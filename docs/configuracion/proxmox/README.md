# Configuración de red de proxmoxAB

[`interfaces`](interfaces) es una copia del fichero `/etc/network/interfaces` de proxmoxAB, el servidor físico donde corren todas las máquinas virtuales. En ese fichero Proxmox define su red: las tarjetas físicas, los bridges (switches virtuales a los que se conectan las VMs) y sus propias IPs. Si el fichero se estropea, Proxmox se queda sin red y no se puede entrar a él ni a las VMs.

Esta copia no la aplica Ansible: sirve para consultar cómo está montada la red y para recuperar el fichero si hace falta. No contiene contraseñas, solo IPs.

## Qué hay en el fichero

| Interfaz | Dirección | Para qué sirve |
| --- | --- | --- |
| `nic0` a `nic3` | — | Tarjetas físicas del servidor. Solo se usa `nic1` |
| `vmbr0` | 192.168.202.7/22, puerta de enlace 192.168.200.254 | Bridge conectado a la red del aula por `nic1`. Es por donde entramos a Proxmox; no se toca para no perder el acceso |
| `vmbr1` | — | Bridge interno sin tarjeta física. Es VLAN-aware: cada VM lleva una etiqueta (`tag=40`, `tag=50`, `tag=100`) que decide en qué VLAN está |
| `vmbr1.40` | 192.168.40.4/24 | IP de gestión de Proxmox dentro de la VLAN 40, para que Ansible y Checkmk lleguen a él |

Las dos líneas `post-up ip route replace` hacen que Proxmox llegue a la VLAN 50 (clientes) y a la VLAN 100 (DMZ) a través de 192.168.40.1, que es la IP virtual (VIP CARP) compartida por los firewalls FW01 y FW02.

## Cambio respecto a la versión anterior

Hasta el 19/11 Proxmox hacía de router entre las VLAN y de NAT hacia el aula (`vmbr1.40` en la .1, `ip_forward` y `MASQUERADE`). Desde el 19/11 esa función la hacen los firewalls OPNsense en alta disponibilidad, y Proxmox se queda solo con su IP de gestión. Así Proxmox deja de ser un punto único de fallo para la red y no mezcla el hipervisor con la función de router.

La versión anterior se conserva en [`docs/historico/proxmox-interfaces-antes-19-11.cfg`](../../historico/proxmox-interfaces-antes-19-11.cfg).

## Aplicar y revertir (shell de proxmoxAB)

```bash
cp /etc/network/interfaces /root/interfaces.bak                 # copia antes de cualquier cambio
ifreload -a                                                      # aplica el fichero
cp /root/interfaces.bak /etc/network/interfaces && ifreload -a   # vuelve atrás
```

Antes de aplicar un cambio, tened abierta la consola de Proxmox: si la red falla, por SSH no se podrá volver atrás.
