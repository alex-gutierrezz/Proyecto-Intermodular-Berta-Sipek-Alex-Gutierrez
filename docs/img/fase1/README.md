# Capturas de la Fase 1

Capturas de la Fase 1 (Infraestructura) que sirven de evidencia para la [`memoria`](../../memoria-fase1.md). Están ordenadas por **día de trabajo** (una carpeta por fecha, `DD-MM`) y, dentro de cada día, por bloque de tareas. El número del nombre indica el orden en que se hicieron. Las capturas de la Fase 2 van en [`../fase2/`](../fase2/).

## Estructura

```
fase1/
├── 12-11/                      Preparación de las VMs Windows e instalación de WS2025
└── 16-11/
    ├── 01-dc01-preparacion/    Drivers VirtIO, IP fija, DNS y WinRM en DC01
    ├── 02-dc01-dominio/        Verificación del dominio con Ansible
    └── 03-cierre/              Apagado ordenado de las VMs en proxmoxAB
├── 17-11/
│   └── 04-firewalls/           Instalación y configuración base de FW01 y FW02 (OPNsense)
└── 19-11/
    ├── 04-firewalls/           HA, VIP CARP, NAT, corte de red de Proxmox y failover (28 a 40)
    ├── 05-dc02/                Preparación, promoción y réplica de DC02
    ├── 06-dhcp01/              Drivers VirtIO en DHCP01
    ├── 07-dhcp02/              Drivers VirtIO en DHCP02
    ├── 08-ad-estructura-dhcp/  OUs, unión al dominio y DHCP con failover
    └── 09-redimensionado/      RAM y CPU de las VMs tras el cambio
```

## 12/11/2026 — Preparación de las VMs Windows

Carpeta [`12-11/`](12-11/). La columna *Sección* indica dónde se enlaza en la memoria.

| Fichero | Sección | Qué se ve |
| --- | --- | --- |
| `12-11/06-dc01-hardware-vlan40.png` | 3 (bitácora del 12/11) | Web de Proxmox, pestaña *Hardware* de la VM 100 (DC01) con la etiqueta `ws2025`: 4 GiB de RAM, 2 núcleos tipo `host`, SeaBIOS, máquina `pc-i440fx-11.0`, controlador VirtIO SCSI single, `WS2025_eval.iso` en ide2 y `virtio-win.iso` en ide3, disco `scsi0` de 60 GB en `local-lvm` (discard e iothread) y tarjeta `virtio` en `vmbr1` con `firewall=1` y **`tag=40`** |
| `12-11/07-proxmox-isos.png` | 7 | Shell de proxmoxAB: `ls -lh` en `/var/lib/vz/template/iso` con las cuatro ISO (18 GB en total): la de idiomas y características LOF (6,4 GB), Ubuntu Server 24.04.4 (3,2 GB), `virtio-win.iso` (837 MB) y `WS2025_eval.iso` (7,7 GB) |
| `12-11/09-git-commit-playbook-proxmox.png` | 9 | VM Ansible, en `~/cibernova/ansible`: `git add` de `inventario.ini` y `playbooks/proxmox-vms-windows.yml` y commit `06aff21` `feat(proxmox)` (2 ficheros, 107 líneas añadidas) |
| `12-11/09-proxmox-playbook-codigo.png` | 9.5 | Primera parte de `proxmox-vms-windows.yml`: se ejecuta sobre el grupo `proxmox`; variables (`local-lvm`, `vmbr1`, VLAN 40, las dos ISO, etiqueta `ws2025`) y la lista de las 7 VMs con su id, núcleos, RAM y disco; primeras tareas: comprobar que existen las ISO, **parar si falta alguna antes de borrar nada**, leer el `qm config` de cada VM y crear `/root/qm-antes` para guardar la configuración antigua |
| `12-11/09-proxmox-playbook-idempotencia.png` | 3 y 9.5 | Segunda ejecución del playbook: las tareas *Borrar las VMs antiguas* y *Crear las VMs nuevas* salen en **skipping** para las 7 VMs (no cambia nada) y la tarea final muestra el `qm list` con las Windows paradas, cada una con su disco |
| `12-11/11-ad-instalador-vioscsi.png` | 11.1 | Instalador de Windows Server 2025, pantalla *Instalar el controlador*: ruta `E:\vioscsi\2k25\amd64` y el controlador **Red Hat VirtIO SCSI pass-through controller** (`vioscsi.inf`) listo para instalar |
| `12-11/11-ad-instalador-disco.png` | 11.1 | Instalador de Windows Server 2025, *Seleccionar ubicación*: después de cargar `vioscsi` ya aparece el **Disco 0** con 60 GB sin asignar |
| `12-11/12-p2-qm-config-antes.png` | 12 (P2) | Shell de proxmoxAB con el `qm config` de las 7 VMs Windows **antes** del cambio: todas tienen montada la ISO LOF en ide2, ninguna tiene `tag` en `net0`, cinco usan tarjeta `e1000` (DC01 y DC02 ya tenían `virtio`), y la 102 (DHCP) y la 109 (FILES02) arrancan con `order=ide2;net0` (sin el disco) y tienen un disco `unused0` |
| `12-11/12-p2-qm-list-antes.png` | 12 (P2) | `qm list` **antes** del cambio: la 102 (DHCP) y la 109 (FILES02) muestran `BOOTDISK 0.00`; debajo, `ls` de la carpeta de ISO con solo la LOF y la de Ubuntu (todavía faltaba la de WS2025) |
| `12-11/12-p2-qm-list-despues.png` | 3 (bitácora del 12/11) | Salida de la tarea *Mostrar qm list* del playbook **después** del cambio: la 102 ya tiene 40 GB y la 109 60 GB; todas las Windows están paradas y el resto de VMs en marcha |

## 16/11/2026 — DC01: preparación, dominio y cierre

Carpeta [`16-11/`](16-11/). Estas capturas se enlazan en el apartado 11.2 de la memoria.

### `01-dc01-preparacion/` — Drivers, red y WinRM en DC01

| Fichero | Qué se ve |
| --- | --- |
| `01-dc01-powershell-inicial.jpg` | Consola de Proxmox (noVNC) de la VM 100 (DC01) con *Windows PowerShell* abierto como administrador sobre el Administrador del servidor |
| `02-dc01-incidencia-teclado-novnc.png` | **Incidencia de teclado** en la consola noVNC: al escribir `Get-NetAdapter \| Format-Table ...` (Sirve para mostrar los adaptadores de red del ordenador en una tabla, seleccionando únicamente tres datos concretos) aparece `get'netadapter ç format'table`, porque la distribución del teclado no coincide (el guion sale como `'` y la barra vertical como `ç`) |
| `03-dc01-sconfig-menu-winrm-habilitado.png` | Menú de `SConfig` en Windows Server 2025 Standard Evaluation: grupo de trabajo `WORKGROUP`, nombre provisional `WIN-HNGB913JVHC`, **Administración remota habilitada** y Escritorio remoto deshabilitado |
| `04-dc01-sin-adaptadores-de-red.png` | `SConfig` → *Configuración de red*: la lista de adaptadores sale **vacía** porque Windows aún no tiene el driver de la tarjeta VirtIO |
| `05-dc01-explorador-unidades-cd.jpg` | Explorador de archivos de DC01: en el panel lateral se ven las dos unidades de CD, D: (instalador de WS2025) y E: (`virtio-win`) |
| `06-dc01-cd-virtio-guest-tools.jpg` | Contenido de la unidad E: (`virtio-win-0.1.302`): carpetas de drivers (`vioscsi`, `viostor`, `vioserial`...) y el instalador `virtio-win-guest-tools` |
| `07-dc01-instalador-guest-tools.jpg` | Pantalla de bienvenida del instalador *Virtio-win guest tools*, con las licencias (MS-RL, GPL v2, Apache 2) |
| `08-dc01-componentes-drivers.jpg` | *Virtio-win-driver-installer*, pantalla *Custom Setup*: lista de drivers que se instalan (Balloon, Network, Pvpanic, Fwcfg, Qemupciserial, Viinput, Viorng, Vioscsi, Vioserial...) |
| `09-dc01-instalando-drivers.jpg` | Barra de progreso: *Installing Windows Virtio-Win Drivers* |
| `10-dc01-guest-tools-instaladas.jpg` | Fin del instalador: *Installation Successfully* |
| `11-dc01-adaptador-virtio-detectado.png` | `SConfig` → *Configuración de red*: ahora aparece el adaptador 6, **Red Hat VirtIO Ethernet Adapter**, con una IP automática `169.254.80.124` |
| `12-dc01-config-adaptador-antes.png` | Detalle del adaptador **antes** de configurarlo: IP APIPA `169.254.80.124/16`, DHCP habilitado y sin puerta de enlace ni DNS |
| `13-dc01-ip-estatica-datos.png` | Introducción de la IP estática: `192.168.40.10`, máscara `255.255.255.0` (valor por defecto) y puerta de enlace `192.168.40.1` |
| `14-dc01-ip-estatica-aplicada.png` | Mensajes de confirmación: DHCP deshabilitado, puerta de enlace y dirección IP aplicadas correctamente |
| `15-dc01-adaptador-con-ip-fija.png` | Detalle del adaptador **después**: `192.168.40.10/24`, DHCP `False`, puerta de enlace `192.168.40.1` y todavía sin servidores DNS |
| `16-dc01-dns-asignados.png` | Opción *Establecer servidores DNS*: se asignan `8.8.8.8` y `1.1.1.1`, antes de crear el dominio |
| `17-dc01-ping-ansible-e-internet.png` | PowerShell de DC01: `ping 192.168.40.5` a la VM Ansible (0 % perdidos, < 1 ms) y `ping 8.8.8.8` a Internet (0 % perdidos, 12 ms), que confirma el routing y el NAT de Proxmox |
| `18-dc01-winrm-test-wsman-ok.png` | `Enable-PSRemoting -Force -SkipNetworkProfileCheck`(Sirve para habilitar la administración remota de PowerShell en un equipo Windows, permitiendo que otros equipos puedan ejecutar comandos de PowerShell de forma remota) y `Test-WSMan localhost` (Sirve para comprobar si el servicio WinRM (Windows Remote Management) está funcionando correctamente en el propio ordenador) con respuesta correcta (fabricante Microsoft, pila 3.0): **WinRM listo para Ansible** |

### `02-dc01-dominio/` — Verificación del dominio

| Fichero | Qué se ve |
| --- | --- |
| `00-shell-proxmox-teclado-ok.png` | Shell de proxmoxAB: prueba de teclado con caracteres especiales (`a-b_c\|d/e:f~g$h>i`), que salen correctos; después, `ssh` de root a `alex@192.168.40.5` (VM Ansible): primero `Host key verification failed` y, al aceptar la clave, **`Permission denied (publickey,password)`** |
| `01-dc01-verificacion-dominio-fsmo-dcdiag.jpg` | VM Ansible: `git log` (último commit `06aff21`), contraseña de Vault y ejecución de la verificación sobre `cn-dc01`. Resultados: dominio `cibernova.local` (NetBIOS `CIBERNOVA`) con nivel `Windows2025Domain`, **DC01 como único DC** y con los roles PDC, RID y Esquema; `dcdiag` **no supera** las pruebas `DFSREvent` (avisos de SYSVOL) y `SystemLog` (error `0x0000158C`: DC01 y CIBERNOVA con el mismo SID de máquina). Las tildes salen como `�` por la codificación de la salida de Windows |
| `02-dc01-verificacion-dns-recap.jpg` | Continuación: resolución DNS (`dc01` → `192.168.40.10`, `db01` → `192.168.40.40`, `web01` → `192.168.100.30`, `www.google.com` resuelve; **`dc02` no resuelve**), resumen de replicación vacío (solo hay un DC), la parte de DHCP en *skipping* (sin hosts) y `PLAY RECAP` de `cn-dc01` con `ok=5`, `changed=0` y `failed=0` |

### `03-cierre/` — Apagado ordenado

| Fichero | Qué se ve |
| --- | --- |
| `01-proxmox-vms-antes-de-apagar.png` | `qm list` en proxmoxAB antes de apagar: en marcha DC01, WEB01, WEB02, DB01, DB02, Ansible y CMK; el resto parado |
| `02-proxmox-todas-las-vms-apagadas.jpg` | Apagado con `qm shutdown <id> --timeout 300` en segundo plano para cada VM, con aviso de que el QEMU Guest Agent no responde en la 111 (Ansible); termina en `FIN` y el `qm list` final muestra **todas las VMs paradas** |



## 17/11/2026 — Firewalls OPNsense (FW01 y FW02)

Carpeta [`17-11/04-firewalls/`](17-11/04-firewalls/). Estas capturas se enlazan en el apartado 6.4 de la memoria. El zip de la sesión traía también las carpetas `01` a `03`, que son las del 16/11 y ya están en [`16-11/`](16-11/).

| Fichero | Qué se ve |
| --- | --- |
| `01-proxmox-escaneo-vhid-carp-aula.jpg` | Consola de proxmoxAB con `tcpdump` de anuncios VRRP/CARP en la red del aula: ya se usan el **vrid 8** (desde 192.168.202.38) y el **vrid 34** (desde 192.168.202.35), por eso elegimos el VHID 7 |
| `02-proxmox-backup-red-y-versiones-opnsense.png` | Copias de la red de Proxmox (`/root/interfaces.bak`, `interfaces.pre-ad` y la nueva **`interfaces.pre-firewall`** del 17/11), versiones de OPNsense publicadas (de la 24.7 a la **26.7**) y la carpeta de ISO |
| `03-proxmox-iso-opnsense-checksum-ok.png` | Descarga de `OPNsense-26.7-dvd-amd64.iso.bz2` (471 MB) y su SHA256, que coincide con el publicado |
| `04-proxmox-vms-fw01-fw02-creadas.png` | Creación de las VMs **113 (FW01)** y **114 (FW02)** y `qm config` de FW01: 2 núcleos `host`, 4096 MB, disco de 20 GB en `local-lvm`, ISO de OPNsense en ide2, `onboot: 1`, etiqueta `firewall` y 5 tarjetas VirtIO: `net0` en `vmbr0` y `net1` a `net4` en `vmbr1` con las etiquetas 40, 50, 100 y 99 |
| `05-fw01-modo-live-lan-en-vtnet0-riesgo-dhcp.jpg` | Modo live de OPNsense en FW01: por defecto asigna **LAN → vtnet0**, que es la red del aula; con un DHCP activo en esa LAN habría repartido IPs al aula (P17) |
| `06-proxmox-link-down-wan-durante-instalacion.png` | `qm set` de las VMs 113 y 114: `net0` en `vmbr0` con **`link_down=1`** mientras se instala |
| `07-fw01-instalador-menu.jpg` | Menú del instalador de OPNsense 26.7 con las opciones *Install (ZFS)* e *Install (UFS)* |
| `08-fw01-confirmar-disco-da0.jpg` | *UFS Configuration*: confirmación para borrar el disco `da0` |
| `09-fw01-instalando.jpg` | Progreso de la instalación en FW01 |
| `10-fw01-configuracion-final-root.jpg` | *Final Configuration*: cambio de la contraseña de root y *Complete Install* |
| `11-fw02-instalando.jpg` | Progreso de la instalación en FW02 |
| `12-fw01-asignacion-interfaces.jpg` | Asignación de interfaces en la consola de FW01: WAN → vtnet0, LAN → vtnet1, OPT1 → vtnet2, OPT2 → vtnet3 y OPT3 → vtnet4 |
| `13-fw01-lan-wan-configuradas.jpg` | Menú de consola de FW01 (OPNsense 26.7): LAN `192.168.40.2/24` y WAN `192.168.202.84/22`; las OPT todavía sin IP |
| `14-fw01-ping-internet-ok.jpg` | Opción 7 (*Ping host*) desde FW01 a `8.8.8.8`: 3 paquetes, 0 % perdidos, unos 11 ms |
| `15-fw02-asignacion-interfaces.jpg` | La misma asignación de interfaces en FW02 |
| `16-fw02-incidencia-dhclient-antiguo.png` | Procesos `dhclient` que siguen vivos en `vtnet0` y `vtnet1` de FW02 (P20) |
| `17-fw02-reinicio-limpio-lan-wan.jpg` | FW02 después del reinicio limpio: LAN `192.168.40.3/24` y WAN `192.168.202.85/22` |
| `18-fw01-reinicio-limpio-lan-wan.jpg` | FW01 después del reinicio limpio: LAN `192.168.40.2/24` y WAN `192.168.202.84/22` |
| `19-proxmox-ping-y-web-gui-ambos-fw-ok.png` | Desde proxmoxAB: ping a 192.168.40.2 y 192.168.40.3 correcto y web de FW01 y FW02 con **HTTP 200** |
| `20-fw01-asistente-datos-generales.png` | Asistente web de FW01: hostname `fw01`, dominio `cibernova.local`, zona `Europe/Madrid`, DNS 8.8.8.8 y 1.1.1.1 y Unbound activado |
| `21-fw01-asistente-wan-gateway.png` | Asistente de FW01, WAN estática `192.168.202.84/22`, puerta de enlace `192.168.200.254` y **Block RFC1918 Private Networks desmarcado** (la WAN es la red privada del aula) |
| `22-fw01-asistente-terminado.jpg` | *Finished initial configuration!* en FW01 (`root@fw01.cibernova.local`) |
| `23-fw01-reglas-sync-clientes-dmz.jpg` | *Firewall: Rules* de FW01: regla flotante **TEMPORAL** que permite todo desde CLIENTES y DMZ (se restringe en la Fase 3), reglas por defecto de la LAN y regla **SYNC** que permite pfsync y XMLRPC entre FW01 y FW02 |
| `24-fw02-asistente-datos-generales.jpg` | Asistente web de FW02: hostname `fw02` con los mismos datos que FW01 |
| `25-fw02-asistente-terminado.jpg` | *Finished initial configuration!* en FW02 (`root@fw02.cibernova.local`) |
| `26-fw02-interfaces-configuradas.jpg` | *Interfaces: Overview* de FW02: WAN `192.168.202.85/22` con gateway `192.168.200.254`, LAN `192.168.40.3/24`, CLIENTES `192.168.50.3/24`, DMZ `192.168.100.3/24` y SYNC `192.168.99.2/24` |
| `27-fw02-regla-sync-aplicada.jpg` | *Firewall: Rules* de FW02 con la regla SYNC aplicada (la regla TEMPORAL llegará al sincronizar desde FW01) |

## 19/11/2026 — Firewalls en HA, DC02, estructura de AD y DHCP con failover

Carpeta [`19-11/`](19-11/). Estas capturas se enlazan en los apartados 6.4, 8.1 y 11.3 de la memoria. El zip de la sesión traía también las capturas 24 a 27 de `04-firewalls`, que son las del 17/11 y ya están en [`17-11/04-firewalls/`](17-11/04-firewalls/).

### `04-firewalls/` — HA, VIP CARP, NAT, corte de red y failover

La numeración sigue la de [`17-11/04-firewalls/`](17-11/04-firewalls/).

| Fichero | Qué se ve |
| --- | --- |
| `28-fw01-ha-ajustes.jpg` | *System: High Availability: Settings* en FW01: estados por **SYNC**, *Synchronize Peer IP* y *Synchronize Config* a `192.168.99.2`, usuario `root` (contraseña vacía en la captura) y *Select All* en los servicios a sincronizar |
| `29-fw01-ha-conectado-con-fw02.jpg` | *High Availability: Status* en FW01: ve las versiones de FW02 (firmware, base y kernel **26.7**) y la lista de servicios, con *Synchronize and reconfigure all* |
| `30-fw01-carp-wan-master.jpg` | *Virtual IPs: Status* en FW01: la VIP de la WAN `192.168.202.86` con **VHID 7** (freq. 1/0) en **MASTER** |
| `31-fw02-carp-wan-backup.jpg` | La misma VIP en FW02, con VHID 7 (freq. 1/100) en **BACKUP** |
| `32-fw01-nat-salida-vip.jpg` | *Firewall: NAT: Source NAT* en modo **Hybrid**: regla en la WAN con origen `REDES_INTERNAS` traducido a `192.168.202.86` |
| `33-proxmox-corte-vmbr1-40-a-punto-4.jpg` | Consola de proxmoxAB al aplicar el corte: avisos `post-down` de las reglas MASQUERADE ya borradas (P24), `vmbr1.40` con **192.168.40.4/24** y `POSTROUTING` sin reglas |
| `34-fw02-todas-vip-backup.jpg` | *Virtual IPs: Status* en FW02: las cuatro VIP (WAN VHID 7, LAN 40, CLIENTES 50 y DMZ 100) en **BACKUP** |
| `35-proxmox-tras-corte-rutas-y-pings-ok.jpg` | Rutas de proxmoxAB tras el corte (`192.168.50.0/24` y `192.168.100.0/24` vía `192.168.40.1`) y ping **OK** a .40.1, .40.2, .40.3, .40.5, .40.20, .100.30 y .40.40 |
| `36-ansible-internet-por-firewall-ok.jpg` | Consola de la VM Ansible (192.168.40.5): `ping 8.8.8.8` sin pérdidas, ya por los firewalls |
| `37-failover-ping-sin-cortes-fw01-apagado.jpg` | El mismo ping continuo mientras se apaga FW01: las respuestas siguen seguidas, sin saltos en `icmp_seq` |
| `38-failover-fw02-master.jpg` | *Virtual IPs: Status* en FW02 durante el failover: las cuatro VIP en **MASTER** |
| `39-failback-fw01-recupera-master.jpg` | Pensada para el failback, pero el fichero es **idéntico** a la captura 34 (FW02 con las cuatro VIP en BACKUP). Falta una captura propia del failback, como los anuncios CARP con `tcpdump` en `vmbr1.40` que se usaron para comprobarlo |
| `40-ansible-inventario-proxmox-40-4.png` | VM Ansible: `cibernova-dominio.yml` con el paso 7 (`proxmox-vlan50-relay.yml`) comentado como obsoleto y conexión a proxmoxAB por `192.168.40.4` |

### `05-dc02/` — Preparación, promoción y réplica de DC02

| Fichero | Qué se ve |
| --- | --- |
| `01-dc02-instalador-guest-tools.jpg` | Consola de la VM 101 (DC02): `virtio-win-guest-tools` en el CD E: (`virtio-win-0.1.302`) y la bienvenida del instalador |
| `02-dc02-guest-tools-instaladas.jpg` | Fin del instalador en DC02: *Installation Successfully* |
| `03-dc02-ip-dns-winrm-por-agente.png` | Salida de `qm guest exec` en proxmoxAB: IP `192.168.40.11` manual, `Test-NetConnection` a DC01 correcto, registro SRV que devuelve `dc01.cibernova.local` en el puerto 389 y servicio WinRM en marcha y automático |
| `04-dc02-renombrado-sid-distinto.png` | SID de máquina de DC01 (`S-1-5-21-3903391704-…`) y de DC02 (`S-1-5-21-654049888-…`): son distintos |
| `05-dc02-replicacion-ok.jpg` | `repadmin /replsummary`: DC01 y DC02 con **0 errores de 5** en los dos sentidos; las 5 particiones replicadas correctamente; `SYSVOL` y `NETLOGON` publicados; el SRV devuelve `dc01` y `dc02` |

### `06-dhcp01/` y `07-dhcp02/` — Drivers VirtIO

| Fichero | Qué se ve |
| --- | --- |
| `06-dhcp01/01-dhcp01-guest-tools-instaladas.jpg` | Consola de la VM 102 (DHCP01): *Installation Successfully* del instalador de guest tools, con el CD `virtio-win-0.1.302` en D: |
| `07-dhcp02/01-dhcp02-guest-tools-instaladas.jpg` | Lo mismo en la VM 104 (DHCP02), con el CD en E: |

### `08-ad-estructura-dhcp/` — OUs, unión al dominio y DHCP

| Fichero | Qué se ve |
| --- | --- |
| `01-ad03-ous-directiva.png` | `ad-03-estructura.yml` en `cn-dc01`: OUs de primer nivel e hijas, directiva de contraseñas y bloqueo, `redircmp` a `OU=Puestos` y `PLAY RECAP` con `ok=5 changed=5 failed=0` |
| `02-ad04-dhcp-unidas-dominio.png` | `ad-04-unir-servidores.yml`: DNS a DC01 y DC02, unión al dominio en `OU=Servidores`, canal seguro correcto y resultado `DHCP01 -> cibernova.local` y `DHCP02 -> cibernova.local`, con `failed=0` |
| `03-dhcp-ambito-failover-ok.png` | `dhcp-01-failover.yml`: autorización en AD, ámbito y opciones creados y failover `CN-DHCP01-DHCP02` en modo **LoadBalance 50 %**, socio `dhcp02.cibernova.local` y estado **Normal**; `PLAY RECAP` sin fallos |

### `09-redimensionado/` — RAM y CPU

| Fichero | Qué se ve |
| --- | --- |
| `01-proxmox-recursos-vms-tras-cambio.png` | Núcleos, memoria y tipo de CPU de cada VM después del cambio (FILES01, FILES02 y BACKUP apagadas) y memoria del host: 125 GB en total, 43 GB usados |
