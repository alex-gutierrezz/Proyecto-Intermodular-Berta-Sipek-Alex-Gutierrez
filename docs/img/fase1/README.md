# Capturas de la Fase 1

Capturas de la Fase 1 (Infraestructura) que sirven de evidencia para la [`memoria`](../../memoria-fase1.md). Están ordenadas por **día de trabajo** (una carpeta por fecha, `DD-MM`) y, dentro de cada día, por bloque de tareas. El número del nombre indica el orden en que se hicieron. Las capturas de la Fase 2 van en [`../fase2/`](../fase2/).

## Estructura

```
fase1/
├── 12-11/                      Preparación de las VMs Windows e instalación de WS2025
├── 16-11/
│   ├── 01-dc01-preparacion/    Drivers VirtIO, IP fija, DNS y WinRM en DC01
│   ├── 02-dc01-dominio/        Verificación del dominio con Ansible
│   └── 03-cierre/              Apagado ordenado de las VMs en proxmoxAB
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

**De qué trata:** las 7 VMs Windows estaban mal creadas: tenían la ISO equivocada (la de idiomas, LOF), no tenían etiqueta de VLAN, usaban tarjetas `e1000` y dos no arrancaban desde el disco (P2). Se borraron y se volvieron a crear con un playbook de Ansible (`proxmox-vms-windows.yml`), con la ISO de Windows Server 2025, los drivers VirtIO y la VLAN 40. Después se empezó la instalación de Windows.

**Qué hay en las capturas:** el estado de las VMs antes y después del cambio, el código del playbook y su commit, la prueba de que se puede ejecutar dos veces sin cambiar nada (idempotencia) y el instalador de Windows cargando el driver del disco VirtIO.

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

**De qué trata:** primera sesión con Windows Server. Se preparó DC01, el primer controlador de dominio: drivers, red y administración remota. Después se creó y comprobó el dominio `cibernova.local` con Ansible, y al final se apagaron las VMs de forma ordenada.

Carpeta [`16-11/`](16-11/). Estas capturas se enlazan en el apartado 11.2 de la memoria.

### `01-dc01-preparacion/` — Drivers, red y WinRM en DC01

**De qué trata:** dejar DC01 listo para gestionarlo desde Ansible. Se instalaron los drivers VirtIO (sin ellos Windows no ve la tarjeta de red), se le puso la IP fija `192.168.40.10` con su puerta de enlace y sus DNS y se activó WinRM, que es por donde Ansible se conecta a Windows. Las capturas siguen ese orden e incluyen una incidencia de teclado en la consola de Proxmox (P13).

| Fichero | Qué se ve |
| --- | --- |
| `01-dc01-powershell-inicial.jpg` | Consola de Proxmox (noVNC) de la VM 100 (DC01) con *Windows PowerShell* abierto como administrador sobre el Administrador del servidor |
| `02-dc01-incidencia-teclado-novnc.png` | **Incidencia de teclado** en la consola noVNC (P13). Se escribió `Get-NetAdapter \| Format-Table ...`, que muestra en una tabla los adaptadores de red, pero apareció `get'netadapter ç format'table`. La distribución del teclado de la consola no coincide con la del PC: el guion sale como `'` y la barra vertical como `ç` |
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
| `18-dc01-winrm-test-wsman-ok.png` | Activación y prueba de WinRM, el servicio por el que Ansible se conecta a Windows. `Enable-PSRemoting -Force -SkipNetworkProfileCheck` permite ejecutar PowerShell en DC01 desde otros equipos y `Test-WSMan localhost` comprueba que WinRM responde. La respuesta es correcta (fabricante Microsoft, pila 3.0): **WinRM listo para Ansible** |

### `02-dc01-dominio/` — Verificación del dominio

**De qué trata:** comprobar desde la VM Ansible que el dominio `cibernova.local` se creó bien. Un playbook revisa el nivel del dominio, los roles FSMO de DC01, el estado del DC (`dcdiag`) y que el DNS resuelve los servidores. Las capturas muestran el resultado y los dos fallos de `dcdiag` que salieron (P14 y P15). También hay una prueba previa de SSH de Proxmox a la VM Ansible, que fue rechazada.

| Fichero | Qué se ve |
| --- | --- |
| `00-shell-proxmox-teclado-ok.png` | Shell de proxmoxAB: prueba de teclado con caracteres especiales (`a-b_c\|d/e:f~g$h>i`), que salen correctos; después, `ssh` de root a `alex@192.168.40.5` (VM Ansible): primero `Host key verification failed` y, al aceptar la clave, **`Permission denied (publickey,password)`** |
| `01-dc01-verificacion-dominio-fsmo-dcdiag.jpg` | VM Ansible: `git log` (último commit `06aff21`), contraseña de Vault y ejecución de la verificación sobre `cn-dc01`. Resultados: dominio `cibernova.local` (NetBIOS `CIBERNOVA`) con nivel `Windows2025Domain`, **DC01 como único DC** y con los roles PDC, RID y Esquema; `dcdiag` **no supera** las pruebas `DFSREvent` (avisos de SYSVOL) y `SystemLog` (error `0x0000158C`: DC01 y CIBERNOVA con el mismo SID de máquina). Las tildes salen como `�` por la codificación de la salida de Windows |
| `02-dc01-verificacion-dns-recap.jpg` | Continuación: resolución DNS (`dc01` → `192.168.40.10`, `db01` → `192.168.40.40`, `web01` → `192.168.100.30`, `www.google.com` resuelve; **`dc02` no resuelve**), resumen de replicación vacío (solo hay un DC), la parte de DHCP en *skipping* (sin hosts) y `PLAY RECAP` de `cn-dc01` con `ok=5`, `changed=0` y `failed=0` |

### `03-cierre/` — Apagado ordenado

**De qué trata:** cerrar la sesión sin dañar nada. Se apagaron las VMs una a una desde Proxmox (`qm shutdown`), dando a cada una hasta 5 minutos para cerrarse sola en lugar de cortarles la corriente. Las capturas muestran qué VMs estaban en marcha antes y que al final quedaron todas paradas.

| Fichero | Qué se ve |
| --- | --- |
| `01-proxmox-vms-antes-de-apagar.png` | `qm list` en proxmoxAB antes de apagar: en marcha DC01, WEB01, WEB02, DB01, DB02, Ansible y CMK; el resto parado |
| `02-proxmox-todas-las-vms-apagadas.jpg` | Apagado con `qm shutdown <id> --timeout 300` en segundo plano para cada VM, con aviso de que el QEMU Guest Agent no responde en la 111 (Ansible); termina en `FIN` y el `qm list` final muestra **todas las VMs paradas** |



## 17/11/2026 — Firewalls OPNsense (FW01 y FW02)

**De qué trata:** se montaron los dos firewalls de la infraestructura, FW01 y FW02, como VMs con OPNsense 26.7. Van a sustituir a Proxmox como router y NAT. En esta sesión se dejaron instalados y con la configuración básica. La alta disponibilidad entre los dos se termina el 19/11.

Carpeta [`17-11/04-firewalls/`](17-11/04-firewalls/). Estas capturas se enlazan en el apartado 6.4 de la memoria. El zip de la sesión traía también las carpetas `01` a `03`, que son las del 16/11 y ya están en [`16-11/`](16-11/).

### `04-firewalls/` — Instalación y configuración base de FW01 y FW02

**De qué trata:** todo el montaje de los firewalls, en orden. Primero se comprobó qué VHID libres había en la red del aula y se guardó una copia de la red de Proxmox. Después se crearon las dos VMs y se instaló OPNsense en cada una. Luego se asignaron las interfaces y las IP de LAN y WAN por consola y se pasó el asistente web. Por último se crearon las primeras reglas (SYNC y TEMPORAL). Incluye la incidencia del DHCP del aula en FW02 (P20).

| Fichero | Qué se ve |
| --- | --- |
| `01-proxmox-escaneo-vhid-carp-aula.jpg` | Consola de proxmoxAB con `tcpdump` de anuncios VRRP/CARP en la red del aula: ya se usan el **vrid 8** (desde 192.168.202.38) y el **vrid 34** (desde 192.168.202.35), por eso elegimos el VHID 7 |
| `02-proxmox-backup-red-y-versiones-opnsense.png` | Preparación antes de tocar la red. Se ven las copias de la configuración de red de Proxmox (`/root/interfaces.bak`, `interfaces.pre-ad` y la nueva **`interfaces.pre-firewall`** del 17/11), que sirven para volver atrás si algo falla. También se ve la lista de versiones de OPNsense publicadas (de la 24.7 a la **26.7**), consultada para descargar la más reciente, y la carpeta de ISO de Proxmox donde se guarda |
| `03-proxmox-iso-opnsense-checksum-ok.png` | Descarga de `OPNsense-26.7-dvd-amd64.iso.bz2` (471 MB) y su SHA256, que coincide con el publicado |
| `04-proxmox-vms-fw01-fw02-creadas.png` | Creación de las dos VMs de los firewalls y su configuración (`qm config` de FW01):<br>• VMs **113 (FW01)** y **114 (FW02)**<br>• 2 núcleos tipo `host`, 4 GB de RAM y disco de 20 GB en `local-lvm`<br>• ISO de OPNsense montada en ide2 y arranque automático (`onboot: 1`)<br>• 5 tarjetas de red: `net0` en `vmbr0` (WAN, red del aula) y `net1` a `net4` en `vmbr1` con las VLAN 40, 50, 100 y 99 |
| `05-fw01-modo-live-lan-en-vtnet0-riesgo-dhcp.jpg` | Modo live de OPNsense en FW01: por defecto asigna **LAN → vtnet0**, que es la red del aula; con un DHCP activo en esa LAN habría repartido IPs al aula (P17) |
| `06-proxmox-link-down-wan-durante-instalacion.png` | Se «desenchufa» el cable virtual de la WAN (`link_down=1` en `net0`) de las VMs 113 y 114 mientras se instala OPNsense. El modo live de OPNsense pone su LAN en la tarjeta que está en la red del aula y podría repartir IPs por DHCP a los equipos de clase (P17). Con la WAN desconectada no hay riesgo |
| `07-fw01-instalador-menu.jpg` | Menú del instalador de OPNsense 26.7, que pregunta con qué sistema de ficheros instalar. **ZFS** es moderno y avanzado (instantáneas, comprobación de datos), pero gasta más RAM. **UFS** es el clásico de FreeBSD: sencillo y ligero. Elegimos UFS |
| `08-fw01-confirmar-disco-da0.jpg` | El instalador pide confirmación para borrar el disco `da0`, que es el disco virtual de 20 GB de la VM. OPNsense se instala ocupando todo el disco, así que hay que borrarlo. Es una VM nueva y el disco estaba vacío, así que no se pierde nada |
| `09-fw01-instalando.jpg` | Progreso de la instalación en FW01 |
| `10-fw01-configuracion-final-root.jpg` | *Final Configuration*: cambio de la contraseña de root y *Complete Install* |
| `11-fw02-instalando.jpg` | Progreso de la instalación en FW02 |
| `12-fw01-asignacion-interfaces.jpg` | En la consola de FW01 se dice qué tarjeta de red hace cada función. `vtnetX` es el nombre que da FreeBSD (la base de OPNsense) a las tarjetas VirtIO de Proxmox: `vtnet0` es la `net0`, `vtnet1` la `net1` y así sucesivamente. Queda: WAN → vtnet0 (aula), LAN → vtnet1 (VLAN 40), OPT1 → vtnet2 (VLAN 50), OPT2 → vtnet3 (VLAN 100) y OPT3 → vtnet4 (VLAN 99, SYNC) |
| `13-fw01-lan-wan-configuradas.jpg` | Menú de consola de FW01 (OPNsense 26.7): LAN `192.168.40.2/24` y WAN `192.168.202.84/22`; las OPT todavía sin IP |
| `14-fw01-ping-internet-ok.jpg` | Opción 7 (*Ping host*) desde FW01 a `8.8.8.8`: 3 paquetes, 0 % perdidos, unos 11 ms |
| `15-fw02-asignacion-interfaces.jpg` | La misma asignación de interfaces en FW02 |
| `16-fw02-incidencia-dhclient-antiguo.png` | Incidencia P20: FW02 había cogido una IP del DHCP del aula (192.168.200.67) en vez de la fija. La causa eran procesos `dhclient` (el programa que pide IP por DHCP) que se habían quedado en marcha en `vtnet0` y `vtnet1` desde antes de poner las IP fijas. Se resolvió reiniciando los dos firewalls |
| `17-fw02-reinicio-limpio-lan-wan.jpg` | FW02 después del reinicio limpio: LAN `192.168.40.3/24` y WAN `192.168.202.85/22` |
| `18-fw01-reinicio-limpio-lan-wan.jpg` | FW01 después del reinicio limpio: LAN `192.168.40.2/24` y WAN `192.168.202.84/22` |
| `19-proxmox-ping-y-web-gui-ambos-fw-ok.png` | Desde proxmoxAB: ping a 192.168.40.2 y 192.168.40.3 correcto y web de FW01 y FW02 con **HTTP 200** |
| `20-fw01-asistente-datos-generales.png` | Asistente web de FW01: hostname `fw01`, dominio `cibernova.local`, zona `Europe/Madrid`, DNS 8.8.8.8 y 1.1.1.1 y Unbound activado |
| `21-fw01-asistente-wan-gateway.png` | Paso de la WAN en el asistente web de FW01: IP fija `192.168.202.84/22` y puerta de enlace `192.168.200.254` (el router del aula). Se desmarca **Block RFC1918 Private Networks**, una opción que bloquea en la WAN las IP privadas (192.168.x.x, 10.x.x.x…). Nuestra WAN es la red privada del aula, así que con ese bloqueo no saldría nada |
| `22-fw01-asistente-terminado.jpg` | Final del asistente web de FW01 (*Finished initial configuration!*): la configuración básica (nombre, dominio, DNS, LAN y WAN) ya está aplicada. Arriba se ve `root@fw01.cibernova.local`, es decir, el usuario root conectado al equipo `fw01` del dominio `cibernova.local`. Eso confirma que se aplicaron el nombre y el dominio |
| `23-fw01-reglas-sync-clientes-dmz.jpg` | *Firewall: Rules* de FW01: regla flotante **TEMPORAL** que permite todo desde CLIENTES y DMZ (se restringe en la Fase 3), reglas por defecto de la LAN y regla **SYNC** que permite pfsync y XMLRPC entre FW01 y FW02 |
| `24-fw02-asistente-datos-generales.jpg` | Asistente web de FW02: hostname `fw02` con los mismos datos que FW01 |
| `25-fw02-asistente-terminado.jpg` | *Finished initial configuration!* en FW02 (`root@fw02.cibernova.local`) |
| `26-fw02-interfaces-configuradas.jpg` | *Interfaces: Overview* de FW02: WAN `192.168.202.85/22` con gateway `192.168.200.254`, LAN `192.168.40.3/24`, CLIENTES `192.168.50.3/24`, DMZ `192.168.100.3/24` y SYNC `192.168.99.2/24` |
| `27-fw02-regla-sync-aplicada.jpg` | Reglas de FW02 con la regla **SYNC** aplicada. OPNsense bloquea por defecto todo el tráfico en una interfaz nueva. Esta regla permite el tráfico entre FW01 y FW02 por la VLAN 99 para que puedan sincronizarse (pfsync y XMLRPC). Se crea a mano en los dos, porque sin ella FW02 no podría recibir la sincronización. El resto de reglas, como la TEMPORAL, le llegan después desde FW01 |

## 19/11/2026 — Firewalls en HA, DC02, estructura de AD y DHCP con failover

**De qué trata:** la sesión con más avances de la Fase 1. Los firewalls pasan a funcionar en alta disponibilidad y sustituyen a Proxmox como router. Se añade el segundo controlador de dominio (DC02), se crea la estructura de Active Directory y se monta el DHCP con dos servidores en failover. Al final se ajustan la RAM y la CPU de todas las VMs.

Carpeta [`19-11/`](19-11/). Estas capturas se enlazan en los apartados 6.4, 8.1 y 11.3 de la memoria. El zip de la sesión traía también las capturas 24 a 27 de `04-firewalls`, que son las del 17/11 y ya están en [`17-11/04-firewalls/`](17-11/04-firewalls/).

### `04-firewalls/` — HA, VIP CARP, NAT, corte de red y failover

**De qué trata:** terminar la alta disponibilidad de los firewalls y ponerlos en servicio. FW01 copia a FW02 su configuración y las conexiones abiertas; los dos comparten las IP de puerta de enlace (VIP CARP) y las redes internas salen a Internet por la VIP de la WAN (NAT). Después se hizo el corte: Proxmox dejó de ser el router. Por último se probó el failover apagando FW01 con un ping en marcha, que no se cortó.

La numeración sigue la de [`17-11/04-firewalls/`](17-11/04-firewalls/).

| Fichero | Qué se ve |
| --- | --- |
| `28-fw01-ha-ajustes.jpg` | Configuración de la alta disponibilidad en FW01 (*System: High Availability: Settings*). Se le dice que copie a FW02 (`192.168.99.2`), por la interfaz SYNC, dos cosas: el estado de las conexiones abiertas (pfsync), para que no se corten si FW01 cae, y la configuración (XMLRPC), con el usuario `root` y todos los servicios marcados. La contraseña no aparece en la captura |
| `29-fw01-ha-conectado-con-fw02.jpg` | Comprobación de que FW01 se comunica con FW02 (*High Availability: Status*). FW01 consigue leer las versiones de FW02 (firmware, base y kernel 26.7), así que la conexión por XMLRPC funciona. Desde aquí se pulsa *Synchronize and reconfigure all* para copiar la configuración de FW01 a FW02 |
| `30-fw01-carp-wan-master.jpg` | Estado de la VIP de la WAN en FW01 (*Virtual IPs: Status*): `192.168.202.86` con **VHID 7** en **MASTER**, es decir, ahora mismo la tiene FW01. *freq. 1/0* son los dos valores de CARP: anuncia cada 1 segundo y con prioridad 0 (*advskew*), la más alta. Por eso FW01 es el que manda mientras esté encendido |
| `31-fw02-carp-wan-backup.jpg` | La misma VIP vista en FW02: VHID 7 en **BACKUP**, esperando por si FW01 cae. Su *freq. 1/100* indica que anuncia con prioridad 100, peor que la 0 de FW01, así que solo se queda la VIP si deja de oír a FW01. Las capturas 30 y 31 juntas demuestran que la pareja CARP funciona |
| `32-fw01-nat-salida-vip.jpg` | NAT de salida de FW01 (*Firewall: NAT: Source NAT*) en modo **Hybrid**: OPNsense mantiene sus reglas automáticas y además acepta reglas manuales. La regla manual cambia la IP de origen de todo lo que sale de las redes internas (alias `REDES_INTERNAS`: VLAN 40, 50 y 100) por la VIP `192.168.202.86`. Así, aunque salga por FW02 tras un fallo, la IP pública sigue siendo la misma |
| `33-proxmox-corte-vmbr1-40-a-punto-4.jpg` | El momento del corte en la consola de proxmoxAB: Proxmox deja de ser el router. `vmbr1.40` pasa a la **192.168.40.4** (la .1 queda libre para la VIP de los firewalls) y la tabla `POSTROUTING` sale vacía, sin las reglas MASQUERADE, así que Proxmox ya no hace NAT. Los avisos `post-down` salen porque esas reglas ya se habían borrado (P24) y no afectan |
| `34-fw02-todas-vip-backup.jpg` | Estado normal de FW02 antes de la prueba de failover: sus cuatro VIP (WAN con VHID 7, LAN 40, CLIENTES 50 y DMZ 100) están en **BACKUP**. Esto confirma que FW01 lleva todas las puertas de enlace y que FW02 está preparado para relevarlo |
| `35-proxmox-tras-corte-rutas-y-pings-ok.jpg` | Comprobación después del corte. Las rutas de proxmoxAB mandan las VLAN 50 y 100 a través de los firewalls (`via 192.168.40.1`). Los pings responden a la VIP (.40.1), a FW01 (.40.2), a FW02 (.40.3), a Ansible (.40.5), a CMK (.40.20), a WEB01 (.100.30) y a DB01 (.40.40): la red sigue funcionando con el nuevo router |
| `36-ansible-internet-por-firewall-ok.jpg` | Prueba de salida a Internet desde la VM Ansible (192.168.40.5) con `ping 8.8.8.8` sin pérdidas. Ahora el tráfico ya no pasa por Proxmox, sino por la VIP `192.168.40.1` de los firewalls y su NAT. Este mismo ping se deja en marcha para la prueba de failover de la captura 37 |
| `37-failover-ping-sin-cortes-fw01-apagado.jpg` | **Prueba de failover**: se apaga FW01 mientras sigue el ping de la captura 36. `icmp_seq` es el número de cada ping; si se perdiera alguno, habría un salto en la numeración. No hay ninguno, así que FW02 tomó el relevo sin cortar la conexión, gracias a CARP (la VIP) y a pfsync (las conexiones abiertas) |
| `38-failover-fw02-master.jpg` | FW02 durante el failover, con FW01 apagado: sus cuatro VIP han pasado de BACKUP a **MASTER**. Ahora FW02 hace de puerta de enlace y de NAT para todas las redes. Junto con la captura 37, demuestra que la alta disponibilidad funciona |
| `40-ansible-inventario-proxmox-40-4.png` | Cambios en la VM Ansible tras el corte. El inventario conecta ahora con proxmoxAB por la `192.168.40.4`: la .40.1 es la VIP de los firewalls y con ella Ansible entraría en un firewall. En `cibernova-dominio.yml`, el paso 7 (`proxmox-vlan50-relay.yml`) queda comentado como obsoleto porque la VLAN 50 ya la gestionan los firewalls |

No hay captura 39: la que había era idéntica a la 34 y se eliminó. Falta repetir el *failback* (volver a encender FW01 y comprobar que recupera las VIP en MASTER) y capturarlo.

### `05-dc02/` — Preparación, promoción y réplica de DC02

**De qué trata:** añadir un segundo controlador de dominio para que AD y DNS no dependan solo de DC01. Se instalaron los drivers VirtIO, se configuraron la IP `192.168.40.11`, el DNS y WinRM, y se comprobó que su SID de máquina es distinto del de DC01. Después se promovió a controlador de dominio y se verificó que los dos DC se replican sin errores.

| Fichero | Qué se ve |
| --- | --- |
| `01-dc02-instalador-guest-tools.jpg` | Primer paso con DC02 (VM 101): instalar los drivers VirtIO, igual que en DC01. Se ve el instalador `virtio-win-guest-tools`, que está en el CD E: (`virtio-win-0.1.302`). Sin estos drivers, Windows no reconoce la tarjeta de red de Proxmox |
| `02-dc02-guest-tools-instaladas.jpg` | Fin de la instalación de los drivers en DC02 (*Installation Successfully*). A partir de aquí Windows ya ve la tarjeta de red y se le puede configurar la IP |
| `03-dc02-ip-dns-winrm-por-agente.png` | Configuración de DC02 lanzada desde proxmoxAB con `qm guest exec`, que ejecuta órdenes dentro de la VM a través del agente QEMU sin abrir la consola. Resultados: IP fija `192.168.40.11`, conexión correcta con DC01, el DNS encuentra el controlador del dominio (registro SRV de `dc01.cibernova.local`, puerto 389) y WinRM en marcha y automático, listo para Ansible |
| `04-dc02-renombrado-sid-distinto.png` | Comprobación del SID de máquina, el identificador único de cada Windows. DC01 (`S-1-5-21-3903391704-…`) y DC02 (`S-1-5-21-654049888-…`) tienen SID distintos. Es imprescindible antes de promover DC02: dos máquinas con el mismo SID dan errores en el dominio, como ya pasó con DC01 (P15) |
| `05-dc02-replicacion-ok.jpg` | DC02 ya es controlador de dominio y se comprueba la réplica con `repadmin /replsummary`: **0 errores** en los dos sentidos y las 5 particiones de AD replicadas. Además están publicadas `SYSVOL` y `NETLOGON` (las carpetas compartidas que necesitan los DC) y el DNS devuelve `dc01` y `dc02`. El dominio ya no depende de un solo servidor |

### `06-dhcp01/` y `07-dhcp02/` — Drivers VirtIO

**De qué trata:** primer paso para preparar los dos servidores DHCP. Igual que en DC01 y DC02, se instalaron los drivers VirtIO para que Windows reconozca la tarjeta de red y el disco. Sin ellos no se pueden configurar la red ni WinRM, ni unirlos al dominio.

| Fichero | Qué se ve |
| --- | --- |
| `06-dhcp01/01-dhcp01-guest-tools-instaladas.jpg` | Drivers VirtIO instalados en DHCP01 (VM 102), con el CD `virtio-win-0.1.302` en D:. Es el mismo paso que en DC01 y DC02 y hace falta para que Windows vea la tarjeta de red antes de configurarle la IP y unirlo al dominio |
| `07-dhcp02/01-dhcp02-guest-tools-instaladas.jpg` | Lo mismo en DHCP02 (VM 104), con el CD en E:. Con los dos servidores DHCP ya con red, se pueden unir al dominio y montar el failover (subcarpeta `08`) |

### `08-ad-estructura-dhcp/` — OUs, unión al dominio y DHCP

**De qué trata:** tres playbooks de Ansible seguidos. El primero crea la estructura de Active Directory: las unidades organizativas (OU) y la directiva de contraseñas y bloqueo. El segundo une DHCP01 y DHCP02 al dominio. El tercero crea el ámbito DHCP de la VLAN 50 y el failover entre los dos servidores, que se reparten las IPs al 50 % y se cubren si uno cae.

| Fichero | Qué se ve |
| --- | --- |
| `01-ad03-ous-directiva.png` | Playbook `ad-03-estructura.yml` ejecutado en DC01: crea las unidades organizativas (OU), las carpetas de AD donde se ordenan usuarios, grupos y equipos, y la directiva de contraseñas y bloqueo de cuentas. Con `redircmp`, los equipos nuevos van a `OU=Puestos` en lugar del contenedor por defecto. `ok=5 changed=5 failed=0`: todo creado sin errores |
| `02-ad04-dhcp-unidas-dominio.png` | Playbook `ad-04-unir-servidores.yml`: pone como DNS de DHCP01 y DHCP02 a DC01 y DC02 y los une al dominio en `OU=Servidores`. Después comprueba el canal seguro, la relación de confianza entre cada servidor y el dominio. Resultado: `DHCP01 -> cibernova.local` y `DHCP02 -> cibernova.local`, con `failed=0` |
| `03-dhcp-ambito-failover-ok.png` | Playbook `dhcp-01-failover.yml`. Autoriza los dos servidores en AD (un DHCP no autorizado no reparte IPs en un dominio) y crea el ámbito de la VLAN 50 con sus opciones. Después configura el failover `CN-DHCP01-DHCP02` en **LoadBalance 50 %**: cada servidor reparte la mitad de las IPs y, si uno cae, el otro atiende a todos. Estado **Normal**: los dos se ven y están sincronizados |

### `09-redimensionado/` — RAM y CPU

**De qué trata:** ajustar los recursos de cada VM a la carga real de su servicio, para no reservar memoria y núcleos que no se usan. Quedaron 36 vCPU y 78 GB asignados de los 128 GB del servidor. La captura muestra los núcleos y la memoria de cada VM después del cambio y la memoria total del host.

| Fichero | Qué se ve |
| --- | --- |
| `01-proxmox-recursos-vms-tras-cambio.png` | Resultado del redimensionado: núcleos, memoria y tipo de CPU de cada VM después de ajustarlos a lo que necesita su servicio, y la memoria del servidor (125 GB en total, 43 GB en uso en ese momento). FILES01, FILES02 y BACKUP estaban apagadas. El reparto final es de 36 vCPU y 78 GB asignados de 128 GB |
