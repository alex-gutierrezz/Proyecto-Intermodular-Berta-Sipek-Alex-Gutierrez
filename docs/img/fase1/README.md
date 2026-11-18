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

Carpeta [`16-11/`](16-11/). Estas capturas todavía no están enlazadas en la memoria.

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


