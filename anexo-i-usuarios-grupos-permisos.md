# Anexo I — Usuarios, grupos y permisos

**Grupo 7:** Berta Sipek y Alex Gutiérrez · **Dominio:** `cibernova.local` · **Actualizado:** 12/11/2026 · **Estado:** diseño, pendiente de implementar con el script de alta

Diseño de OU, grupos AGDLP y matriz de permisos de CiberNova a partir del Anexo I del enunciado.

## 1. Estructura de OU

Los usuarios se organizan en una OU por departamento; la sede se registra en el atributo Oficina (`physicalDeliveryOfficeName`) y en los grupos `G_Sede_*`, como pide el apartado 1 del Anexo.

```
cibernova.local
└── CiberNova
    ├── Usuarios
    │   ├── Direccion
    │   ├── Administracion
    │   ├── RRHH
    │   ├── Comercial
    │   ├── Marketing
    │   ├── Consultoria
    │   ├── Desarrollo
    │   ├── Sistemas
    │   ├── Soporte
    │   └── Legal
    ├── Cuentas_Admin        (adm.*: 6 cuentas)
    ├── Cuentas_Servicio     (svc_backup, svc_web, svc_bbdd, svc_ia)
    ├── Cuentas_Especiales   (recepcion.bcn, auditor.ext)
    ├── Bajas                (cuentas deshabilitadas, apartado 11)
    ├── Grupos
    │   ├── Globales         (G_*)
    │   └── DominioLocal     (DL_*)
    └── Equipos
        ├── Puestos
        └── Recepcion
```

| Decisión | Elegido | Alternativa descartada | Justificación |
| --- | --- | --- | --- |
| Criterio de las OU de usuarios | Por departamento | Por sede | Las GPO que dependen del puesto (redirección de carpetas para todos salvo Dirección y Comercial) se vinculan una vez por OU. Comercial, Consultoría, Desarrollo y Soporte están en varias sedes: por sede habría que duplicar esas GPO |
| Becarios | En la OU de su departamento | OU Becarios propia | Siguen siendo de su departamento; lo que limita sus permisos son los grupos, no la OU (sección 3) |
| Bajas | OU Bajas con la cuenta deshabilitada | Borrar la cuenta | El apartado 11 exige deshabilitar y mover, nunca borrar de inmediato |
| Equipos | OU Equipos con Puestos y Recepcion | Contenedor Computers por defecto | En el contenedor por defecto no se pueden vincular GPO; Recepcion permite limitar recepcion.bcn a su equipo |

## 2. Grupos globales (G_)

Los grupos globales agrupan personas; nunca aparecen en las ACL, solo dentro de grupos DL_ (modelo AGDLP). Los marcados como nuevos no están en el Anexo y son propuesta del grupo.

| Tipo | Grupo | Miembros | Origen |
| --- | --- | --- | --- |
| Departamento | G_Direccion, G_Administracion, G_RRHH, G_Comercial, G_Marketing, G_Consultoria, G_Desarrollo, G_Sistemas, G_Soporte, G_Legal | Personal del departamento sin los becarios | Anexo, ap. 1 |
| Sede | G_Sede_Barcelona, G_Sede_Madrid, G_Sede_Valencia | Todos los empleados de la sede, becarios incluidos | Anexo, ap. 1 |
| Transversal | G_Responsables, G_Proyecto_Sanitario, G_Proyecto_Financiero, G_Comite_Seguridad, G_RRHH_Nominas, G_Becarios | Los del apartado 4 | Anexo, ap. 4 |
| Becarios por departamento | G_Becarios_Desarrollo (nerea.ruiz, kevin.lopez), G_Becarios_Marketing (aitana.sempere), G_Becarios_Soporte (izan.moreno) | Becarios de cada departamento; los tres dentro de G_Becarios | Nuevo |
| Todos los empleados | G_Empleados | Los 10 G_ de departamento + G_Becarios | Nuevo |
| Responsable de Administración | G_Resp_Administracion | rosa.martinez | Nuevo (P-08) |
| Recepción | G_Recepcion | recepcion.bcn | Nuevo (P-44) |
| Auditoría externa | G_Auditores_Ext | auditor.ext | Nuevo (P-27, P-35) |
| Administración técnica | G_Adm_Sistemas | Las 6 cuentas adm.* | Nuevo (ap. 5 y 8) |
| Copias | G_Svc_Backup | svc_backup | Nuevo (ap. 5) |

G_Resp_Administracion, G_Recepcion y G_Auditores_Ext tienen un solo miembro porque los permisos van siempre a grupos: si cambia la persona, se cambia el miembro y no la ACL.

## 3. Becarios: no se les quitan permisos, no se les dan

Los becarios no entran en el G_ de su departamento: así no heredan sus permisos generales y no hace falta denegar nada. Reciben solo lo suyo por G_Becarios_&lt;Dept&gt; y lo común por G_Empleados.

Ejemplo con nerea.ruiz (becaria de Desarrollo, Barcelona):

- G_Becarios_Desarrollo: consulta en Codigo y Releases, modificación en Desarrollo\Becarios (P-21).
- G_Becarios → G_Empleados: consulta en Comunicados, Base_Conocimiento, Plantillas, Formacion y Politicas.
- G_Sede_Barcelona: modificación en Comun\Sedes\Barcelona (P-43).

Prueba 1 del Anexo: borrar en Desarrollo\Codigo da Denegado (solo consulta) y crear en Desarrollo\Becarios da Permitido, sin ningún denegar.

**La única excepción es Proyectos (P-38).** El requisito exige que un becario no acceda aunque se le añada por error a un grupo de proyecto. Solo un denegar lo garantiza, porque en NTFS el denegar gana al permitir. Se aplica una sola regla, en Proyectos, para G_Becarios.

| Decisión | Elegido | Alternativa descartada | Justificación |
| --- | --- | --- | --- |
| Permisos reducidos de becarios | Grupos G_Becarios_&lt;Dept&gt; fuera del G_ de departamento | Meterlos en G_&lt;Dept&gt; y denegar encima | El denegar se hereda y gana siempre: bloquearía también Desarrollo\Becarios y obligaría a excepciones difíciles de depurar. Sumar lo justo es mínimo privilegio |
| Protección de Proyectos (P-38) | Denegar a G_Becarios en Proyectos | Confiar en no añadirlos nunca por error | El requisito pide protegerse precisamente contra ese error humano |

## 4. Matriz de permisos (P-01 a P-44)

Cada celda es el nivel efectivo de ese grupo en esa carpeta, ya sumada la herencia. Lo que no aparece es «sin acceso» y, con ABE, la carpeta no se ve. Además, en toda la estructura G_Adm_Sistemas tiene control total (ap. 8) y G_Svc_Backup, consulta para las copias (ap. 5).

**Niveles:** CT control total · M modificación · C consulta · D depósito (crea y solo ve lo suyo) · I Intercambio (crea; modifica y borra solo lo suyo; consulta lo demás) · L listar solo esta carpeta, para llegar a una subcarpeta · X denegar · — sin acceso.

**Grupos:** Dir G_Direccion · Adm G_Administracion · RRHH G_RRHH · Com G_Comercial · Mkt G_Marketing · Cons G_Consultoria · Des G_Desarrollo · Sis G_Sistemas · Sop G_Soporte · Leg G_Legal · BecDes / BecMkt / BecSop G_Becarios_&lt;Dept&gt; · Bec G_Becarios · Resp G_Responsables · RespAdm G_Resp_Administracion · Nóm G_RRHH_Nominas · Comité G_Comite_Seguridad · ProySan / ProyFin G_Proyecto_* · Sede G_Sede_&lt;Sede&gt; · Empl G_Empleados · Recep G_Recepcion · Audit G_Auditores_Ext.

### 4.1 Dirección, Administración, RRHH, Comercial y Marketing

| Carpeta | Dir | Adm | RRHH | Com | Mkt | Cons | Leg | BecMkt | Resp | RespAdm | Nóm | Empl | Requisito |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Departamentos (raíz) | — | — | — | — | — | — | — | — | — | — | — | L | Navegación |
| Direccion | M | — | — | — | — | — | — | — | L | — | — | L | P-01 |
| Direccion\Actas | M | — | — | — | — | — | — | — | — | — | — | — | P-02 |
| Direccion\Estrategia | M | — | — | — | — | — | — | — | C | — | — | — | P-02 |
| Direccion\Comunicados | M | — | — | — | — | — | — | — | — | — | — | C | P-03 |
| Administracion | C | M | — | L | — | — | L | — | — | — | — | — | P-04 |
| Administracion\Contabilidad | C | M | — | — | — | — | — | — | — | — | — | — | P-04, P-05 |
| Administracion\Facturacion | C | M | — | — | — | — | C | — | — | — | — | — | P-05, P-06 |
| Administracion\Presupuestos | C | M | — | M | — | — | — | — | — | — | — | — | P-05 |
| RRHH | L | — | M | — | — | — | — | — | — | L | — | L | P-07 |
| RRHH\Expedientes | C | — | M | — | — | — | — | — | — | — | — | — | P-09, P-11 (auditoría) |
| RRHH\Nominas | — | — | — | — | — | — | — | — | — | C | M | — | P-08, P-11 (auditoría); herencia cortada |
| RRHH\Seleccion | C | — | M | — | — | — | — | — | — | — | — | — | P-09 |
| RRHH\Buzon_Documentacion | — | — | M | — | — | — | — | — | — | — | — | D | P-10 |
| Comercial | C | — | — | M | C | L | — | — | — | — | — | — | P-12, P-13 |
| Comercial\Clientes | C | — | — | M | C | — | — | — | — | — | — | — | P-12 a P-14 |
| Comercial\Ofertas | C | — | — | M | C | C | — | — | — | — | — | — | P-14 |
| Marketing | C | — | — | L | M | — | — | C | — | — | — | — | P-15, P-17 |
| Marketing\Campanas | C | — | — | M | M | — | — | M | — | — | — | — | P-16, P-17 |
| Marketing\Diseno | C | — | — | — | M | — | — | C | — | — | — | — | P-16, P-17 |

### 4.2 Consultoría, Desarrollo, Sistemas, Soporte y Legal

| Carpeta | Dir | Adm | Com | Cons | Des | Sis | Sop | Leg | BecDes | BecSop | Comité | Empl | Audit | Requisito |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Consultoria (y subcarpetas) | C | — | — | M | M | — | C | — | — | — | — | — | — | P-18, P-19 |
| Desarrollo | — | — | — | L | M | L | L | — | L | — | — | — | — | P-20 |
| Desarrollo\Codigo | — | — | — | C | M | — | — | — | C | — | — | — | — | P-21, P-23 |
| Desarrollo\Releases | — | — | — | — | M | C | C | — | C | — | — | — | — | P-21, P-22 |
| Desarrollo\Becarios | — | — | — | — | M | — | — | — | M | — | — | — | — | P-21 |
| Sistemas | — | — | — | — | — | CT | L | — | — | — | — | — | L | P-24 |
| Sistemas\Documentacion | — | — | — | — | — | CT | C | — | — | — | — | — | C | P-25, P-27 |
| Sistemas\Software | — | — | — | — | — | CT | C | — | — | — | — | — | — | P-25 |
| Sistemas\Privado | — | — | — | — | — | CT | — | — | — | — | — | — | — | P-26 |
| Soporte | — | — | — | L | L | M | M | — | — | C | — | L | — | P-28, P-31 |
| Soporte\Incidencias | — | — | — | C | C | M | M | — | — | M | — | — | — | P-29, P-31 |
| Soporte\Base_Conocimiento | — | — | — | — | — | M | M | — | — | C | — | C | — | P-30 |
| Legal | L | L | L | — | — | L | — | M | — | — | L | L | L | P-32 |
| Legal\Contratos | C | C | C | — | — | — | — | M | — | — | — | — | — | P-33 |
| Legal\Politicas | — | — | — | — | — | M | — | M | — | — | — | C | — | P-34 |
| Legal\Comite_Seguridad | — | — | — | — | — | — | — | — | — | — | M | — | C | P-35; herencia cortada |

### 4.3 Proyectos y Común

| Carpeta | Dir | RRHH | Mkt | Leg | Bec | ProySan | ProyFin | Sede | Empl | Recep | Requisito |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Proyectos | L | — | — | L | X | L | L | — | — | — | P-38 |
| Proyectos\Sanitario | C | — | — | C | X | M | — | — | — | — | P-36, P-38, P-39 (auditoría) |
| Proyectos\Financiero | C | — | — | C | X | — | M | — | — | — | P-37, P-38 |
| Comun | — | — | — | — | — | — | — | — | C | C | P-44 |
| Comun\Plantillas | — | — | M | — | — | — | — | — | C | C | P-40, P-44 |
| Comun\Intercambio | — | — | — | — | — | — | — | — | I | — | P-41, P-44; herencia cortada |
| Comun\Formacion | — | M | — | — | — | — | — | — | C | C | P-42, P-44 |
| Comun\Sedes (cada sede) | — | — | — | — | — | — | — | M | C | C | P-43, P-44 |

**Herencia cortada** en RRHH\Nominas (el resto de RRHH no debe verla), Legal\Comite_Seguridad (el resto de Legal tampoco) y Comun\Intercambio (recepcion.bcn no tiene acceso). **Auditoría de acceso** (SACL) en RRHH\Nominas, RRHH\Expedientes y Proyectos\Sanitario (P-11, P-39), también para Sistemas.

**Comprobación con las pruebas del Anexo:** 1 nerea.ruiz no borra en Codigo y sí crea en Becarios · 2 adrian.campos entra en Administracion y solo ve Presupuestos · 3 eva.marquez no ve Proyectos\Sanitario · 5 irene.moreno no ve Nominas · 6 rosa.martinez abre Nominas pero no guarda · 13 hugo.pascual no puede modificar Comercial.

## 5. Grupos de dominio local (DL_)

Hay un DL_ por cada permiso que se añade en una carpeta; lo heredado no necesita grupo propio. Formato DL_&lt;Carpeta&gt;_&lt;Nivel&gt;, como el Anexo. Son 62 grupos (contando uno por sede) y los crea el script.

| Grupo DL_ | Carpeta | Nivel | Miembros (G_) |
| --- | --- | --- | --- |
| DL_Departamentos_L | Departamentos | L | G_Empleados |
| DL_Direccion_M | Direccion | M | G_Direccion |
| DL_Direccion_L | Direccion | L | G_Empleados |
| DL_Direccion_Estrategia_C | Direccion\Estrategia | C | G_Responsables |
| DL_Direccion_Comunicados_C | Direccion\Comunicados | C | G_Empleados |
| DL_Administracion_M | Administracion | M | G_Administracion |
| DL_Administracion_C | Administracion | C | G_Direccion |
| DL_Administracion_L | Administracion | L | G_Comercial, G_Legal |
| DL_Administracion_Facturacion_C | Administracion\Facturacion | C | G_Legal |
| DL_Administracion_Presupuestos_M | Administracion\Presupuestos | M | G_Comercial |
| DL_RRHH_M | RRHH | M | G_RRHH |
| DL_RRHH_L | RRHH | L | G_Empleados |
| DL_RRHH_Expedientes_C | RRHH\Expedientes | C | G_Direccion |
| DL_RRHH_Nominas_M | RRHH\Nominas | M | G_RRHH_Nominas |
| DL_RRHH_Nominas_C | RRHH\Nominas | C | G_Resp_Administracion |
| DL_RRHH_Seleccion_C | RRHH\Seleccion | C | G_Direccion |
| DL_RRHH_Buzon_Documentacion_D | RRHH\Buzon_Documentacion | D | G_Empleados |
| DL_Comercial_M | Comercial | M | G_Comercial |
| DL_Comercial_C | Comercial | C | G_Direccion, G_Marketing |
| DL_Comercial_L | Comercial | L | G_Consultoria |
| DL_Comercial_Ofertas_C | Comercial\Ofertas | C | G_Consultoria |
| DL_Marketing_M | Marketing | M | G_Marketing |
| DL_Marketing_C | Marketing | C | G_Direccion, G_Becarios_Marketing |
| DL_Marketing_L | Marketing | L | G_Comercial |
| DL_Marketing_Campanas_M | Marketing\Campanas | M | G_Becarios_Marketing, G_Comercial |
| DL_Consultoria_M | Consultoria | M | G_Consultoria, G_Desarrollo |
| DL_Consultoria_C | Consultoria | C | G_Soporte, G_Direccion |
| DL_Desarrollo_M | Desarrollo | M | G_Desarrollo |
| DL_Desarrollo_L | Desarrollo | L | G_Becarios_Desarrollo, G_Consultoria, G_Sistemas, G_Soporte |
| DL_Desarrollo_Codigo_C | Desarrollo\Codigo | C | G_Becarios_Desarrollo, G_Consultoria |
| DL_Desarrollo_Releases_C | Desarrollo\Releases | C | G_Becarios_Desarrollo, G_Sistemas, G_Soporte |
| DL_Desarrollo_Becarios_M | Desarrollo\Becarios | M | G_Becarios_Desarrollo |
| DL_Sistemas_CT | Sistemas | CT | G_Sistemas |
| DL_Sistemas_L | Sistemas | L | G_Soporte, G_Auditores_Ext |
| DL_Sistemas_Documentacion_C | Sistemas\Documentacion | C | G_Soporte, G_Auditores_Ext |
| DL_Sistemas_Software_C | Sistemas\Software | C | G_Soporte |
| DL_Soporte_M | Soporte | M | G_Soporte, G_Sistemas |
| DL_Soporte_C | Soporte | C | G_Becarios_Soporte |
| DL_Soporte_L | Soporte | L | G_Empleados |
| DL_Soporte_Incidencias_M | Soporte\Incidencias | M | G_Becarios_Soporte |
| DL_Soporte_Incidencias_C | Soporte\Incidencias | C | G_Consultoria, G_Desarrollo |
| DL_Soporte_Base_Conocimiento_C | Soporte\Base_Conocimiento | C | G_Empleados |
| DL_Legal_M | Legal | M | G_Legal |
| DL_Legal_L | Legal | L | G_Auditores_Ext, G_Empleados |
| DL_Legal_Contratos_C | Legal\Contratos | C | G_Direccion, G_Administracion, G_Comercial |
| DL_Legal_Politicas_M | Legal\Politicas | M | G_Sistemas |
| DL_Legal_Politicas_C | Legal\Politicas | C | G_Empleados |
| DL_Legal_Comite_Seguridad_M | Legal\Comite_Seguridad | M | G_Comite_Seguridad |
| DL_Legal_Comite_Seguridad_C | Legal\Comite_Seguridad | C | G_Auditores_Ext |
| DL_Proyectos_L | Proyectos | L | G_Proyecto_Sanitario, G_Proyecto_Financiero, G_Legal, G_Direccion |
| DL_Proyectos_Denegar | Proyectos | Denegar | G_Becarios |
| DL_Proyectos_Sanitario_M | Proyectos\Sanitario | M | G_Proyecto_Sanitario |
| DL_Proyectos_Sanitario_C | Proyectos\Sanitario | C | G_Legal, G_Direccion |
| DL_Proyectos_Financiero_M | Proyectos\Financiero | M | G_Proyecto_Financiero |
| DL_Proyectos_Financiero_C | Proyectos\Financiero | C | G_Legal, G_Direccion |
| DL_Comun_C | Comun | C | G_Empleados, G_Recepcion |
| DL_Comun_Plantillas_M | Comun\Plantillas | M | G_Marketing |
| DL_Comun_Intercambio_I | Comun\Intercambio | I | G_Empleados |
| DL_Comun_Formacion_M | Comun\Formacion | M | G_RRHH |
| DL_Comun_Sedes_Barcelona_M (y _Madrid_M, _Valencia_M) | Comun\Sedes\Barcelona (y Madrid, Valencia) | M | G_Sede_Barcelona (y G_Sede_Madrid, G_Sede_Valencia) |

Ejemplo de AGDLP: adrian.campos → G_Comercial → DL_Administracion_Presupuestos_M → ACL de Presupuestos. Si cambia de departamento, solo se cambia su G_; ninguna ACL se toca.

## 6. Otras decisiones

| Tema | Elegido | Alternativa | Justificación |
| --- | --- | --- | --- |
| Permisos de recurso compartido frente a NTFS | Recurso compartido: Usuarios autentificados con Cambiar y Administradores con Control total; el control fino, en NTFS | Repetir las restricciones en el recurso compartido | Un solo sitio donde revisar y depurar los permisos |
| Buzon_Documentacion (P-10) e Intercambio (P-41) | Crear archivos en la carpeta + CREATOR OWNER con Modificar; ABE oculta lo que no es propio | Una carpeta por usuario | Patrón de «depósito» que propone el Anexo; cada uno solo ve lo suyo (prueba 7) |
| Carpetas personales | Solo el propietario con Modificar y G_Adm_Sistemas con Control total; cuotas FSRM de 2 GB, 5 GB y 500 MB con aviso al 90 % | Dar Control total al usuario | El Anexo pide que el usuario no pueda cambiar los permisos (ap. 7) |
| svc_backup | PENDIENTE: G_Svc_Backup con consulta en toda la estructura, o el grupo integrado Operadores de copia de seguridad | — | Se decide al montar BACKUP |

Dirección no tiene acceso a Desarrollo, Sistemas ni Soporte porque el Anexo no lo menciona, y lo no mencionado es «sin acceso». Las cuentas personales de Sistemas son usuarios estándar (ap. 5); el control total técnico es de G_Adm_Sistemas.

## 7. Pendiente

- Diagrama de OU y de anidamiento de grupos (entregable del ap. 12).
- Script de alta idempotente que lea el CSV y cree OU, grupos, usuarios y carpetas personales.
- Evidencias de las 15 pruebas de verificación.
