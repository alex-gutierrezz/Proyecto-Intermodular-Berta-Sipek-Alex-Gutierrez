# Capturas de la Fase 1

Capturas de la Fase 1 (Infraestructura) que se enlazan desde [`../../memoria-fase1.md`](../../memoria-fase1.md). El nombre empieza por el número de la sección de la memoria donde se usa. Las capturas de la Fase 2 van en [`../fase2/`](../fase2/).

## Subidas

| Fichero | Sección | Qué se ve |
| --- | --- | --- |
| `12-11/06-dc01-hardware-vlan40.png` | 3 (bitácora del 12/11) | Hardware de DC01: tag=40, VirtIO SCSI, ISO de WS2025 y virtio-win, etiqueta ws2025 |
| `12-11/07-proxmox-isos.png` | 7 | `ls -lh` de las ISO en Proxmox: LOF, Ubuntu 24.04, virtio-win y WS2025_eval |
| `12-11/09-git-commit-playbook-proxmox.png` | 9 | Commit `feat(proxmox)` 06aff21 del playbook en la VM Ansible |
| `12-11/09-proxmox-playbook-codigo.png` | 9.5 | Código de `proxmox-vms-windows.yml` (vars y primeras tareas) |
| `12-11/09-proxmox-playbook-idempotencia.png` | 3 y 9.5 | Segunda ejecución del playbook: todo en skipping y `qm list` final |
| `12-11/11-ad-instalador-vioscsi.png` | 11.1 | Carga del driver vioscsi (2k25/amd64) en el instalador |
| `12-11/11-ad-instalador-disco.png` | 11.1 | El instalador de WS2025 ve el disco de 60 GB |
| `12-11/12-p2-qm-config-antes.png` | 12 (P2) | `qm config` de las VMs Windows antes del cambio: ISO LOF, sin tag, e1000 y unused0 |
| `12-11/12-p2-qm-list-antes.png` | 12 (P2) | `qm list` antes: DHCP y FILES02 con 0 GB, e ISOs disponibles |
| `12-11/12-p2-qm-list-despues.png` | 3 (bitácora del 12/11) | `qm list` después: 102 con 40 GB y 109 con 60 GB |

## Enlazadas en la memoria pero sin subir

| Fichero | Sección | Qué debe verse |
| --- | --- | --- |
| `09-proxmox-playbook-inicio.png` | 9.5 | Primera ejecución del playbook (tareas en changed) |
| `09-proxmox-playbook-recap2-tareas.png` | 9.5 | PLAY RECAP de la segunda ejecución |

El resto de capturas pendientes está en la sección 16.2 de la memoria.
