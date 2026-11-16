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
| [`docs/historico/propuesta-inicial.pdf`](docs/historico/propuesta-inicial.pdf) | Propuesta inicial de la Fase 1, superada por el diseño actual (ver sección 4 de la memoria) |
| [`ansible/`](ansible/) | Inventario, variables y playbooks de Ansible (secretos cifrados con Ansible Vault) |
| [`configs/proxmox/`](configs/proxmox/) | Configuración de red de Proxmox (bridges, VLANs y NAT) |
| `scripts/` | Scripts del Anexo I (alta de usuarios desde el CSV). *Pendiente* |

## Diagrama de red

digraph red {
  graph [rankdir=TB, fontname="DejaVu Sans", fontsize=12, bgcolor="white", pad=0.4, nodesep=0.25, ranksep=0.55,
         label="CiberNova · Red de la Fase 1 (proxmoxAB) · 16/11/2026", labelloc=t, fontsize=16];
  node  [fontname="DejaVu Sans", fontsize=11, shape=box, style="rounded,filled", fillcolor="#ffffff", color="#555555"];
  edge  [fontname="DejaVu Sans", fontsize=10, color="#555555"];

  aula [label="Red del aula\n192.168.200.0/22\nGateway e Internet: 192.168.200.254", fillcolor="#eeeeee"];

  subgraph cluster_pve {
    label="Servidor físico · proxmoxAB · Proxmox VE 9.2.2\n2x Xeon E5-2620 v2 · 128 GB RAM · 4x900 GB RAID 10";
    style="rounded"; color="#333333"; fontsize=12;

    vmbr0 [label="vmbr0 (nic1)\n192.168.202.7/22\nweb: https://192.168.202.7:8006", fillcolor="#dbe8f7"];
    nat   [label="Router + NAT (MASQUERADE)\nip_forward = 1", shape=ellipse, fillcolor="#fff4cc"];
    vmbr1 [label="vmbr1 · bridge interno VLAN-aware\n(sin puertos físicos)", fillcolor="#dbe8f7"];
    v40   [label="vmbr1.40\n192.168.40.1/24", fillcolor="#d9f0d9"];
    v100  [label="vmbr1.100\n192.168.100.1/24", fillcolor="#fde2d2"];

    subgraph cluster_vlan40 {
      label="VLAN 40 · Servidores internos · 192.168.40.0/24 (tag=40)";
      style="rounded,filled"; fillcolor="#f1faf1"; color="#4a9a4a";
      node [fillcolor="#ffffff"];
      ans  [label="111 Ansible\n.5 · Ubuntu 24.04"];
      dc01 [label="100 DC01\n.10 · WS2025 · AD+DNS"];
      dc02 [label="101 DC02\n.11 · WS2025 · AD+DNS"];
      dh1  [label="102 DHCP01\n.12 · WS2025"];
      dh2  [label="104 DHCP02\n.13 · WS2025"];
      cmk  [label="112 CMK\n.20 · Ubuntu · Checkmk 2.5"];
      f1   [label="108 FILES01\n.30 · WS2025 · DFS"];
      f2   [label="109 FILES02\n.31 · WS2025 · DFS"];
      db1  [label="106 DB01\n.40 · Ubuntu · MariaDB"];
      db2  [label="107 DB02\n.41 · Ubuntu · MariaDB"];
      bk   [label="110 BACKUP\n.50 · WS2025"];
      {rank=same; ans; dc01; dc02; dh1; dh2; cmk}
      {rank=same; f1; f2; db1; db2; bk}
      ans -> dc01 -> dc02 -> dh1 -> dh2 -> cmk [style=invis]; f1 -> f2 -> db1 -> db2 -> bk [style=invis];
      ans -> f1 [style=invis]; dc01 -> f2 [style=invis]; dh1 -> db1 [style=invis]; dh2 -> db2 [style=invis]; cmk -> bk [style=invis];
    }

    subgraph cluster_vlan100 {
      label="VLAN 100 · DMZ · 192.168.100.0/24 (tag=100)";
      style="rounded,filled"; fillcolor="#fff5ef"; color="#d0743c";
      node [fillcolor="#ffffff"];
      w1 [label="103 WEB01\n.30 · Ubuntu · Web + SFTP"];
      w2 [label="105 WEB02\n.31 · Ubuntu · Web + SFTP"];
      w1 -> w2 [style=invis];
    }

    tpl [label="9000 ubuntu-2404-tpl\nPlantilla cloud-init (sin red)", style="rounded,dashed", fillcolor="#ffffff"];
  }

  aula -> vmbr0 [dir=both, label=" salida al aula"];
  vmbr0 -> nat [dir=both];
  nat -> v40 [dir=both]; nat -> v100 [dir=both];
  vmbr1 -> v40 [style=dashed, arrowhead=none]; vmbr1 -> v100 [style=dashed, arrowhead=none];
  v40 -> dh1 [lhead=cluster_vlan40, label=" gateway"];
  v100 -> w1 [lhead=cluster_vlan100, label=" gateway"];
  vmbr1 -> tpl [style=invis];
}


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
