# Proyecto Intermodular · CiberNova Solutions · Grupo 7

Infraestructura virtualizada, redundante y documentada para CiberNova Solutions (89 empleados, sedes en Barcelona, Madrid y Valencia).

**Equipo:** Berta Sipek y Alex Gutiérrez (ASIR)
**Fase actual:** Fase 1 · Infraestructura (entrega interna 15/12/2026)

## Índice del repositorio

| Ruta | Contenido |
| --- | --- |
| [`docs/memoria-fase1.md`](docs/memoria-fase1.md) | Memoria de la Fase 1: calendario, bitácora, desfases, decisiones técnicas, inventario, problemas y soluciones |
| [`docs/anexo-i-usuarios-grupos-permisos.md`](docs/anexo-i-usuarios-grupos-permisos.md) | Diseño del Anexo I: OUs, grupos AGDLP y matriz de permisos |
| [`docs/img/fase1/`](docs/img/fase1/) | Capturas que se enlazan desde la memoria |
| [`ansible/`](ansible/) | Inventario, variables y playbooks de Ansible (secretos cifrados con Ansible Vault) |
| [`configs/proxmox/`](configs/proxmox/) | Configuración de red de Proxmox (bridges, VLANs y NAT) |
| `scripts/` | Scripts del Anexo I (alta de usuarios desde el CSV). *Pendiente* |

## Diagrama de red

```mermaid
flowchart TB
    INET((Internet))
    AULA["Red del aula<br/>192.168.200.0/22 · gw 192.168.200.254"]
    PVE["proxmoxAB · Proxmox VE 9.2.2<br/>vmbr0 192.168.202.7<br/>router entre VLANs + NAT"]

    INET --- AULA --- PVE

    subgraph V40["VLAN 40 · Servidores · 192.168.40.0/24 · gw .1"]
        ANS["Ansible<br/>.5"]
        CMK["CMK · Checkmk<br/>.20"]
        DB01["DB01<br/>.40"]
        DB02["DB02<br/>.41"]
        DC01["DC01<br/>.10"]
        DC02["DC02<br/>.11"]
        WIN["DHCP · DHCP02 · FILES01<br/>FILES02 · BACKUP<br/>(IPs por asignar)"]
    end

    subgraph V100["VLAN 100 · DMZ · 192.168.100.0/24 · gw .1"]
        WEB01["WEB01<br/>.30"]
        WEB02["WEB02<br/>.31"]
    end

    PVE -- "vmbr1.40" --- V40
    PVE -- "vmbr1.100" --- V100
```

## Estado de la Fase 1

| Bloque | Estado |
| --- | --- |
| Hipervisor Proxmox con RAID | Hecho |
| Red: VLAN 40, DMZ (VLAN 100) y NAT | Hecho (sin filtrado entre VLANs, ver memoria) |
| Plantilla Ubuntu 24.04 con cloud-init | Hecho |
| Ansible + Vault | Hecho |
| Monitorización con Checkmk (alta automática) | Hecho |
| VMs Windows Server 2025 | Creadas con Ansible, instalación en curso |
| Active Directory, DHCP, ficheros/DFS, web, SFTP, BBDD, backups | Pendiente |

## Cómo se trabaja en este repositorio

- Commit al final de cada sesión de clase, con [Conventional Commits](https://www.conventionalcommits.org/es/) (`feat:`, `fix:`, `docs:`, `chore:`).
- Ningún secreto en claro: las contraseñas van en `ansible/group_vars/all/vault.yml`, cifrado con Ansible Vault.
- Las capturas se guardan en `docs/img/fase1/` con el número de la sección de la memoria delante (`06-…`, `09-…`, `12-…`).
