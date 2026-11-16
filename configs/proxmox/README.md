# Configuración de red de proxmoxAB

`network.cfg` es la configuración de `/etc/network/interfaces` del hipervisor. De momento solo contiene el fragmento de `vmbr1` y las VLAN (sección 6.3 de la memoria); falta añadir la copia completa con `lo` y `vmbr0`.

| Interfaz | Dirección | Función |
| --- | --- | --- |
| `vmbr0` | 192.168.202.7/22, gw 192.168.200.254 | Bridge hacia la red del aula (puerto `nic1`). No se modifica para no perder el acceso a Proxmox |
| `vmbr1` | — | Bridge interno VLAN-aware (`bridge-vids 2-4094`) |
| `vmbr1.40` | 192.168.40.1/24 | Gateway de la VLAN 40 (servidores) y activación de `ip_forward` |
| `vmbr1.100` | 192.168.100.1/24 | Gateway de la VLAN 100 (DMZ) |

Proxmox hace de router entre las VLAN y de NAT (`MASQUERADE`) hacia `vmbr0`. Cada VM lleva `tag=40` o `tag=100` en su tarjeta de red; sin etiqueta no llega a su gateway.

## Aplicar y revertir (consola de proxmoxAB)

```bash
cp /etc/network/interfaces /root/interfaces.bak   # copia antes de cualquier cambio
ifreload -a                                        # aplica el fichero
cp /root/interfaces.bak /etc/network/interfaces && ifreload -a   # vuelve atrás
```

Riesgos conocidos: Proxmox es un punto único de fallo como router, y el tráfico entre la VLAN 40 y la DMZ todavía no se filtra (mejora de la Fase 3).
