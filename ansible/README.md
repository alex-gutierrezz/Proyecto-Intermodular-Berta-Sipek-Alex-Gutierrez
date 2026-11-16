# Ansible — CiberNova Solutions

Automatización de la infraestructura de la Fase 1: monitorización con Checkmk y preparación de las VMs Windows en Proxmox.

> **Origen de esta carpeta.** Ansible se ejecuta en la **VM Ansible** (`192.168.40.5`, carpeta `~/cibernova/ansible`). Lo que hay aquí es una copia versionada de ese proyecto.
> Versión: **Ansible core 2.16.3**. Contenido comprobado contra la VM el **16/11/2026**.
> Si se modifica algo en la VM, hay que copiarlo también aquí y actualizar esta fecha.

## Índice

1. [Cómo funciona](#1-cómo-funciona)
2. [Estructura de la carpeta](#2-estructura-de-la-carpeta)
3. [Inventario](#3-inventario)
4. [Playbooks](#4-playbooks)
5. [Cómo ejecutarlo](#5-cómo-ejecutarlo)
6. [Gestión de secretos (Ansible Vault)](#6-gestión-de-secretos-ansible-vault)
7. [Riesgos conocidos](#7-riesgos-conocidos)
8. [Diferencias con la VM Ansible](#8-diferencias-con-la-vm-ansible)

---

## 1. Cómo funciona

Ansible no instala ningún programa en los servidores que gestiona: se conecta a ellos por **SSH** y ejecuta las tareas con el Python que ya trae Ubuntu. En Windows se conectará por **WinRM** (pendiente).

```mermaid
flowchart LR
    A["VM Ansible<br/>192.168.40.5"] -- SSH (alex) --> L["Servidores Linux<br/>web · db · mon"]
    A -- SSH (root) --> P["Proxmox<br/>proxmoxAB"]
    A -- API REST --> C["Checkmk<br/>192.168.40.20"]
```

Conceptos que se usan en este documento:

| Concepto | Qué es |
| --- | --- |
| **Inventario** | Lista de máquinas que gestiona Ansible, ordenadas por grupos. |
| **Playbook** | Receta: lista de tareas que Ansible ejecuta sobre un grupo de máquinas. |
| **Colección** | Paquete de módulos extra que no vienen con Ansible (por ejemplo, para hablar con la API de Checkmk). |
| **Idempotente** | Ejecutarlo dos veces deja el sistema igual que ejecutarlo una: la segunda vez no cambia nada ni da error. |
| **Ansible Vault** | Herramienta de Ansible para cifrar ficheros con secretos y poder subirlos a Git sin que se puedan leer. |

## 2. Estructura de la carpeta

| Fichero | Para qué sirve |
| --- | --- |
| `ansible.cfg` | Configuración de Ansible para este proyecto. Indica dónde está el inventario y desactiva la comprobación de la huella SSH de los servidores (`host_key_checking = False`). Ver [riesgos](#7-riesgos-conocidos). |
| `requirements.yml` | Colecciones externas necesarias. Ahora solo `checkmk.general`, que aporta los módulos para crear hosts, descubrir servicios y activar cambios en Checkmk. Sin ella, `checkmk-agente.yml` falla. |
| `inventory/inventario.ini` | Máquinas gestionadas y sus grupos. Ver [Inventario](#3-inventario). |
| `group_vars/all/vars.yml` | Variables comunes a todas las máquinas: versión de Checkmk, nombre del sitio e IP del servidor. Si cambia la versión, solo se modifica aquí. |
| `group_vars/all/vault.yml` | Variables secretas, cifradas con Ansible Vault: el secreto del usuario `automation` de Checkmk. **Todavía no está subido.** |
| `host_vars/` | Variables de una sola máquina, para cuando necesite un valor distinto al de su grupo. Ahora está vacía. |

> `group_vars/all/` significa "variables del grupo `all`". En Ansible, `all` incluye todas las máquinas, así que estas variables se cargan en cualquier playbook.

## 3. Inventario

| Grupo | Máquinas | Usuario | Uso |
| --- | --- | --- | --- |
| `control` | La propia VM Ansible (`localhost`) | — | Tareas que se ejecutan en la VM Ansible, como las llamadas a la API de Checkmk. |
| `web` | WEB01, WEB02 (VLAN 100, DMZ) | `alex` | Servidores web. |
| `db` | DB01, DB02 (VLAN 40) | `alex` | Bases de datos. |
| `mon` | CMK (VLAN 40) | `alex` | Servidor Checkmk. |
| `linux` | `web` + `db` + `mon` | `alex` | Todas las Linux gestionadas. Sobre este grupo se instala el agente de Checkmk. |
| `proxmox` | proxmoxAB | `root` | El hipervisor. Va **fuera** del grupo `linux` para que el playbook del agente no instale Checkmk en Proxmox. |

## 4. Playbooks


| Playbook | Fecha | Hosts | Qué hace |
| --- | --- | --- | --- |
| `checkmk-servidor.yml` | 05/11 | `mon` | Instala Checkmk 2.5.0p18 Community y crea el sitio `cibernova` (`creates:` lo hace idempotente) |
| `checkmk-agente.yml` | 05/11 | `linux` | Instala el agente, comprueba que responde y, por la API REST, da de alta el host, descubre sus servicios y activa los cambios |
| `proxmox-vms-windows.yml` | 12/11 | `proxmox` | Comprueba las ISO, guarda la configuración antigua en `/root/qm-antes`, borra las VMs Windows sin la etiqueta `ws2025` y las crea con VirtIO, VLAN 40, ISO de WS2025 y virtio-win |


> **No confundir las etiquetas.** `ws2025` es una **etiqueta de Proxmox** (el campo *Tags* que aparece junto al nombre de la VM), no una etiqueta VLAN como `tag=40`. El playbook la usa como marca de "esta VM ya está recreada correctamente": si la VM la tiene, no la toca.

## 5. Cómo ejecutarlo

Todos los comandos se ejecutan en la **VM Ansible**, dentro de la carpeta del proyecto.

**1. Instalar las colecciones** (una sola vez, o al clonar el repositorio en otra máquina):

```bash
ansible-galaxy collection install -r requirements.yml --upgrade
```

**2. Lanzar los playbooks:**

```bash
ansible-playbook playbooks/checkmk-servidor.yml --ask-vault-pass
ansible-playbook playbooks/checkmk-agente.yml --ask-vault-pass
ansible-playbook playbooks/proxmox-vms-windows.yml --ask-vault-pass   # ver riesgos antes de lanzarlo
```

`--ask-vault-pass` pide la contraseña del vault para descifrar `vault.yml`. Como ese fichero está en `group_vars/all/`, Ansible lo carga en **todos** los playbooks, incluso en los que no usan el secreto. Por eso todos la piden.

**Resultado esperado:** en el resumen final (`PLAY RECAP`), todas las máquinas con `failed=0`. Si se relanza un playbook ya aplicado, las tareas salen como `ok` y no como `changed`.

## 6. Gestión de secretos (Ansible Vault)

- Los secretos solo se guardan en `group_vars/all/vault.yml`, cifrado con AES256.
- El fichero cifrado sí se puede subir a Git: sin la contraseña no se puede leer.
- **La contraseña del vault no se sube nunca** al repositorio ni a la documentación.

### Subir el vault (pendiente)

Antes de copiarlo de la VM Ansible al repositorio, hay que comprobar que está cifrado:

```bash
head -1 group_vars/all/vault.yml
```

| Salida | Significado | Qué hacer |
| --- | --- | --- |
| `$ANSIBLE_VAULT;1.1;AES256` | Cifrado (marca de Vault, versión del formato y algoritmo) | Se puede subir. |
| `vault_cmk_api_secret: "…"` | **En claro** | **No subirlo.** Cifrarlo antes con `ansible-vault encrypt group_vars/all/vault.yml`. |

## 7. Riesgos conocidos

| Riesgo | Por qué existe | Mitigación o mejora pendiente |
| --- | --- | --- |
| `proxmox-vms-windows.yml` borra VMs sin preguntar | Decide si borrar una VM **solo** por la etiqueta `ws2025`. Si alguien la quita de una VM ya instalada (por ejemplo DC01 con el dominio creado) y se relanza el playbook, la VM se destruye y **no se puede recuperar**. | No relanzarlo una vez instaladas las Windows. Mejora: pedir confirmación antes de borrar. |
| `host_key_checking = False` | Ansible no comprueba la huella SSH de los servidores, así que no detectaría un servidor que se hace pasar por otro. Se desactivó porque las VMs se recrean a menudo. | Aceptado en laboratorio. Fase 3: activarlo y registrar las huellas con `ssh-keyscan`. |
| Acceso root a Proxmox desde la VM Ansible | Quien controle la VM Ansible controla también el hipervisor. | Aceptado para demostrar la automatización del hipervisor. Fase 3: sustituirlo por un token de la API de Proxmox con permisos mínimos. |
