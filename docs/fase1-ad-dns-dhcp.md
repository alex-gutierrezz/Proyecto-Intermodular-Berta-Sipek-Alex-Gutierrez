# Fase 1 · Active Directory, DNS y DHCP con Ansible

> Guía preparada por Alex Gutiérrez el 16/11/2026. El estado real de cada paso (qué se ha ejecutado y qué no) está en la memoria de la Fase 1.

## 1. Qué se monta

| Servidor | IP | Qué hace |
|---|---|---|
| DC01 | 192.168.40.10 | Crea el bosque `cibernova.local` (NetBIOS `CIBERNOVA`). AD + DNS. Emulador PDC y fuente de hora (NTP) |
| DC02 | 192.168.40.11 | Segundo DC con DNS: réplica completa de DC01 |
| DHCP01 | 192.168.40.12 | DHCP, failover 50/50 con DHCP02 |
| DHCP02 | 192.168.40.13 | DHCP, failover 50/50 con DHCP01 |
| FILES01, FILES02 | 192.168.40.30, .31 | Se unen al dominio (DFS en la semana 4) |
| BACKUP | 192.168.40.50 | Se une al dominio (copias en la semana 5) |

**Por qué así (para la sección de decisiones):**
- **Dos DC con DNS integrado en AD.** Si cae uno, la autenticación y la resolución de nombres siguen funcionando. Es el requisito de "sin puntos únicos de fallo".
- **Failover DHCP en equilibrio de carga 50/50.** Los dos servidores reparten IPs a la vez y comparten el estado de las concesiones. Si cae uno, el otro asume todo el rango cuando pasa el MCLT (1 h). No hace falta partir el rango a mano (regla 80/20).
- **Reenviadores 8.8.8.8 y 1.1.1.1**, porque el DNS del centro (192.168.200.254) no responde desde el laboratorio (P5).
- **Árbol de OUs del diseño del Grupo 7** (Anexo I), más una OU `Servidores` para aplicar GPO solo a los servidores. Los equipos nuevos van por defecto a `Equipos\Puestos` (`redircmp`).
- **Directiva de contraseñas del Anexo I:** 12 caracteres con complejidad, historial de 10, caducidad a 90 días y bloqueo de 15 minutos tras 5 fallos. Los 15 caracteres de Dirección, Sistemas y `adm.` van en una PSO aparte (semana 3).
- **Usuarios y grupos fuera de estos playbooks:** los crea el script del CSV, como pide el Anexo I (contraseñas generadas por el script, nunca en el repo).

### Ámbito DHCP (propuesta, se decide el 17/11)

| VLAN | Red | Fijas | Ámbito | Concesión | Puerta de enlace | DNS |
|---|---|---|---|---|---|---|
| 50 Clientes | 192.168.50.0/24 | .2 – .19 | .20 – .250 | 8 días | 192.168.50.1 (Proxmox) | DC01, DC02 |

Para añadir más VLAN de clientes, se añade un elemento a `dhcp_ambitos` en `inventory/group_vars/dhcp.yml` y se relanza el playbook.

## 2. Ficheros

```
playbooks/win-00-comprobaciones.yml comprobación previa + snapshots pre-ad (no cambia los Windows)
playbooks/win-01-base.yml           IP definitiva, nombre, zona horaria, ping permitido
playbooks/ad-01-dc01-bosque.yml     bosque cibernova.local + DNS (reenviadores, zonas inversas, registros Linux) + NTP
playbooks/ad-02-dc02-replica.yml    DC02 como segundo DC + DNS cruzado entre DCs
playbooks/ad-03-estructura.yml      árbol de OUs del Grupo 7 + directiva de contraseñas + redircmp
playbooks/ad-04-unir-servidores.yml DHCP01/02, FILES01/02, BACKUP al dominio (OU=Servidores)
playbooks/dhcp-01-failover.yml      rol DHCP, autorización en AD, ámbitos y failover
playbooks/ad-99-verificar.yml       comprobaciones para las capturas (no cambia nada)
playbooks/proxmox-vlan50-relay.yml  VLAN 50 de clientes + relay DHCP en Proxmox
playbooks/cibernova-dominio.yml     TODO lo anterior en orden, con un solo comando
inventory/group_vars/windows.yml    conexión WinRM
inventory/group_vars/all/ad.yml     datos del dominio
inventory/group_vars/dhcp.yml       ámbito DHCP (VLAN 50)
vars/ad_estructura.yml              OUs y directiva de contraseñas
```

## 3. Preparación (una sola vez, en la VM Ansible)

> En el repositorio los ficheros ya están integrados: playbooks en `ansible/playbooks/`, variables en `ansible/inventory/group_vars/` y `ansible/vars/`, el inventario de los Windows al final de `ansible/inventory/inventario.ini` y las colecciones en `ansible/requirements.yml`.

```bash
cd ~/cibernova/repo/ansible
ansible-galaxy collection install -r requirements.yml --upgrade
ansible-vault edit inventory/group_vars/all/vault.yml
```

En el vault tienen que existir estas variables (los valores **solo** van en el vault cifrado, nunca en Git ni en la documentación). Todas deben cumplir la complejidad de Windows: 12 o más caracteres, mayúsculas, minúsculas, números y símbolos.

| Variable | Para qué |
|---|---|
| `vault_win_admin_password` | Administrador de las 7 Windows; al crear el bosque pasa a ser también la del Administrador del dominio |
| `vault_dsrm_password` | Modo de restauración de servicios de directorio (DSRM) de DC01 y DC02 |
| `vault_dhcp_failover_secreto` | Secreto compartido del failover entre DHCP01 y DHCP02 |

Si algún Windows tiene todavía una IP provisional (por ejemplo, FILES01 con .14), añadid `ip_actual=192.168.40.14` en su línea del inventario: `win-01-base.yml` entra por esa IP, le pone la definitiva y sigue. Después borrad `ip_actual`.

Comprobad la conexión con los 7 Windows:

```bash
ansible windows -m ansible.windows.win_ping --ask-vault-pass
```

Si tenéis `vault_password_file` en `ansible.cfg`, quitad `--ask-vault-pass` de todos los comandos.

## 4. Orden de ejecución

### Todo de una vez

```bash
ansible-playbook playbooks/cibernova-dominio.yml --ask-vault-pass
```

Hace los pasos 0 a 7 de la tabla, más la VLAN 50 y el relay en Proxmox (sección 6), en unos 30-40 minutos. Si se corta, se relanza el mismo comando y sigue: lo ya hecho sale "ok". Al terminar, borrad los snapshots de los DC.

**Medidas de seguridad:**
- **Comprobación previa** (`win-00-comprobaciones.yml`): conexión, IP, que no estén en otro dominio y 10 GB libres en los 7 Windows. Si algo no cuadra, para sin tocar nada.
- **Snapshot `pre-ad` automático** de las 7 VMs Windows y copia de la red de Proxmox en `/root/interfaces.pre-ad`.
- **`any_errors_fatal`:** si falla una sola máquina, se para todo. Nada queda a medias en unas sí y en otras no.
- **En Proxmox solo se levanta `vmbr1.50`** (`ifup`). No se recarga el resto de la red, y vmbr0 (aula) no se toca.

**Volver atrás** (antes de que DC02 sea DC; después, NO restauréis los DC): `qm rollback <id> pre-ad` en la consola de proxmoxAB.

### Paso a paso (si preferís ir por partes)

Lanzad cada paso y no paséis al siguiente si el `PLAY RECAP` tiene `failed` o `unreachable` distinto de 0. Después de cada paso, haced un commit.

| # | Comando | Tiempo aprox. |
|---|---|---|
| 0 | `ansible-playbook playbooks/win-00-comprobaciones.yml --ask-vault-pass` (comprueba y hace los snapshots) | 1 min |
| 1 | `ansible-playbook playbooks/win-01-base.yml --ask-vault-pass` | 2 min |
| 2 | `ansible-playbook playbooks/ad-01-dc01-bosque.yml --ask-vault-pass` | 10-15 min (reinicia DC01) |
| 3 | `ansible-playbook playbooks/ad-02-dc02-replica.yml --ask-vault-pass` | 10-15 min (reinicia DC02) |
| 4 | `ansible-playbook playbooks/ad-03-estructura.yml --ask-vault-pass` | 1 min |
| 5 | `ansible-playbook playbooks/ad-04-unir-servidores.yml --ask-vault-pass` | 5 min (reinicia los 5) |
| 6 | `ansible-playbook playbooks/dhcp-01-failover.yml --ask-vault-pass` | 3 min |
| 7 | `ansible-playbook playbooks/ad-99-verificar.yml --ask-vault-pass` | 1 min |

**Después del paso 3, borrad los snapshots de los DC.** Restaurar un DC a un punto anterior cuando ya replica con el otro provoca un *USN rollback* y rompe el dominio:

```bash
for id in 100 101; do for s in instalado-limpio pre-ad; do qm delsnapshot $id $s 2>/dev/null; done; done
```

**Commits sugeridos:**

```bash
git add . && git commit -m "feat(ad): bosque cibernova.local en DC01 y DNS con reenviadores y zonas inversas"
git add . && git commit -m "feat(ad): DC02 como segundo controlador de dominio"
git add . && git commit -m "feat(ad): árbol de OUs del Grupo 7 y directiva de contraseñas"
git add . && git commit -m "feat(ad): servidores miembro unidos al dominio"
git add . && git commit -m "feat(dhcp): DHCP01/DHCP02 con failover 50/50 y ámbito de la VLAN 50"
```

Todos los playbooks son idempotentes: si se relanzan, solo cambian lo que no está como debe.

## 5. Capturas para la documentación

| Captura | Qué se ve |
|---|---|
| `11-ad-dc01-bosque-recap.png` | PLAY RECAP del paso 2 |
| `11-ad-dc02-replica-recap.png` | PLAY RECAP del paso 3 |
| `11-ad-verificar.png` | Salida del paso 7 (dominio, DCs, FSMO, dcdiag, replsummary, DNS) |
| `11-ad-usuarios-equipos.png` | DC01 → *Usuarios y equipos de Active Directory* con las OUs desplegadas |
| `11-ad-dns.png` | DC01 → *Administrador DNS*: zona directa con los registros Linux y zonas inversas |
| `12-dhcp-failover.png` | DHCP01 → consola DHCP → IPv4 → propiedades → Conmutación por error |
| `12-dhcp-ambitos.png` | El ámbito de la VLAN 50 en DHCP01 y en DHCP02 (replicado) |
| `12-dhcp-cliente.png` | Cliente de prueba en la VLAN 50 con IP del DHCP (sección 6) |

## 6. Red de clientes y prueba real del DHCP

En el laboratorio no hay switches. Las VLAN de clientes no existen, así que nadie pide IP al DHCP. Se crea la VLAN 50 en Proxmox y Proxmox hace de *DHCP relay* (lo que en la empresa haría el switch de capa 3 con `ip helper-address`).

El playbook `proxmox-vlan50-relay.yml` (incluido en `cibernova-dominio.yml`) hace la interfaz y el relay. A mano sería así. **En la consola de proxmoxAB**, primero la copia de seguridad y la interfaz nueva:

```bash
cp /etc/network/interfaces /root/interfaces.bak-vlan50
cat >> /etc/network/interfaces << 'EOF'

auto vmbr1.50
iface vmbr1.50 inet static
    address 192.168.50.1/24
    post-up iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s 192.168.50.0/24 -o vmbr0 -j MASQUERADE
EOF
ifreload -a
ip -br a | grep vmbr1
```

Después, el relay con dnsmasq. `port=0` desactiva su DNS, así que solo reenvía las peticiones DHCP a DHCP01 y DHCP02:

```bash
apt install -y dnsmasq
cat > /etc/dnsmasq.d/relay-cibernova.conf << 'EOF'
port=0
interface=vmbr1.50
bind-interfaces
dhcp-relay=192.168.50.1,192.168.40.12
dhcp-relay=192.168.50.1,192.168.40.13
EOF
systemctl restart dnsmasq && systemctl status dnsmasq --no-pager
```

Por último, un cliente de prueba clonado de la plantilla, en la VLAN 50 y por DHCP:

```bash
qm clone 9000 120 --name CLIENTE-V50 --full
qm set 120 --net0 virtio,bridge=vmbr1,firewall=1,tag=50 --ipconfig0 ip=dhcp
qm start 120
```

Al minuto, en DHCP01 (PowerShell): `Get-DhcpServerv4Lease -ScopeId 192.168.50.0`. Tiene que salir una IP entre .20 y .250. Para probar el failover, apagad DHCP01 y renovad la IP del cliente con `sudo networkctl renew <interfaz>` (el nombre sale con `ip -br a`; suele ser `eth0`). La sigue dando DHCP02.

## 7. Problemas típicos

| Síntoma | Causa | Solución |
|---|---|---|
| `win_ping` da `401 Unauthorized` | Usuario o contraseña incorrectos | En Windows en español la cuenta es **Administrador**. Revisad `vault_win_admin_password` |
| `win_ping` da `timed out` / `connection refused` | WinRM no está activado, el firewall lo bloquea o la IP no es la del inventario | En el Windows: `Enable-PSRemoting -Force -SkipNetworkProfileCheck`. Si tiene otra IP, usad `ip_actual` |
| DC02 no encuentra el dominio | Su DNS no apunta a DC01 | El paso 3 lo pone. Comprobad `Resolve-DnsName _ldap._tcp.dc._msdcs.cibernova.local` |
| `Access denied` al autorizar el DHCP o crear el failover | Doble salto NTLM | Las tareas llevan `become: true`. Comprobad `ansible_become_*` en `inventory/group_vars/windows.yml` |
| La hora no sincroniza en DC01 | El aula bloquea NTP (UDP 123) | No afecta al dominio. Lo documentáis como incidencia: los DC y miembros se sincronizan con DC01 igualmente |
