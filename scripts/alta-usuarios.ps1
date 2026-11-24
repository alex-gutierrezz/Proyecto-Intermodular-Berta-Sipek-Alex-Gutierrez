<#
.SYNOPSIS
    Alta de usuarios, grupos y cuentas especiales de CiberNova a partir de
    usuarios_cibernova.csv (Anexo I).

.DESCRIPTION
    Se ejecuta en DC01 (o lo lanza ansible/playbooks/ad-05-usuarios.yml).
    Es idempotente: cada ejecución deja AD como dicen el CSV y los ficheros de
    scripts/datos; lo que ya está bien no se toca y nunca se crean duplicados.

    Qué hace, en este orden:
      1. Lee y valida el CSV (departamento, sede, grupos y nombre de usuario esperado).
      2. Crea los grupos globales G_ (departamento, sede, transversales, becarios...).
      3. Crea o actualiza los 89 usuarios en la OU de su departamento.
      4. Crea las cuentas adm.<usuario>, de servicio y especiales.
      5. Sincroniza la pertenencia a los G_ (los becarios NO entran en G_<Dept>).
      6. Crea los grupos de dominio local DL_ y les pone sus G_ (modelo AGDLP).
      7. Crea la PSO de 15 caracteres para Dirección, Sistemas y cuentas adm.
      8. (Opcional, -RutaPersonales) crea las carpetas personales con sus permisos.

    Contraseñas: solo se generan al CREAR una cuenta (aleatorias, 16 caracteres,
    cambio obligatorio en el primer inicio). Se guardan en un CSV en
    C:\CiberNova\credenciales que solo pueden leer los administradores; nunca se
    muestran por pantalla ni van al repositorio. A las cuentas que ya existen no
    se les cambia la contraseña ni el estado (habilitada/deshabilitada).

    Lo que el script NO hace nunca: borrar cuentas, tocar las que están en
    OU=Bajas ni quitar de los grupos a cuentas que no gestiona (solo avisa).

.PARAMETER RutaPersonales
    Ruta UNC de la carpeta Personales (p. ej. \\cibernova.local\empresa\Personales).
    Si no se indica, no se crean carpetas personales ni se rellena H:.

.PARAMETER RutaPerfiles
    Ruta UNC de los perfiles móviles. Si se indica, los usuarios con Perfil=Movil
    reciben ProfilePath = <RutaPerfiles>\<usuario>.

.EXAMPLE
    .\alta-usuarios.ps1 -WhatIf
    Muestra lo que cambiaría sin tocar nada.

.EXAMPLE
    .\alta-usuarios.ps1
    Aplica los cambios.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RutaCsv             = (Join-Path $PSScriptRoot 'datos\usuarios_cibernova.csv'),
    [string]$RutaConfig          = (Join-Path $PSScriptRoot 'datos\config-alta.psd1'),
    [string]$RutaGruposDL        = (Join-Path $PSScriptRoot 'datos\grupos-dl.csv'),
    [string]$CarpetaCredenciales = 'C:\CiberNova\credenciales',
    [string]$CarpetaLogs         = 'C:\CiberNova\logs',
    [string]$RutaPersonales,
    [string]$RutaPerfiles
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# ---------------------------------------------------------------------------
# Registro
# ---------------------------------------------------------------------------
$script:Simulacion = [bool]$WhatIfPreference
$script:Cambios    = 0
$script:Creados    = 0
$script:Avisos     = New-Object System.Collections.Generic.List[string]
$script:Errores    = New-Object System.Collections.Generic.List[string]
$script:Credenciales = New-Object System.Collections.Generic.List[object]

$marca = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not (Test-Path $CarpetaLogs)) { New-Item -ItemType Directory -Path $CarpetaLogs -Force -WhatIf:$false | Out-Null }
$script:FicheroLog = Join-Path $CarpetaLogs "alta-usuarios-$marca.log"

function Registrar {
    param([string]$Texto, [ValidateSet('INFO', 'CAMBIO', 'AVISO', 'ERROR')][string]$Nivel = 'INFO')
    $prefijo = if ($script:Simulacion -and $Nivel -eq 'CAMBIO') { 'SIMULADO' } else { $Nivel }
    $linea = '{0} [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $prefijo, $Texto
    [System.IO.File]::AppendAllText($script:FicheroLog, $linea + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    switch ($Nivel) {
        'CAMBIO' { $script:Cambios++; Write-Host $linea }
        'AVISO'  { $script:Avisos.Add($Texto); Write-Host $linea -ForegroundColor Yellow }
        'ERROR'  { $script:Errores.Add($Texto); Write-Host $linea -ForegroundColor Red }
        default  { Write-Host $linea }
    }
}

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

# Quita tildes, diéresis, eñes y todo lo que no sea letra o número, y pasa a minúsculas.
function ConvertTo-Ascii {
    param([string]$Texto)
    $descompuesto = $Texto.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $descompuesto.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne
            [System.Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($c) }
    }
    return ($sb.ToString() -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
}

# Contraseña aleatoria con generador criptográfico; siempre lleva mayúscula,
# minúscula, número y símbolo. Sin caracteres que se confunden (0/O, 1/l/I).
$script:Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

# Entero aleatorio uniforme en [0, Maximo) (muestreo con rechazo, sin sesgo de módulo)
function Get-Aleatorio {
    param([int]$Maximo)
    $byte   = New-Object byte[] 1
    $limite = 256 - (256 % $Maximo)
    do { $script:Rng.GetBytes($byte) } while ($byte[0] -ge $limite)
    return [int]($byte[0] % $Maximo)
}

function New-Contrasena {
    param([int]$Longitud = 16)
    $juegos = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnpqrstuvwxyz', '23456789', '!#$%&*+-=?@')
    $todos  = -join $juegos
    $chars  = New-Object System.Collections.Generic.List[char]
    foreach ($j in $juegos) { $chars.Add($j[(Get-Aleatorio $j.Length)]) }
    while ($chars.Count -lt $Longitud) { $chars.Add($todos[(Get-Aleatorio $todos.Length)]) }
    # Barajar (Fisher-Yates) para que los cuatro primeros no sigan siempre el mismo orden
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $k = Get-Aleatorio ($i + 1)
        $tmp = $chars[$i]; $chars[$i] = $chars[$k]; $chars[$k] = $tmp
    }
    return -join $chars
}

# Atributo logonHours (21 bytes, 1 bit por hora de la semana, en UTC, empezando el
# domingo a las 00:00 UTC). Se calcula con el desfase de horario de invierno de la
# zona indicada, igual que la consola de AD. En horario de verano la franja se
# desplaza una hora (limitación conocida de logonHours, que no entiende de DST).
function Get-LogonHours {
    param([int[]]$Dias, [int]$Desde, [int]$Hasta, [string]$ZonaHoraria)
    $bytes   = New-Object byte[] 21
    $desfase = [int][System.TimeZoneInfo]::FindSystemTimeZoneById($ZonaHoraria).BaseUtcOffset.TotalHours
    foreach ($d in $Dias) {
        for ($h = $Desde; $h -lt $Hasta; $h++) {
            $i = ((($d * 24) + $h - $desfase) % 168 + 168) % 168
            $pos = [int][Math]::Floor($i / 8)
            $bytes[$pos] = [byte]($bytes[$pos] -bor (1 -shl ($i % 8)))
        }
    }
    return , $bytes
}

function Get-LogonHoursTexto {
    param($Bytes)
    if ($null -eq $Bytes) { return 'sin restricción' }
    $todo = $true
    foreach ($b in $Bytes) { if ($b -ne 255) { $todo = $false } }
    if ($todo) { return 'sin restricción' }
    return ($Bytes | ForEach-Object { $_.ToString('X2') }) -join ''
}

function Get-OUPadre {
    param([string]$DN)
    return ($DN -replace '^CN=.+?(?<!\\),', '')
}

# ---------------------------------------------------------------------------
# Datos de entrada
# ---------------------------------------------------------------------------
Registrar "Inicio del alta de usuarios$(if ($script:Simulacion) { ' (SIMULACIÓN: -WhatIf)' })"
Registrar "CSV: $RutaCsv"

$cfg    = Import-PowerShellDataFile -Path $RutaConfig
$filas  = @(Import-Csv -Path $RutaCsv -Delimiter ';' -Encoding UTF8 | Where-Object { $_.Nombre -and $_.Nombre.Trim() })
$tablaDL = @(Import-Csv -Path $RutaGruposDL -Delimiter ';' -Encoding UTF8 | Where-Object { $_.Grupo })
$zona   = if ($cfg.ZonaHoraria) { $cfg.ZonaHoraria } else { 'Romance Standard Time' }

$columnas = 'Nombre', 'Apellido1', 'Apellido2', 'Usuario', 'Departamento', 'Puesto', 'Sede',
            'Responsable', 'GruposAdicionales', 'Perfil', 'CuotaPersonal', 'Observaciones'
$faltan = $columnas | Where-Object { $filas[0].PSObject.Properties.Name -notcontains $_ }
if ($faltan) { throw "Al CSV le faltan las columnas: $($faltan -join ', ')" }
Registrar "Filas leídas: $($filas.Count); grupos DL_ en la tabla: $($tablaDL.Count)"

$dominio = Get-ADDomain
$raiz    = "OU=CiberNova,$($dominio.DistinguishedName)"
$ouGlobales = "OU=Globales,OU=Grupos,$raiz"
$ouDL       = "OU=DominioLocal,OU=Grupos,$raiz"
$ouBajas    = "OU=Bajas,$raiz"

# Las OU las crea ad-03-estructura.yml; si falta alguna, se para aquí.
$ousNecesarias = @($ouGlobales, $ouDL, $ouBajas, "OU=Cuentas_Admin,$raiz", "OU=Cuentas_Servicio,$raiz",
                   "OU=Cuentas_Especiales,$raiz") + ($cfg.Departamentos | ForEach-Object { "OU=$_,OU=Usuarios,$raiz" })
foreach ($ou in $ousNecesarias) {
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ou'")) {
        throw "No existe $ou. Lanza antes ad-03-estructura.yml."
    }
}

# ---------------------------------------------------------------------------
# 1. Validación del CSV y cálculo del nombre de usuario
#    Regla del Anexo: nombre.apellido1; si ya existe, se añade la inicial del 2º apellido.
#    El "ya existe" se mira dentro del CSV y en su orden (el primero que aparece se
#    queda el nombre corto), así el resultado es siempre el mismo aunque se repita.
# ---------------------------------------------------------------------------
$usuarios = New-Object System.Collections.Generic.List[object]
$asignados = @{}
foreach ($f in $filas) {
    $base = '{0}.{1}' -f (ConvertTo-Ascii $f.Nombre), (ConvertTo-Ascii $f.Apellido1)
    $sam  = $base
    if ($asignados.ContainsKey($sam)) { $sam = $base + (ConvertTo-Ascii $f.Apellido2).Substring(0, 1) }

    $problemas = @()
    if ($asignados.ContainsKey($sam))                    { $problemas += "nombre $sam repetido incluso con la inicial del 2º apellido" }
    if ($sam -ne $f.Usuario.Trim().ToLowerInvariant())   { $problemas += "calculado '$sam' pero el CSV espera '$($f.Usuario)'" }
    if ($sam.Length -gt 20)                              { $problemas += "'$sam' supera los 20 caracteres de sAMAccountName" }
    if ($cfg.Departamentos -notcontains $f.Departamento) { $problemas += "departamento desconocido '$($f.Departamento)'" }
    if ($cfg.Sedes -notcontains $f.Sede)                 { $problemas += "sede desconocida '$($f.Sede)'" }
    $extra = @($f.GruposAdicionales -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($g in $extra) { if ($cfg.Transversales -notcontains $g) { $problemas += "grupo adicional desconocido '$g'" } }

    if ($problemas) {
        Registrar "Fila de $($f.Nombre) $($f.Apellido1) $($f.Apellido2) descartada: $($problemas -join '; ')" ERROR
        continue
    }
    $asignados[$sam] = $true

    $usuarios.Add([pscustomobject]@{
        Fila        = $f
        Usuario     = $sam
        Becario     = ($extra -contains 'Becarios')
        Responsable = ($f.Responsable -eq 'Si')
        Extra       = $extra
        Admin       = ($f.Observaciones -match 'cuenta administrativa adm\.')
    })
}
Registrar "Usuarios válidos: $($usuarios.Count) (becarios: $(@($usuarios | Where-Object Becario).Count))"

# ---------------------------------------------------------------------------
# 2. Grupos globales G_
# ---------------------------------------------------------------------------
$descG = @{}
foreach ($d in $cfg.Departamentos) { $descG["G_$d"] = "Personal de $d (sin becarios)" }
foreach ($s in $cfg.Sedes)         { $descG["G_Sede_$s"] = "Personal de la sede de $s" }
foreach ($t in $cfg.Transversales) { $descG["G_$t"] = "Grupo transversal $t (Anexo I, ap. 4)" }
$descG['G_Becarios'] = 'Todos los becarios (anida G_Becarios_<Dept>)'
foreach ($d in ($usuarios | Where-Object Becario | ForEach-Object { $_.Fila.Departamento } | Sort-Object -Unique)) {
    $descG["G_Becarios_$d"] = "Becarios de $d"
}
$descG['G_Empleados']     = 'Todos los empleados: G_ de departamento + G_Becarios'
$descG['G_Adm_Sistemas']  = 'Cuentas adm. de Sistemas (únicas con privilegios)'
$descG['G_Recepcion']     = 'Cuenta de recepción'
$descG['G_Auditores_Ext'] = 'Auditoría externa'
$descG['G_Svc_Backup']    = 'Cuenta de servicio de copias'
foreach ($par in $cfg.GruposDeResponsable.GetEnumerator()) { $descG[$par.Value] = "Responsable de $($par.Key)" }
# Cualquier G_ que use la tabla de DL_ también tiene que existir
foreach ($fila in $tablaDL) {
    foreach ($m in ($fila.Miembros -split ',')) {
        $m = $m.Trim()
        if ($m -and -not $descG.ContainsKey($m)) { $descG[$m] = 'Grupo global usado en la matriz de permisos' }
    }
}

function Confirmar-Grupo {
    param([string]$Nombre, [ValidateSet('Global', 'DomainLocal')][string]$Ambito, [string]$Descripcion)
    $ou = if ($Ambito -eq 'Global') { $ouGlobales } else { $ouDL }
    $g = Get-ADGroup -Filter "SamAccountName -eq '$Nombre'" -Properties Description
    if (-not $g) {
        New-ADGroup -Name $Nombre -SamAccountName $Nombre -GroupScope $Ambito -GroupCategory Security `
                    -Path $ou -Description $Descripcion
        Registrar "Grupo creado: $Nombre ($Ambito)" CAMBIO
        return
    }
    if ($g.GroupScope -ne $Ambito) { Registrar "El grupo $Nombre existe con ámbito $($g.GroupScope), se esperaba $Ambito" AVISO }
    if ((Get-OUPadre $g.DistinguishedName) -ne $ou) { Registrar "El grupo $Nombre no está en $ou" AVISO }
    if ($g.Description -ne $Descripcion) {
        Set-ADGroup -Identity $g -Description $Descripcion
        Registrar "Grupo ${Nombre}: descripción actualizada" CAMBIO
    }
}

Registrar '--- Grupos globales ---'
foreach ($nombre in ($descG.Keys | Sort-Object)) { Confirmar-Grupo $nombre 'Global' ($descG[$nombre]) }

# ---------------------------------------------------------------------------
# 3 y 4. Usuarios y cuentas especiales
# ---------------------------------------------------------------------------
$horasBecarios = Get-LogonHours $cfg.Becarios.Dias $cfg.Becarios.HoraDesde $cfg.Becarios.HoraHasta $zona
$caducidadBecarios = [datetime]::ParseExact($cfg.Becarios.Caducidad, 'yyyy-MM-dd', $null)
$propiedades = 'GivenName', 'Surname', 'DisplayName', 'Title', 'Department', 'Office', 'Description',
               'Company', 'AccountExpirationDate', 'logonHours', 'HomeDirectory', 'HomeDrive', 'ProfilePath',
               'CannotChangePassword', 'PasswordNeverExpires', 'Enabled', 'LogonWorkstations', 'Manager', 'SID'

# Deseado (hashtable): Usuario, CN, Nombre, Apellidos, Mostrar, OU, Descripcion y, opcionales:
#   Puesto, Departamento, Oficina, Habilitada, Servicio, NoCambiaContrasena,
#   Caducidad (clave presente = se gestiona; valor $null = sin caducidad),
#   Horas     (clave presente = se gestiona; valor $null = sin restricción),
#   Equipos, HomeDirectory, ProfilePath (clave presente = se gestiona)
# Devuelve el DN de la cuenta, o $null si no se debe tocar.
function Confirmar-Usuario {
    param([hashtable]$D)
    $u = Get-ADUser -Filter "SamAccountName -eq '$($D.Usuario)'" -Properties $propiedades

    if (-not $u) {
        $param = @{
            Name              = $D.CN
            SamAccountName    = $D.Usuario
            UserPrincipalName = "$($D.Usuario)@$($dominio.DNSRoot)"
            GivenName         = $D.Nombre
            Surname           = $D.Apellidos
            DisplayName       = $D.Mostrar
            Description       = $D.Descripcion
            Company           = $cfg.Empresa
            Path              = $D.OU
            Enabled           = [bool]$D.Habilitada
        }
        if ($D.Puesto)       { $param.Title = $D.Puesto }
        if ($D.Departamento) { $param.Department = $D.Departamento }
        if ($D.Oficina)      { $param.Office = $D.Oficina }
        if ($D.Servicio -or $D.NoCambiaContrasena) {
            $param.PasswordNeverExpires = $true
            $param.ChangePasswordAtLogon = $false
        } else {
            $param.ChangePasswordAtLogon = $true
        }
        if ($D.NoCambiaContrasena) { $param.CannotChangePassword = $true }
        if ($D.ContainsKey('Caducidad') -and $D.Caducidad) { $param.AccountExpirationDate = $D.Caducidad }
        if ($D.ContainsKey('Equipos') -and $D.Equipos)     { $param.LogonWorkstations = $D.Equipos }
        if ($D.ContainsKey('HomeDirectory') -and $D.HomeDirectory) { $param.HomeDirectory = $D.HomeDirectory; $param.HomeDrive = 'H:' }
        if ($D.ContainsKey('ProfilePath') -and $D.ProfilePath)     { $param.ProfilePath = $D.ProfilePath }

        # Si la contraseña no cumple la complejidad (p. ej. contiene parte del nombre), se genera otra
        for ($intento = 1; $intento -le 3; $intento++) {
            $clave = New-Contrasena $cfg.LongitudContrasena
            try {
                New-ADUser @param -AccountPassword (ConvertTo-SecureString $clave -AsPlainText -Force)
                break
            } catch [Microsoft.ActiveDirectory.Management.ADPasswordComplexityException] {
                if ($intento -eq 3) { throw }
            }
        }
        $dn = "CN=$($D.CN),$($D.OU)"
        if (-not $script:Simulacion) {
            if ($D.ContainsKey('Horas') -and $D.Horas) {
                Set-ADUser -Identity $D.Usuario -Replace @{ logonHours = [byte[]]$D.Horas }
            }
            $script:Credenciales.Add([pscustomobject]@{
                Usuario = $D.Usuario; Nombre = $D.Mostrar; ContrasenaInicial = $clave
                CambioEnPrimerInicio = [bool]$param.ChangePasswordAtLogon; Creada = (Get-Date -Format 'yyyy-MM-dd HH:mm')
            })
            $dn = (Get-ADUser -Identity $D.Usuario).DistinguishedName
        }
        $script:Creados++
        Registrar "Cuenta creada: $($D.Usuario) en $($D.OU)$(if (-not $D.Habilitada) { ' (deshabilitada)' })" CAMBIO
        return $dn
    }

    # --- La cuenta ya existe ---
    if ($u.DistinguishedName -like "*,$ouBajas") {
        Registrar "$($D.Usuario) está en OU=Bajas: no se modifica" AVISO
        return $null
    }
    if ($u.Surname -and $D.Apellidos -and ($u.Surname -ne $D.Apellidos)) {
        Registrar "$($D.Usuario) ya existe pero es otra persona ($($u.Surname)): no se modifica" ERROR
        return $null
    }

    $dn = $u.DistinguishedName
    if ((Get-OUPadre $dn) -ne $D.OU) {
        Move-ADObject -Identity $dn -TargetPath $D.OU
        Registrar "$($D.Usuario) movido a $($D.OU)" CAMBIO
        # El objeto $u apunta todavía al DN antiguo: se vuelve a leer antes de seguir
        if (-not $script:Simulacion) {
            $u  = Get-ADUser -Identity $D.Usuario -Properties $propiedades
            $dn = $u.DistinguishedName
        }
    }

    # Atributos de texto
    $cambiar = @{}
    $mapa = [ordered]@{ GivenName = $D.Nombre; Surname = $D.Apellidos; DisplayName = $D.Mostrar
                        Description = $D.Descripcion; Company = $cfg.Empresa
                        Title = $D.Puesto; Department = $D.Departamento; Office = $D.Oficina }
    foreach ($campo in $mapa.Keys) {
        $valor = $mapa[$campo]
        if ($valor -and ($u.$campo -cne $valor)) { $cambiar[$campo] = $valor }
    }
    if ($cambiar.Count) {
        Set-ADUser -Identity $u @cambiar
        Registrar "$($D.Usuario): actualizado $($cambiar.Keys -join ', ')" CAMBIO
    }

    # Caducidad
    if ($D.ContainsKey('Caducidad')) {
        if ($D.Caducidad -and ($u.AccountExpirationDate -ne $D.Caducidad)) {
            Set-ADAccountExpiration -Identity $u -DateTime $D.Caducidad
            Registrar "$($D.Usuario): caducidad $($D.Caducidad.ToString('dd/MM/yyyy'))" CAMBIO
        } elseif (-not $D.Caducidad -and $u.AccountExpirationDate) {
            Clear-ADAccountExpiration -Identity $u
            Registrar "$($D.Usuario): se quita la caducidad" CAMBIO
        }
    }

    # Horario de inicio de sesión
    if ($D.ContainsKey('Horas')) {
        $actual  = Get-LogonHoursTexto $u.logonHours
        $deseado = Get-LogonHoursTexto $D.Horas
        if ($actual -ne $deseado) {
            if ($D.Horas) { Set-ADUser -Identity $u -Replace @{ logonHours = [byte[]]$D.Horas } }
            else          { Set-ADUser -Identity $u -Clear logonHours }
            Registrar "$($D.Usuario): horario de inicio de sesión actualizado" CAMBIO
        }
    }

    # Equipos permitidos
    if ($D.ContainsKey('Equipos') -and $D.Equipos -and ($u.LogonWorkstations -ne $D.Equipos)) {
        Set-ADUser -Identity $u -LogonWorkstations $D.Equipos
        Registrar "$($D.Usuario): limitado a los equipos $($D.Equipos)" CAMBIO
    }

    # Contraseña sin caducidad / no puede cambiarla (servicio y recepción)
    $sinCaducidad = [bool]($D.Servicio -or $D.NoCambiaContrasena)
    if ($u.PasswordNeverExpires -ne $sinCaducidad) {
        Set-ADUser -Identity $u -PasswordNeverExpires $sinCaducidad
        Registrar "$($D.Usuario): PasswordNeverExpires = $sinCaducidad" CAMBIO
    }
    if ($u.CannotChangePassword -ne [bool]$D.NoCambiaContrasena) {
        Set-ADUser -Identity $u -CannotChangePassword ([bool]$D.NoCambiaContrasena)
        Registrar "$($D.Usuario): CannotChangePassword = $([bool]$D.NoCambiaContrasena)" CAMBIO
    }

    # Carpeta personal y perfil móvil (solo si se ha pedido gestionarlos)
    if ($D.ContainsKey('HomeDirectory') -and ($u.HomeDirectory -ne $D.HomeDirectory -or $u.HomeDrive -ne 'H:')) {
        Set-ADUser -Identity $u -HomeDirectory $D.HomeDirectory -HomeDrive 'H:'
        Registrar "$($D.Usuario): carpeta personal $($D.HomeDirectory) en H:" CAMBIO
    }
    if ($D.ContainsKey('ProfilePath') -and ($u.ProfilePath -ne $D.ProfilePath)) {
        if ($D.ProfilePath) { Set-ADUser -Identity $u -ProfilePath $D.ProfilePath }
        else                { Set-ADUser -Identity $u -Clear profilePath }
        Registrar "$($D.Usuario): perfil '$($D.ProfilePath)'" CAMBIO
    }
    return $dn
}

$dnUsuario = @{}   # sAMAccountName -> DN de todas las cuentas gestionadas

Registrar '--- Usuarios del CSV ---'
foreach ($x in $usuarios) {
    $f = $x.Fila
    $d = @{
        Usuario      = $x.Usuario
        CN           = "$($f.Nombre) $($f.Apellido1) $($f.Apellido2)"
        Nombre       = $f.Nombre
        Apellidos    = "$($f.Apellido1) $($f.Apellido2)"
        Mostrar      = "$($f.Nombre) $($f.Apellido1) $($f.Apellido2)"
        OU           = "OU=$($f.Departamento),OU=Usuarios,$raiz"
        Descripcion  = $f.Puesto
        Puesto       = $f.Puesto
        Departamento = $f.Departamento
        Oficina      = $f.Sede
        Habilitada   = $true
        Caducidad    = $(if ($x.Becario) { $caducidadBecarios } else { $null })
        Horas        = $(if ($x.Becario) { $horasBecarios } else { $null })
    }
    if ($RutaPersonales) { $d.HomeDirectory = Join-Path $RutaPersonales $x.Usuario }
    if ($RutaPerfiles)   { $d.ProfilePath = $(if ($f.Perfil -eq 'Movil') { Join-Path $RutaPerfiles $x.Usuario } else { $null }) }
    try {
        $dn = Confirmar-Usuario $d
        if ($dn) { $dnUsuario[$x.Usuario] = $dn }
    } catch {
        Registrar "Error con $($x.Usuario): $($_.Exception.Message)" ERROR
    }
}

Registrar '--- Cuentas adm. ---'
$cuentasAdm = @()
foreach ($x in ($usuarios | Where-Object Admin)) {
    $f = $x.Fila
    $adm = "adm.$($x.Usuario)"
    if ($adm.Length -gt 20) { Registrar "$adm supera los 20 caracteres: no se crea" ERROR; continue }
    $d = @{
        Usuario     = $adm
        CN          = "$($f.Nombre) $($f.Apellido1) $($f.Apellido2) (adm)"
        Nombre      = $f.Nombre
        Apellidos   = "$($f.Apellido1) $($f.Apellido2)"
        Mostrar     = "$($f.Nombre) $($f.Apellido1) $($f.Apellido2) (administración)"
        OU          = "OU=Cuentas_Admin,$raiz"
        Descripcion = "Cuenta administrativa de $($x.Usuario)"
        Departamento = 'Sistemas'
        Habilitada  = $true
    }
    try {
        $dn = Confirmar-Usuario $d
        if ($dn) { $dnUsuario[$adm] = $dn; $cuentasAdm += $adm }
    } catch {
        Registrar "Error con ${adm}: $($_.Exception.Message)" ERROR
    }
}

Registrar '--- Cuentas especiales y de servicio ---'
$cuentaGrupo = @{}   # sAMAccountName -> G_ al que pertenece
foreach ($c in $cfg.CuentasEspeciales) {
    $d = @{
        Usuario     = $c.Usuario
        CN          = $c.Usuario
        Nombre      = $c.Nombre
        Mostrar     = $c.Nombre
        OU          = "OU=$($c.OU),$raiz"
        Descripcion = $c.Descripcion
        Oficina     = $c.Oficina
        Habilitada  = [bool]$c.Habilitada
        Servicio    = [bool]$c.Servicio
        NoCambiaContrasena = [bool]$c.NoCambiaContrasena
    }
    if ($c.Caducidad) { $d.Caducidad = [datetime]::ParseExact($c.Caducidad, 'yyyy-MM-dd', $null) }
    elseif ($c.ContainsKey('Caducidad')) { Registrar "$($c.Usuario): sin fecha de caducidad en config-alta.psd1 (pendiente)" AVISO }
    if ($c.Horario) { $d.Horas = Get-LogonHours $c.Horario.Dias $c.Horario.HoraDesde $c.Horario.HoraHasta $zona }
    if ($c.Equipos) { $d.Equipos = $c.Equipos }
    elseif ($c.ContainsKey('Equipos')) { Registrar "$($c.Usuario): sin equipo de recepción en config-alta.psd1 (pendiente)" AVISO }
    try {
        $dn = Confirmar-Usuario $d
        if ($dn) {
            $dnUsuario[$c.Usuario] = $dn
            if ($c.Grupo) { $cuentaGrupo[$c.Usuario] = $c.Grupo }
        }
    } catch {
        Registrar "Error con $($c.Usuario): $($_.Exception.Message)" ERROR
    }
}

# Responsable de cada departamento como "Manager" del resto
Registrar '--- Responsables (atributo Manager) ---'
foreach ($dep in $cfg.Departamentos) {
    $resp = @($usuarios | Where-Object { $_.Responsable -and $_.Fila.Departamento -eq $dep })
    if ($resp.Count -ne 1) { Registrar "$dep tiene $($resp.Count) responsables en el CSV: no se asigna Manager" AVISO; continue }
    $dnResp = $dnUsuario[$resp[0].Usuario]
    if (-not $dnResp) { continue }
    foreach ($x in ($usuarios | Where-Object { -not $_.Responsable -and $_.Fila.Departamento -eq $dep })) {
        if (-not $dnUsuario[$x.Usuario] -or $script:Simulacion) { continue }
        $actual = (Get-ADUser -Identity $x.Usuario -Properties Manager).Manager
        if ($actual -ne $dnResp) {
            Set-ADUser -Identity $x.Usuario -Manager $dnResp
            Registrar "$($x.Usuario): responsable $($resp[0].Usuario)" CAMBIO
        }
    }
}

# ---------------------------------------------------------------------------
# 5. Pertenencia a los grupos
# ---------------------------------------------------------------------------
$dnGrupo = @{}
function Get-DNGrupo {
    param([string]$Nombre)
    if (-not $dnGrupo.ContainsKey($Nombre)) {
        $g = Get-ADGroup -Filter "SamAccountName -eq '$Nombre'"
        $dnGrupo[$Nombre] = if ($g) { $g.DistinguishedName } elseif ($script:Simulacion) { "CN=$Nombre,(simulado)" } else { $null }
    }
    return $dnGrupo[$Nombre]
}

# Deja el grupo con exactamente los miembros deseados. Solo quita miembros que el
# script gestiona; los demás se dejan y se avisa (AGDLP: no debería haber otros).
function Sincronizar-Miembros {
    param([string]$Grupo, [string[]]$Deseados)
    $g = Get-ADGroup -Filter "SamAccountName -eq '$Grupo'" -Properties Member
    if (-not $g) {
        if (-not $script:Simulacion) { Registrar "No existe el grupo $Grupo" ERROR }
        return
    }
    $actuales = @($g.Member)
    $deseados = @($Deseados | Where-Object { $_ } | Sort-Object -Unique)
    $anadir = @($deseados | Where-Object { $actuales -notcontains $_ })
    $sobran = @($actuales | Where-Object { $deseados -notcontains $_ })
    if ($anadir) {
        # En simulación algunos miembros aún no existen: solo se anota
        if (-not $script:Simulacion) { Add-ADGroupMember -Identity $g -Members $anadir }
        Registrar "${Grupo}: + $(($anadir | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }) -join ', ')" CAMBIO
    }
    foreach ($m in $sobran) {
        if ($script:Gestionados.ContainsKey($m)) {
            if (-not $script:Simulacion) { Remove-ADGroupMember -Identity $g -Members $m -Confirm:$false }
            Registrar "${Grupo}: - $(($m -split ',')[0] -replace '^CN=')" CAMBIO
        } else {
            Registrar "${Grupo}: tiene un miembro que no gestiona el script ($m); se deja" AVISO
        }
    }
}

$script:Gestionados = @{}
foreach ($dn in $dnUsuario.Values) { $script:Gestionados[$dn] = $true }
foreach ($n in $descG.Keys) { $dnG = Get-DNGrupo $n; if ($dnG) { $script:Gestionados[$dnG] = $true } }

$miembros = @{}
foreach ($n in $descG.Keys) { $miembros[$n] = New-Object System.Collections.Generic.List[string] }

foreach ($x in $usuarios) {
    $dn = $dnUsuario[$x.Usuario]
    if (-not $dn) { continue }
    $f = $x.Fila
    # Los becarios no entran en G_<Dept>: así no heredan los permisos del departamento
    if ($x.Becario) { $miembros["G_Becarios_$($f.Departamento)"].Add($dn) }
    else            { $miembros["G_$($f.Departamento)"].Add($dn) }
    $miembros["G_Sede_$($f.Sede)"].Add($dn)
    foreach ($t in $x.Extra) { if ($t -ne 'Becarios') { $miembros["G_$t"].Add($dn) } }
    if ($x.Responsable) {
        $miembros['G_Responsables'].Add($dn)
        if ($cfg.GruposDeResponsable.ContainsKey($f.Departamento)) {
            $miembros[$cfg.GruposDeResponsable[$f.Departamento]].Add($dn)
        }
    }
}
foreach ($adm in $cuentasAdm) { $miembros['G_Adm_Sistemas'].Add($dnUsuario[$adm]) }
foreach ($par in $cuentaGrupo.GetEnumerator()) { $miembros[$par.Value].Add($dnUsuario[$par.Key]) }

# Anidamientos fijos
foreach ($n in ($descG.Keys | Where-Object { $_ -like 'G_Becarios_*' })) { $miembros['G_Becarios'].Add((Get-DNGrupo $n)) }
foreach ($dep in $cfg.Departamentos) { $miembros['G_Empleados'].Add((Get-DNGrupo "G_$dep")) }
$miembros['G_Empleados'].Add((Get-DNGrupo 'G_Becarios'))

Registrar '--- Miembros de los grupos globales ---'
foreach ($n in ($miembros.Keys | Sort-Object)) {
    try { Sincronizar-Miembros $n ($miembros[$n].ToArray()) }
    catch { Registrar "Error en los miembros de ${n}: $($_.Exception.Message)" ERROR }
}

# Las cuentas adm. son las únicas con privilegios: G_Adm_Sistemas dentro de Admins. del dominio
# (se busca por SID, el nombre cambia con el idioma de Windows)
$admsDominio = Get-ADGroup -Identity "$($dominio.DomainSID)-512" -Properties Member
$dnAdmSis = Get-DNGrupo 'G_Adm_Sistemas'
if ($dnAdmSis -and ($admsDominio.Member -notcontains $dnAdmSis)) {
    if (-not $script:Simulacion) { Add-ADGroupMember -Identity $admsDominio -Members $dnAdmSis }
    Registrar "G_Adm_Sistemas añadido a $($admsDominio.Name)" CAMBIO
}

# ---------------------------------------------------------------------------
# 6. Grupos de dominio local DL_ (AGDLP)
# ---------------------------------------------------------------------------
Registrar '--- Grupos de dominio local ---'
$nombresNivel = @{ CT = 'Control total'; M = 'Modificar'; C = 'Consulta'; D = 'Depósito'
                   I = 'Intercambio'; L = 'Listar carpeta'; X = 'DENEGAR' }
foreach ($fila in $tablaDL) {
    try {
        Confirmar-Grupo $fila.Grupo 'DomainLocal' ("{0} - {1}" -f $fila.Carpeta, $nombresNivel[$fila.Nivel])
        $script:Gestionados[(Get-DNGrupo $fila.Grupo)] = $true
        $dnMiembros = @($fila.Miembros -split ',' | ForEach-Object { Get-DNGrupo $_.Trim() })
        Sincronizar-Miembros $fila.Grupo $dnMiembros
    } catch {
        Registrar "Error con $($fila.Grupo): $($_.Exception.Message)" ERROR
    }
}

# ---------------------------------------------------------------------------
# 7. PSO de 15 caracteres
# ---------------------------------------------------------------------------
Registrar '--- Directiva de contraseñas específica ---'
$p = $cfg.PSO
$base = Get-ADDefaultDomainPasswordPolicy
$valoresPSO = @{
    Precedence               = $p.Precedencia
    MinPasswordLength        = $p.Longitud
    PasswordHistoryCount     = $p.Historial
    MaxPasswordAge           = New-TimeSpan -Days $p.CaducidadDias
    MinPasswordAge           = $base.MinPasswordAge
    ComplexityEnabled        = $true
    ReversibleEncryptionEnabled = $false
    LockoutThreshold         = $p.Intentos
    LockoutDuration          = New-TimeSpan -Minutes $p.BloqueoMin
    LockoutObservationWindow = New-TimeSpan -Minutes $p.BloqueoMin
}
try {
    $pso = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq '$($p.Nombre)'"
    if (-not $pso) {
        New-ADFineGrainedPasswordPolicy -Name $p.Nombre -ProtectedFromAccidentalDeletion $true @valoresPSO
        Registrar "PSO $($p.Nombre) creada ($($p.Longitud) caracteres)" CAMBIO
    } else {
        $dif = @{}
        foreach ($k in $valoresPSO.Keys) { if ($pso.$k -ne $valoresPSO[$k]) { $dif[$k] = $valoresPSO[$k] } }
        if ($dif.Count) {
            Set-ADFineGrainedPasswordPolicy -Identity $pso @dif
            Registrar "PSO $($p.Nombre): actualizado $($dif.Keys -join ', ')" CAMBIO
        }
    }
    if (-not $script:Simulacion) {
        $sujetos = @(Get-ADFineGrainedPasswordPolicySubject -Identity $p.Nombre | ForEach-Object { $_.Name })
        $faltan  = @($p.AplicarA | Where-Object { $sujetos -notcontains $_ })
        if ($faltan) {
            Add-ADFineGrainedPasswordPolicySubject -Identity $p.Nombre -Subjects $faltan
            Registrar "PSO $($p.Nombre) aplicada a $($faltan -join ', ')" CAMBIO
        }
    }
} catch {
    Registrar "Error con la PSO: $($_.Exception.Message)" ERROR
}

# ---------------------------------------------------------------------------
# 8. Carpetas personales (opcional, cuando exista el recurso de FILES01)
#    Solo el usuario con Modificar y G_Adm_Sistemas con Control total (Anexo I, ap. 7).
#    OWNER RIGHTS con Modificar evita que el usuario cambie los permisos de lo que crea.
#    Las cuotas (2 GB / 5 GB / 500 MB) se aplican con FSRM en FILES01, no aquí.
# ---------------------------------------------------------------------------
function Set-PermisosCarpeta {
    param([string]$Ruta, [System.Security.Principal.SecurityIdentifier[]]$ControlTotal,
          [System.Security.Principal.SecurityIdentifier[]]$Modificar)
    $acl = Get-Acl -Path $Ruta
    $acl.SetAccessRuleProtection($true, $false)   # corta la herencia sin copiar los permisos heredados
    foreach ($r in @($acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]))) {
        $acl.RemoveAccessRuleSpecific($r)
    }
    $herencia = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $prop     = [System.Security.AccessControl.PropagationFlags]::None
    foreach ($sid in $ControlTotal) {
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', $herencia, $prop, 'Allow')))
    }
    foreach ($sid in $Modificar) {
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'Modify', $herencia, $prop, 'Allow')))
    }
    Set-Acl -Path $Ruta -AclObject $acl
}

if ($RutaPersonales -and -not $script:Simulacion) {
    Registrar "--- Carpetas personales en $RutaPersonales ---"
    if (-not (Test-Path $RutaPersonales)) {
        Registrar "No se puede acceder a ${RutaPersonales}: no se crean carpetas personales" ERROR
    } else {
        $sidSistema   = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18'
        $sidOwnerRights = New-Object System.Security.Principal.SecurityIdentifier 'S-1-3-4'
        $sidAdmSis    = (Get-ADGroup -Identity 'G_Adm_Sistemas').SID
        foreach ($x in $usuarios) {
            if (-not $dnUsuario[$x.Usuario]) { continue }
            $ruta = Join-Path $RutaPersonales $x.Usuario
            try {
                if (-not (Test-Path $ruta)) {
                    New-Item -ItemType Directory -Path $ruta | Out-Null
                    $sidUsuario = (Get-ADUser -Identity $x.Usuario).SID
                    Set-PermisosCarpeta $ruta @($sidSistema, $sidAdmSis) @($sidUsuario, $sidOwnerRights)
                    Registrar "Carpeta personal creada: $ruta" CAMBIO
                }
            } catch {
                Registrar "Error con la carpeta de $($x.Usuario): $($_.Exception.Message)" ERROR
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Cuentas en AD que no están en el CSV (no se tocan: las bajas van por su script)
# ---------------------------------------------------------------------------
$enCsv = @{}; foreach ($x in $usuarios) { $enCsv[$x.Usuario] = $true }
foreach ($u in (Get-ADUser -SearchBase "OU=Usuarios,$raiz" -Filter *)) {
    if (-not $enCsv.ContainsKey($u.SamAccountName)) {
        Registrar "$($u.SamAccountName) está en OU=Usuarios pero no en el CSV (no se modifica)" AVISO
    }
}

# ---------------------------------------------------------------------------
# Contraseñas iniciales de las cuentas creadas en esta ejecución
# ---------------------------------------------------------------------------
$ficheroCred = $null
if ($script:Credenciales.Count -gt 0) {
    if (-not (Test-Path $CarpetaCredenciales)) { New-Item -ItemType Directory -Path $CarpetaCredenciales -Force | Out-Null }
    # Solo Administradores y SYSTEM, sin herencia
    Set-PermisosCarpeta $CarpetaCredenciales @(
        (New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544'),
        (New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18')) @()
    $ficheroCred = Join-Path $CarpetaCredenciales "credenciales-$marca.csv"
    $script:Credenciales | Export-Csv -Path $ficheroCred -Delimiter ';' -Encoding UTF8 -NoTypeInformation
    Registrar "Contraseñas iniciales de $($script:Credenciales.Count) cuentas en $ficheroCred (entregar y borrar)"
}

Registrar ("Fin. Cambios: {0} · cuentas creadas: {1} · avisos: {2} · errores: {3}" -f
           $script:Cambios, $script:Creados, $script:Avisos.Count, $script:Errores.Count)

[pscustomobject]@{
    Simulacion   = $script:Simulacion
    Cambios      = $script:Cambios
    Creados      = $script:Creados
    Avisos       = $script:Avisos.ToArray()
    Errores      = $script:Errores.ToArray()
    Log          = $script:FicheroLog
    Credenciales = $ficheroCred
}
