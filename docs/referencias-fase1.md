# Referencias de la Fase 1

Fuentes consultadas durante la Fase 1 de CiberNova Solutions. Cada entrada indica el producto y la versión que hemos usado, y el enlace lleva a su documentación oficial.

## 1. Documentos del proyecto

- Enunciado del Proyecto Intermodular (documento del aula).
- Anexo I: usuarios, grupos y permisos, con el fichero `usuarios_cibernova.csv`.
- Repositorio del grupo 7: [Proyecto-Intermodular-Berta-Sipek-Alex-Gutierrez](https://github.com/bertasipekmenendez-asix/Proyecto-Intermodular-Berta-Sipek-Alex-Gutierrez)

## 2. Virtualización

- **Proxmox VE 9.2.2** — *Proxmox VE Administration Guide*, de Proxmox Server Solutions: instalación, almacenamiento, VMs, `qm` y copias de seguridad. [pve.proxmox.com/pve-docs](https://pve.proxmox.com/pve-docs/)
- **cloud-init** — configuración del primer arranque de las VMs Linux, usada en la plantilla 9000. [cloudinit.readthedocs.io](https://cloudinit.readthedocs.io/)
- **virtio-win 0.1.302** — controladores VirtIO para Windows: `vioscsi` para el disco, el adaptador de red y las guest tools. [github.com/virtio-win](https://github.com/virtio-win/virtio-win-pkg-scripts)

## 3. Red, cortafuegos y alta disponibilidad

- **OPNsense 26.7** — documentación oficial: asignación de interfaces, reglas, NAT y alta disponibilidad con CARP, pfsync y sincronización XMLRPC. [docs.opnsense.org](https://docs.opnsense.org/)
- **RFC 2131**, *Dynamic Host Configuration Protocol* — por qué el broadcast DHCP no cruza routers y para qué sirve el relay. [rfc-editor.org/rfc/rfc2131](https://www.rfc-editor.org/rfc/rfc2131)

## 4. Windows Server y Active Directory

- **Windows Server 2025** — documentación de Microsoft Learn: Active Directory Domain Services, DNS, DHCP con failover, DFS y directivas de grupo. [learn.microsoft.com/windows-server](https://learn.microsoft.com/en-us/windows-server/)
- **Features on Demand (ISO LOF)** — qué contiene la imagen de idiomas y características, que al principio confundimos con la ISO de instalación. [Features on Demand](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-v2--capabilities?view=windows-11) y [Languages overview](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/languages-overview?view=windows-11)

## 5. Linux y automatización

- **Ubuntu Server 24.04 LTS** — documentación oficial del sistema base de las VMs Linux. [ubuntu.com/server/docs](https://ubuntu.com/server/docs/)
- **Ansible Core 2.16.3** — documentación oficial: inventario, playbooks, idempotencia, conexión WinRM y Ansible Vault. [docs.ansible.com](https://docs.ansible.com/)

## 6. Monitorización

- **Checkmk 2.5.0p18 Community** — documentación oficial: instalación del sitio, agentes y alta de hosts. [docs.checkmk.com](https://docs.checkmk.com/)

## 7. Documentación, control de versiones y diagramas

- **Git** — documentación oficial. [git-scm.com/doc](https://git-scm.com/doc)
- **Conventional Commits 1.0.0** — formato de los mensajes de commit del repositorio. [conventionalcommits.org](https://www.conventionalcommits.org/)
- **diagrams.net (draw.io)** — herramienta con la que están hechos los diagramas de `docs/diagramas/`. [diagrams.net](https://www.diagrams.net/)

## 8. De dónde hemos sacado cada imagen

- **Proxmox VE 9.2 ISO Installer** — descargas oficiales de Proxmox. [proxmox.com/en/downloads](https://www.proxmox.com/en/downloads)
- **Windows Server 2025, versión de evaluación (180 días)** — Microsoft Evaluation Center; en esa misma página está la ISO de idiomas y características (LOF) que al principio confundimos con la de instalación. [microsoft.com/en-us/evalcenter/download-windows-server-2025](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025)
- **virtio-win 0.1.302** — ISO de controladores VirtIO publicada por el proyecto virtio-win. [github.com/virtio-win](https://github.com/virtio-win/virtio-win-pkg-scripts)
- **OPNsense 26.7** — página de descarga oficial, con los ficheros de firma y los SHA256 para comprobar la imagen. [opnsense.org/download](https://opnsense.org/download/)
- **Ubuntu Server 24.04 LTS** — descarga oficial. [ubuntu.com/download/server](https://ubuntu.com/download/server)

---

Los enlaces llevan a la página principal de cada documentación, no a un apartado concreto, porque son las versiones las que cambian de sitio los apartados. Conviene abrirlos antes de entregar para comprobar que siguen vivos.
