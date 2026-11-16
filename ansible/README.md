# Ansible

El proyecto de Ansible que funciona está en la VM Ansible (192.168.40.5), en `~/cibernova/ansible`. Esta carpeta es su copia en el repositorio.

| Carpeta | Contenido |
| --- | --- |
| `inventory/` | Inventario (`inventario.ini`): grupos control, web, db, mon, linux y proxmox |
| `group_vars/` | `all/vars.yml` (variables comunes) y `all/vault.yml` (secretos, **cifrado con Ansible Vault**) |
| `host_vars/` | Variables de un solo host (por ahora vacía) |
| `playbooks/` | `checkmk-servidor.yml`, `checkmk-agente.yml`, `proxmox-vms-windows.yml` |

**Pendiente:** copiar aquí los ficheros de la VM Ansible. En la VM el inventario está en la raíz (`inventario.ini`), así que al traerlo a `inventory/` hay que cambiar en `ansible.cfg` la línea `inventory = inventory/inventario.ini`.

Antes de cualquier commit, comprobad que el vault sigue cifrado:

```bash
head -1 group_vars/all/vault.yml   # debe mostrar $ANSIBLE_VAULT;1.1;AES256
```
