# Ansible

Copia en el repositorio del proyecto de Ansible que funciona en la VM Ansible (192.168.40.5, `~/cibernova/ansible`). Ansible core 2.16.3. Contenido comprobado el 16/11/2026 contra la VM.

| Ruta | Contenido |
| --- | --- |
| `ansible.cfg` | Inventario, `host_key_checking = False` (aceptado en laboratorio, a revisar en la Fase 3) |
| `requirements.yml` | Colección `checkmk.general`, necesaria para `checkmk-agente.yml` |
| `inventory/inventario.ini` | Grupos `control`, `web` (DMZ), `db`, `mon`, `linux` (web + db + mon, usuario `alex`) y `proxmox` (root, aparte para que el agente de Checkmk no lo toque) |
| `group_vars/all/vars.yml` | Versión, sitio y servidor de Checkmk |
| `group_vars/all/vault.yml` | **Falta subirlo.** Secreto del usuario `automation` de Checkmk, cifrado con Ansible Vault |
| `host_vars/` | Variables de un solo host (vacía) |

## Playbooks

| Playbook | Fecha | Hosts | Qué hace |
| --- | --- | --- | --- |
| `checkmk-servidor.yml` | 05/11 | `mon` | Instala Checkmk 2.5.0p18 Community y crea el sitio `cibernova` (`creates:` lo hace idempotente) |
| `checkmk-agente.yml` | 05/11 | `linux` | Instala el agente, comprueba que responde y, por la API REST, da de alta el host, descubre sus servicios y activa los cambios |
| `proxmox-vms-windows.yml` | 12/11 | `proxmox` | Comprueba las ISO, guarda la configuración antigua en `/root/qm-antes`, borra las VMs Windows sin la etiqueta `ws2025` y las crea con VirtIO, VLAN 40, ISO de WS2025 y virtio-win |

Todos se lanzan desde esta carpeta y piden la contraseña del vault, porque `group_vars/all/vault.yml` se carga para todos los hosts:

```bash
ansible-galaxy collection install -r requirements.yml --upgrade
ansible-playbook playbooks/checkmk-servidor.yml --ask-vault-pass
ansible-playbook playbooks/checkmk-agente.yml --ask-vault-pass
ansible-playbook playbooks/proxmox-vms-windows.yml --ask-vault-pass
```

**Cuidado con `proxmox-vms-windows.yml`:** borra cualquier VM de la lista que no tenga la etiqueta `ws2025`. Si alguien quita la etiqueta a una VM ya instalada, la destruiría (mejora pendiente: pedir una confirmación antes de borrar).

## Diferencias con la VM Ansible

- En la VM el inventario está en la raíz (`inventario.ini`); aquí está en `inventory/` y `ansible.cfg` apunta a esa ruta.

## Subir el vault

Desde la VM Ansible, antes de copiarlo, comprobad que está cifrado:

```bash
head -1 group_vars/all/vault.yml   # debe mostrar $ANSIBLE_VAULT;1.1;AES256
```
