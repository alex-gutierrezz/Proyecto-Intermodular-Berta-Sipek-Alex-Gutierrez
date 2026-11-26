<#
.SYNOPSIS
    Directivas de grupo de CiberNova (Anexo I): unidades de red, redirección de
    carpetas y configuración de los puestos.

.DESCRIPTION
    Crea o actualiza tres GPO y sus vínculos:

      CN-U-Unidades     G: Departamentos (G_Empleados)
                        P: Proyectos     (solo quien tiene acceso: DL_Proyectos_L)
                        S: Comun         (DL_Comun_C: empleados y recepción)
                        Vinculada a las OU Usuarios y Cuentas_Especiales.

      CN-U-Redireccion  Documentos y Escritorio a la carpeta personal
                        (\\<dominio>\empresa\Personales\<usuario>).
                        Solo se aplica a los departamentos con perfil local y a los
                        becarios. Dirección y Comercial usan perfil móvil y
                        recepcion.bcn perfil obligatorio, así que quedan fuera.
                        Vinculada a la OU Usuarios.

      CN-C-Puestos      Esperar a la red al iniciar el equipo y la sesión (sin esto
                        el perfil móvil y la redirección fallan en el primer inicio)
                        y G_Adm_Sistemas en el grupo Administradores local.
                        Vinculada a la OU Equipos (Puestos y Recepcion).

    La unidad H: no va por GPO: sale del atributo HomeDirectory/HomeDrive que
    rellena alta-usuarios.ps1 cuando se lanza con -RutaPersonales.

    Es idempotente: una GPO que ya tiene su configuración no se toca ni cambia de
    versión, así que los equipos no la vuelven a procesar sin motivo.

    La redirección se guarda en fdeploy.ini (formato que GPMC lee y muestra en
    "Redirección de carpetas"). Valores de [FolderStatus], en hexadecimal:
    0x1 = mover el contenido, 0x10 = derechos exclusivos para el usuario. Se usa 1:
    sin derechos exclusivos, para que Sistemas conserve el acceso técnico que le da
    la carpeta personal (Anexo I).

.PARAMETER Empresa
    Ruta DFS de la raíz de datos. Por defecto \\<dominio>\empresa.

.EXAMPLE
    .\gpo-cibernova.ps1 -WhatIf
    Enseña lo que cambiaría sin tocar nada.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Empresa
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory, GroupPolicy

$simulacion = [bool]$WhatIfPreference
$WhatIfPreference = $false

$dominio = Get-ADDomain
$dns     = $dominio.DNSRoot
$netbios = $dominio.NetBIOSName
$pdc     = $dominio.PDCEmulator
$raizDN  = "OU=CiberNova,$($dominio.DistinguishedName)"
$sysvol  = "\\$pdc\SYSVOL\$dns\Policies"
if (-not $Empresa) { $Empresa = "\\$dns\empresa" }

$cambios = [System.Collections.Generic.List[string]]::new()

# Extensiones de cliente (CSE) y herramientas de edición de GPMC
$CSE = @{
    Unidades    = '{5794DAFD-BE60-433F-88A2-1A31939AC01F}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}'
    Grupos      = '{17D89FEC-5C44-4972-B12D-241CAEF74509}{79F92669-4224-476C-9C5C-6EFB4D87DF4A}'
    Redireccion = '{25537BA6-77A8-11D2-9B6C-0000F8080861}{88E729D6-BDC1-11D1-BD2A-00C04FB9603F}'
}
$NUCLEO_GPP = '{00000000-0000-0000-0000-000000000000}'

# ---------------------------------------------------------------------------
# Funciones
# ---------------------------------------------------------------------------
function Add-Cambio {
    param([string]$Texto)
    $cambios.Add($Texto)
    $prefijo = if ($simulacion) { 'HARÍA' } else { 'CAMBIO' }
    Write-Host "[$prefijo] $Texto"
}

function Get-Sid {
    param([string]$Grupo)
    (Get-ADGroup -Identity $Grupo -Server $pdc).SID.Value
}

# GUID fijo a partir de un texto: el uid de cada elemento de GPP no cambia entre
# ejecuciones y el XML queda igual si la configuración no cambia.
function Get-GuidFijo {
    param([string]$Texto)
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Texto))
    ([guid]::new($bytes)).ToString('B').ToUpper()
}

function Get-GpoCibernova {
    param([string]$Nombre, [string]$Comentario)
    $gpo = Get-GPO -Name $Nombre -Server $pdc -ErrorAction SilentlyContinue
    if (-not $gpo) {
        Add-Cambio "GPO $Nombre creada"
        if (-not $simulacion) { $gpo = New-GPO -Name $Nombre -Comment $Comentario -Server $pdc }
    }
    $gpo
}

function Set-Vinculo {
    param($Gpo, [string]$Nombre, [string]$OU)
    $destino = "$OU,$raizDN"
    $vinculos = (Get-GPInheritance -Target $destino -Server $pdc).GpoLinks
    if (-not $Gpo -or $vinculos.DisplayName -notcontains $Nombre) {
        Add-Cambio "GPO $Nombre vinculada a $OU"
        if (-not $simulacion) { New-GPLink -Guid $Gpo.Id -Target $destino -LinkEnabled Yes -Server $pdc | Out-Null }
    }
}

# Filtrado de seguridad: Usuarios autentificados se queda solo con Lectura (los
# equipos tienen que poder leer la GPO, MS16-072) y Aplicar pasa a los grupos indicados.
function Set-FiltroSeguridad {
    param($Gpo, [string]$Nombre, [string[]]$Grupos)
    if (-not $Gpo) {
        Add-Cambio "GPO $Nombre filtrada a: $($Grupos -join ', ')"
        return
    }
    $permisos = Get-GPPermission -Guid $Gpo.Id -All -Server $pdc
    $autenticados = ([System.Security.Principal.SecurityIdentifier]'S-1-5-11').Translate(
        [System.Security.Principal.NTAccount]).Value.Split('\')[-1]

    $actual = $permisos | Where-Object { $_.Trustee.Sid.Value -eq 'S-1-5-11' }
    if ($actual.Permission -ne 'GpoRead') {
        Add-Cambio "GPO ${Nombre}: $autenticados solo con Lectura"
        if (-not $simulacion) {
            Set-GPPermission -Guid $Gpo.Id -TargetName $autenticados -TargetType Group `
                -PermissionLevel GpoRead -Replace -Server $pdc | Out-Null
        }
    }
    foreach ($g in $Grupos) {
        $p = $permisos | Where-Object { $_.Trustee.Name -eq $g }
        if ($p.Permission -ne 'GpoApply') {
            Add-Cambio "GPO ${Nombre}: Aplicar para $g"
            if (-not $simulacion) {
                Set-GPPermission -Guid $Gpo.Id -TargetName $g -TargetType Group `
                    -PermissionLevel GpoApply -Server $pdc | Out-Null
            }
        }
    }
}

# Valor de directiva administrativa (Registry.pol). Solo se escribe si es distinto,
# porque Set-GPRegistryValue sube la versión de la GPO aunque el valor sea el mismo.
function Set-ValorDirectiva {
    param($Gpo, [string]$Nombre, [string]$Clave, [string]$Valor, [int]$Dato)
    if ($Gpo) {
        $actual = Get-GPRegistryValue -Guid $Gpo.Id -Key $Clave -ValueName $Valor `
            -Server $pdc -ErrorAction SilentlyContinue
        if ($actual -and $actual.Value -eq $Dato) { return }
    }
    Add-Cambio "GPO ${Nombre}: $Clave\$Valor = $Dato"
    if (-not $simulacion) {
        Set-GPRegistryValue -Guid $Gpo.Id -Key $Clave -ValueName $Valor -Type DWord `
            -Value $Dato -Server $pdc | Out-Null
    }
}

# Añade una extensión a gPCUserExtensionNames / gPCMachineExtensionNames.
# Formato: [{CSE}{herramienta}...][...], ordenado por GUID. Devuelve $true si cambia.
function Add-Extension {
    param($Gpo, [ValidateSet('User', 'Machine')][string]$Ambito, [string]$Par, [switch]$Gpp)
    $id = $Gpo.Id.ToString('B').ToUpper()
    $objeto = [adsi]"LDAP://$pdc/CN=$id,CN=Policies,CN=System,$($dominio.DistinguishedName)"
    $atributo = if ($Ambito -eq 'User') { 'gPCUserExtensionNames' } else { 'gPCMachineExtensionNames' }
    $valor = [string]$objeto.Properties[$atributo].Value

    $tabla = @{}
    foreach ($bloque in [regex]::Matches($valor, '\[([^\]]+)\]')) {
        $guids = @([regex]::Matches($bloque.Groups[1].Value, '\{[^}]+\}') | ForEach-Object { $_.Value.ToUpper() })
        $tabla[$guids[0]] = [System.Collections.Generic.SortedSet[string]]::new([string[]]@($guids | Select-Object -Skip 1))
    }
    $nuevos = @($Par.Substring(0, 38), $Par.Substring(38))
    $pares = @(, $nuevos)
    if ($Gpp) { $pares += , @($NUCLEO_GPP, $nuevos[1]) }
    foreach ($p in $pares) {
        if (-not $tabla.ContainsKey($p[0])) {
            $tabla[$p[0]] = [System.Collections.Generic.SortedSet[string]]::new()
        }
        [void]$tabla[$p[0]].Add($p[1])
    }
    $resultado = ($tabla.Keys | Sort-Object | ForEach-Object { '[' + $_ + (-join $tabla[$_]) + ']' }) -join ''
    if ($resultado -eq $valor) { return $false }
    if (-not $simulacion) {
        $objeto.Properties[$atributo].Value = $resultado
        $objeto.CommitChanges()
    }
    $true
}

# Sube la versión de usuario o de equipo en AD y en GPT.INI (tienen que coincidir).
function Step-VersionGpo {
    param($Gpo, [ValidateSet('User', 'Machine')][string]$Ambito)
    $id = $Gpo.Id.ToString('B').ToUpper()
    $objeto = [adsi]"LDAP://$pdc/CN=$id,CN=Policies,CN=System,$($dominio.DistinguishedName)"
    $version = [int]$objeto.Properties['versionNumber'].Value
    $usuario = $version -shr 16
    $equipo  = $version -band 0xFFFF
    if ($Ambito -eq 'User') { $usuario++ } else { $equipo++ }
    $version = ($usuario -shl 16) -bor $equipo
    $objeto.Properties['versionNumber'].Value = $version
    $objeto.CommitChanges()

    $ini = "$sysvol\$id\GPT.INI"
    $texto = if (Test-Path -LiteralPath $ini) { [IO.File]::ReadAllText($ini) } else { "[General]`r`nVersion=0`r`n" }
    if ($texto -notmatch 'Version=\d+') { $texto = $texto.TrimEnd() + "`r`nVersion=0`r`n" }
    [IO.File]::WriteAllText($ini, ($texto -replace 'Version=\d+', "Version=$version"), [System.Text.Encoding]::ASCII)
}

# Escribe un fichero de la GPO en SYSVOL (preferencias o redirección), registra su
# extensión y sube la versión. No hace nada si el fichero y la extensión ya están.
function Set-ArchivoGpo {
    param(
        $Gpo, [string]$Nombre,
        [ValidateSet('User', 'Machine')][string]$Ambito,
        [string]$Ruta, [string]$Contenido, [string]$Extension,
        [switch]$Gpp, [switch]$Utf16
    )
    if (-not $Gpo) {
        Add-Cambio "GPO ${Nombre}: $Ambito\$Ruta"
        return
    }
    $id = $Gpo.Id.ToString('B').ToUpper()
    $fichero = Join-Path "$sysvol\$id\$Ambito" $Ruta
    $actual = if (Test-Path -LiteralPath $fichero) { [IO.File]::ReadAllText($fichero) } else { $null }

    $cambiaFichero = $actual -ne $Contenido
    $cambiaExtension = Add-Extension -Gpo $Gpo -Ambito $Ambito -Par $Extension -Gpp:$Gpp
    if (-not ($cambiaFichero -or $cambiaExtension)) { return }

    Add-Cambio "GPO ${Nombre}: $Ambito\$Ruta"
    if ($simulacion) { return }
    if ($cambiaFichero) {
        New-Item -ItemType Directory -Path (Split-Path $fichero) -Force | Out-Null
        $codificacion = if ($Utf16) { [System.Text.UnicodeEncoding]::new($false, $true) } else { [System.Text.UTF8Encoding]::new($true) }
        [IO.File]::WriteAllText($fichero, $Contenido, $codificacion)
    }
    Step-VersionGpo -Gpo $Gpo -Ambito $Ambito
}

# ---------------------------------------------------------------------------
# Comprobaciones
# ---------------------------------------------------------------------------
$necesarios = 'G_Empleados', 'G_Adm_Sistemas', 'G_Becarios', 'DL_Proyectos_L', 'DL_Comun_C'
$faltan = $necesarios | Where-Object { -not (Get-ADGroup -Filter "Name -eq '$_'" -Server $pdc) }
if ($faltan) { throw "Faltan grupos (lanzar antes ad-05-usuarios.yml): $($faltan -join ', ')" }

$CAMBIADO = '2026-11-26 09:00:00'

# ---------------------------------------------------------------------------
# CN-U-Unidades
# ---------------------------------------------------------------------------
$nombre = 'CN-U-Unidades'
$gpo = Get-GpoCibernova $nombre 'Unidades de red G:, P: y S: (Anexo I). H: va por HomeDirectory.'

$unidades = @(
    @{ Letra = 'G'; Ruta = "$Empresa\Departamentos"; Etiqueta = 'Departamentos'; Grupo = 'G_Empleados' }
    @{ Letra = 'P'; Ruta = "$Empresa\Proyectos";     Etiqueta = 'Proyectos';     Grupo = 'DL_Proyectos_L' }
    @{ Letra = 'S'; Ruta = "$Empresa\Comun";         Etiqueta = 'Comun';         Grupo = 'DL_Comun_C' }
)
$xml = [System.Text.StringBuilder]::new()
[void]$xml.Append('<?xml version="1.0" encoding="utf-8"?>' + "`r`n")
[void]$xml.Append('<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}">')
foreach ($u in $unidades) {
    $uid = Get-GuidFijo "unidad-$($u.Letra)"
    $sid = Get-Sid $u.Grupo
    [void]$xml.Append(
        "<Drive clsid=`"{935D1B74-9CB8-4e3c-9914-7DD559B7A417}`" name=`"$($u.Letra):`" status=`"$($u.Letra):`" " +
        "image=`"2`" changed=`"$CAMBIADO`" uid=`"$uid`" bypassErrors=`"1`">" +
        "<Properties action=`"U`" thisDrive=`"NOCHANGE`" allDrives=`"NOCHANGE`" userName=`"`" " +
        "path=`"$($u.Ruta)`" label=`"$($u.Etiqueta)`" persistent=`"0`" useLetter=`"1`" letter=`"$($u.Letra)`"/>" +
        "<Filters><FilterGroup bool=`"AND`" not=`"0`" name=`"$netbios\$($u.Grupo)`" sid=`"$sid`" " +
        "userContext=`"1`" primaryGroup=`"0`" localGroup=`"0`"/></Filters></Drive>")
}
[void]$xml.Append('</Drives>')

Set-ArchivoGpo -Gpo $gpo -Nombre $nombre -Ambito User -Ruta 'Preferences\Drives\Drives.xml' `
    -Contenido $xml.ToString() -Extension $CSE.Unidades -Gpp
Set-Vinculo $gpo $nombre 'OU=Usuarios'
Set-Vinculo $gpo $nombre 'OU=Cuentas_Especiales'

# ---------------------------------------------------------------------------
# CN-U-Redireccion
# ---------------------------------------------------------------------------
$nombre = 'CN-U-Redireccion'
$gpo = Get-GpoCibernova $nombre 'Documentos y Escritorio a la carpeta personal (perfil local + redirección, Anexo I).'

$personal = "$Empresa\Personales\%USERNAME%"
$ini = @(
    '[.Version]', '_ver=1',
    '[FolderStatus]', 'My Documents=1', 'Desktop=1',
    '[My Documents]', "s-1-1-0=$personal\Documentos",
    '[Desktop]', "s-1-1-0=$personal\Escritorio"
) -join "`r`n"
$ini += "`r`n"

Set-ArchivoGpo -Gpo $gpo -Nombre $nombre -Ambito User -Ruta 'Documents & Settings\fdeploy.ini' `
    -Contenido $ini -Extension $CSE.Redireccion -Utf16
# Las carpetas redirigidas no se marcan para usar sin conexión (Archivos sin conexión)
Set-ValorDirectiva $gpo $nombre 'HKCU\Software\Policies\Microsoft\Windows\NetCache' 'DisableFRAdminPin' 1

$conRedireccion = 'G_Administracion', 'G_RRHH', 'G_Marketing', 'G_Consultoria', 'G_Desarrollo',
                  'G_Sistemas', 'G_Soporte', 'G_Legal', 'G_Becarios'
Set-FiltroSeguridad $gpo $nombre $conRedireccion
Set-Vinculo $gpo $nombre 'OU=Usuarios'

# ---------------------------------------------------------------------------
# CN-C-Puestos
# ---------------------------------------------------------------------------
$nombre = 'CN-C-Puestos'
$gpo = Get-GpoCibernova $nombre 'Configuración de los puestos de trabajo (OU Equipos).'

# Equipo > Plantillas administrativas > Sistema > Inicio de sesión >
#   "Esperar siempre a la red al iniciar el equipo y la sesión"
Set-ValorDirectiva $gpo $nombre 'HKLM\Software\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon' 'SyncForegroundPolicy' 1

# Grupo local Administradores (S-1-5-32-544): se añade G_Adm_Sistemas, no se quita a nadie
$sidAdm = Get-Sid 'G_Adm_Sistemas'
$uidAdm = Get-GuidFijo 'grupo-administradores'
$grupos = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" +
    '<Groups clsid="{3125E937-EB16-4b4c-9934-544FC6D24D26}">' +
    "<Group clsid=`"{6D4A79E4-529C-4481-ABD0-F5BD7EA93BA7}`" name=`"Administradores (integrado)`" image=`"2`" " +
    "changed=`"$CAMBIADO`" uid=`"$uidAdm`">" +
    '<Properties action="U" newName="" description="" deleteAllUsers="0" deleteAllGroups="0" removeAccounts="0" ' +
    'groupSid="S-1-5-32-544" groupName="Administradores (integrado)"><Members>' +
    "<Member name=`"$netbios\G_Adm_Sistemas`" action=`"ADD`" sid=`"$sidAdm`"/>" +
    '</Members></Properties></Group></Groups>'

Set-ArchivoGpo -Gpo $gpo -Nombre $nombre -Ambito Machine -Ruta 'Preferences\Groups\Groups.xml' `
    -Contenido $grupos -Extension $CSE.Grupos -Gpp
Set-Vinculo $gpo $nombre 'OU=Equipos'

# ---------------------------------------------------------------------------
[pscustomobject]@{
    Simulacion = $simulacion
    Cambios    = $cambios.Count
    Detalle    = @($cambios)
}
