# Configuración del alta de usuarios de CiberNova (Anexo I).
# La lee scripts/alta-usuarios.ps1. Aquí van los datos que NO vienen en el CSV:
# fechas, horarios, cuentas especiales y la directiva de 15 caracteres.
# Ninguna contraseña se guarda en este fichero.
@{
    Empresa = 'CiberNova Solutions'

    # Departamentos (= nombre de la OU y del grupo G_<Dept>) y sedes (G_Sede_<Sede>)
    Departamentos = @('Direccion', 'Administracion', 'RRHH', 'Comercial', 'Marketing',
                      'Consultoria', 'Desarrollo', 'Sistemas', 'Soporte', 'Legal')
    Sedes = @('Barcelona', 'Madrid', 'Valencia')

    # Grupos transversales del apartado 4 (valores válidos de la columna GruposAdicionales)
    Transversales = @('Responsables', 'Proyecto_Sanitario', 'Proyecto_Financiero',
                      'Comite_Seguridad', 'RRHH_Nominas', 'Becarios')

    # El responsable (Responsable=Si) de estos departamentos entra además en este grupo
    # (P-08: el responsable de Administración consulta Nóminas)
    GruposDeResponsable = @{ Administracion = 'G_Resp_Administracion' }

    # Zona horaria con la que se calculan los horarios de inicio de sesión
    ZonaHoraria = 'Romance Standard Time'

    # Becarios (ap. 6): caducan el 30/06/2027 (la cuenta caduca al empezar el 01/07)
    # y solo pueden iniciar sesión de lunes a viernes de 8:00 a 15:00.
    Becarios = @{
        Caducidad = '2027-07-01'
        Dias      = @(1, 2, 3, 4, 5)   # 0 = domingo ... 6 = sábado
        HoraDesde = 8
        HoraHasta = 15                 # sin incluir: la última hora permitida es 14:00-15:00
    }

    # Longitud de la contraseña inicial generada (cumple también los 15 caracteres)
    LongitudContrasena = 16

    # Directiva de contraseñas específica (PSO) para Dirección, Sistemas y cuentas adm.
    # El resto de valores son los de la directiva del dominio (ad-03-estructura.yml).
    PSO = @{
        Nombre       = 'PSO_15_Caracteres'
        Precedencia  = 10
        Longitud     = 15
        Historial    = 10
        CaducidadDias = 90
        Intentos     = 5
        BloqueoMin   = 15
        AplicarA     = @('G_Direccion', 'G_Sistemas', 'G_Adm_Sistemas')
    }

    # Cuentas que no salen del CSV (ap. 5). Las adm.<usuario> se generan a partir de
    # las filas del CSV cuya columna Observaciones menciona la cuenta administrativa.
    CuentasEspeciales = @(
        @{
            Usuario     = 'recepcion.bcn'
            Nombre      = 'Recepción Barcelona'
            OU          = 'Cuentas_Especiales'
            Grupo       = 'G_Recepcion'
            Descripcion = 'Cuenta compartida de recepción (sede Barcelona)'
            Oficina     = 'Barcelona'
            Habilitada  = $true
            NoCambiaContrasena = $true
            # Nombre del equipo de recepción (OU=Recepcion). Mientras sea $null no se limita.
            Equipos     = $null
            # Perfil obligatorio (Anexo I). Windows añade .V6: la carpeta es recepcion.V6
            ProfilePath = '\\files01.cibernova.local\Perfiles$\Obligatorio\recepcion'
        }
        @{
            Usuario     = 'auditor.ext'
            Nombre      = 'Auditor externo'
            OU          = 'Cuentas_Especiales'
            Grupo       = 'G_Auditores_Ext'
            Descripcion = 'Auditoría externa: se habilita solo durante la auditoría'
            Habilitada  = $false
            # Fin de la Fase 3 (fecha a confirmar con el profesorado). Mientras sea $null no caduca.
            Caducidad   = $null
            Horario     = @{ Dias = @(1, 2, 3, 4, 5); HoraDesde = 8; HoraHasta = 20 }
        }
        @{
            Usuario     = 'svc_backup'
            Nombre      = 'Servicio de copias'
            OU          = 'Cuentas_Servicio'
            Grupo       = 'G_Svc_Backup'
            Descripcion = 'Cuenta de servicio de las copias de seguridad (sin inicio de sesión interactivo)'
            Habilitada  = $true
            Servicio    = $true
        }
        @{
            Usuario     = 'svc_web'
            Nombre      = 'Servicio web'
            OU          = 'Cuentas_Servicio'
            Descripcion = 'Cuenta de servicio de la aplicación web'
            Habilitada  = $true
            Servicio    = $true
        }
        @{
            Usuario     = 'svc_bbdd'
            Nombre      = 'Servicio base de datos'
            OU          = 'Cuentas_Servicio'
            Descripcion = 'Cuenta de servicio de la base de datos'
            Habilitada  = $true
            Servicio    = $true
        }
        @{
            Usuario     = 'svc_ia'
            Nombre      = 'Servicio IA'
            OU          = 'Cuentas_Servicio'
            Descripcion = 'Cuenta de servicio de IA (Fase 2): solo lectura de logs'
            Habilitada  = $false
            Servicio    = $true
        }
    )
}
