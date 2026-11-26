# Manual de operación y plan de recuperación

Cómo arrancar y parar la infraestructura en orden y qué hacer cuando algo falla. Es el procedimiento para manejar la infraestructura ya montada, de aquí en adelante; no es el relato de cómo la montamos, que está en la bitácora de la memoria. Estado a 23/11/2026. Lo que todavía no se ha podido probar está marcado como pendiente.

## 1. Antes de tocar nada

- Todo se gobierna desde **proxmoxAB** (192.168.202.7). Desde el PC del aula se entra por SSH con Proxmox de salto y, para la web y el RDP («Remote Desktop Protocol»: el escritorio remoto de Windows, que deja ver y manejar el escritorio de un servidor desde otro equipo), con túneles SSH.
- El inventario real lo da `qm list` en proxmoxAB: identifica cada VM por su nombre y su VMID («Virtual Machine ID»: el número con el que Proxmox identifica cada máquina virtual, como el 100 de DC01, y que piden todos los comandos qm) antes de arrancarla o pararla.
- Antes de un cambio que pueda romper algo, snapshot de la VM: `qm snapshot <vmid> antes-de-<cambio>`.

## 2. Arranque ordenado

El orden importa porque cada capa depende de la anterior: sin red no hay dominio, sin dominio no hay autenticación ni DNS, y sin eso el resto de servidores arrancan pero no sirven.

Desde el 23/11 esto ya no hay que hacerlo a mano: en Proxmox todas las VMs tienen el arranque automático activado y un orden con su espera, de modo que al encender el nodo arrancan solas en la secuencia de abajo. Los comandos sirven para arrancar una VM suelta, para comprobar el orden o si el arranque automático falla.

1. **proxmoxAB.** Encender el servidor físico y esperar a que responda la web en `https://192.168.202.7:8006`.
2. **FW01 y después FW02.** Son la puerta de enlace de todas las VLAN y el NAT hacia el aula. Esperar a que FW01 tenga las VIP en MASTER antes de seguir; en el arranque automático la espera configurada es de 30 segundos.
3. **DC01 y después DC02.** Active Directory y DNS. Hasta que no estén, ninguna máquina del dominio autentica. DC01 va primero y lleva la espera más larga, 120 segundos, porque es el que levanta el dominio; DC02 arranca 60 segundos después.
4. **DHCP01 y DHCP02.** Necesitan el dominio para estar autorizados en AD. Espera de 30 segundos; al arrancar, el failover vuelve solo a Normal.
5. **FILES01, FILES02 y BACKUP.** Dependen del dominio para los permisos y para las copias. Están en el dominio desde el 23/11, todavía sin roles.
6. **Ansible y Checkmk.** Ninguna de las dos da servicio a los usuarios, así que en el arranque automático van en este grupo, después de los servidores. Si vas a lanzar playbooks o a comprobar algo, arranca la VM Ansible a mano en cuanto esté el nodo: está en la VLAN 40 igual que los servidores, así que no necesita los cortafuegos para hablar con ellos.
7. **WEB01, WEB02, DB01 y DB02.** Último grupo: la web y la base de datos no hacen falta para que el dominio y los ficheros funcionen. Desde el 23/11 arrancan con el DNS apuntando a los DC y su segundo disco montado.

En proxmoxAB, una a una: `qm start <vmid>`, y comprobar con `qm status <vmid>` antes de pasar a la siguiente.

**En qué se basa este orden.** Es el que configuramos en Proxmox el 23/11, con la espera de cada grupo, y sale de las dependencias entre servicios. Lo que sigue pendiente es probar el arranque entero de una vez, y así consta en el apartado 7. Mientras la montábamos no seguíamos este orden: íbamos arrancando cada máquina según la instalábamos, y lo único ordenado que hicimos fue el apagado del 16/11, con `qm shutdown` y 300 segundos por VM. Al escribir este manual vimos que, para operar la infraestructura ya montada, el orden que tiene sentido es el de arriba, y no el que seguíamos por casualidad mientras la construíamos. Queda probarlo entero y corregir aquí lo que no cuadre.

## 3. Comprobaciones después de arrancar

1. **Red.** En la VM Ansible (192.168.40.5): `ping -c3 192.168.40.1`, que es la VIP de los cortafuegos, y `ping -c3 8.8.8.8`. Si responde el primero pero no el segundo, falla el NAT de salida; si no responde ninguno, los cortafuegos no han arrancado bien.
2. **Cortafuegos.** En la web de FW01, a la que se llega por túnel SSH, en *Virtual IPs: Status*: las cuatro VIP (WAN, LAN, CLIENTES y DMZ) tienen que salir en MASTER, y esas mismas en FW02 en BACKUP. Si aparecen en MASTER en los dos a la vez es que no se ven entre ellos: hay que mirar el enlace de sincronización de la VLAN 99.
3. **Dominio.** En DC01, en PowerShell: `repadmin /replsummary` tiene que dar 0 errores en los dos sentidos, y `dcdiag /q` no debe imprimir nada, porque solo saca los fallos. Desde la VM Ansible vale también `ansible-playbook playbooks/ad-99-verificar.yml`, que es el que usamos el 16/11.
4. **DHCP.** En DHCP01, en PowerShell: `Get-DhcpServerv4Failover` tiene que mostrar la relación CN-DHCP01-DHCP02 en estado *Normal*, y `Get-DhcpServerv4Scope`, el ámbito activo. Si sale como comunicación interrumpida, es que el otro DHCP todavía no está arriba.
5. **Todo junto.** Desde el PC del aula, abrir el túnel `-L 8080:192.168.40.20:80` y entrar en el sitio cibernova de Checkmk: ningún host ni servicio en rojo. Es la comprobación que lo resume todo, pero tarda un par de minutos en refrescar.

## 4. Parada ordenada

Al apagar el nodo, Proxmox para las VMs en el orden inverso al del arranque, así que normalmente no hay que hacer nada. Esta lista es para pararlo a mano: primero lo que no da servicio a nadie y al final lo que necesita todo lo demás.

1. Checkmk y Ansible.
2. WEB01/WEB02 y DB01/DB02.
3. FILES01 y FILES02.
4. DHCP02 y DHCP01.
5. DC02 y después DC01.
6. FW02 y después FW01.
7. proxmoxAB.

Siempre con apagado ordenado, nunca con `qm stop`, que es tirar del cable: `qm shutdown <vmid> --timeout 300`. Si una VM no se para en ese tiempo, mirar por qué antes de forzarla. Al terminar, `qm list` debe mostrarlas todas en *stopped*.

## 5. Qué hacer cuando falla algo

**Cae FW01.** No hay que hacer nada: FW02 asume las VIP solo. Probado el 19/11 con un ping continuo, sin perder ni un paquete. Después, arrancar FW01 y comprobar en *Virtual IPs: Status* que vuelve a MASTER.

**Cae un controlador de dominio.** El otro sigue autenticando y resolviendo DNS. Arrancar el caído y comprobar `repadmin /replsummary` antes de darlo por bueno.

**Cae un DHCP.** El otro sirve el ámbito completo. Probado el 19/11 reiniciando primero uno y luego el otro. Al volver, comprobar que el failover vuelve a *Normal*.

**Falla un disco.** El RAID 10 sigue funcionando con el espejo. Sustituir el disco y dejar que la controladora reconstruya; mientras tanto, no tocar nada más.

**Se cae el servidor físico.** Cae todo a la vez: es el punto único de fallo que tenemos documentado. La recuperación es reinstalar Proxmox y restaurar las VMs desde las copias.

## 6. Restaurar una VM desde copia de seguridad

**La VM BACKUP ya está montada y en el dominio desde el 23/11.** Lo que no está es la política: qué se copia, cada cuánto y dónde se guarda, que sigue *por decidir*. Lo que viene es el procedimiento previsto con las copias de Proxmox, **todavía sin probar**.

1. En proxmoxAB, localizar la copia: `ls -lh /var/lib/vz/dump/`, o el almacenamiento que se acabe decidiendo.
2. Si se va a sobrescribir una VM que existe, pararla antes con `qm shutdown <vmid>`.
3. Restaurar: `qmrestore /var/lib/vz/dump/<fichero>.vma.zst <vmid>`. Añadir `--force` solo para sobrescribir una VM existente, porque eso borra su disco actual.
4. Revisar `qm config <vmid>`: etiqueta de VLAN, discos y orden de arranque (es justo lo que falló en P2).
5. Arrancar la VM y pasar las comprobaciones de la sección 3.

Hoy las copias viven en el mismo servidor que protegen, así que no sirven si se pierde el host. Hace falta una copia fuera, con la regla 3-2-1.

## 7. Lo que falta para cerrar este manual

- Decidir dónde se guardan las copias y configurar la política en BACKUP, que ya está en el dominio.
- Hacer una restauración de prueba y anotar aquí cuánto tardó y qué hizo falta.
- Apagar y arrancar la infraestructura entera siguiendo las secciones 2 y 4, y corregir lo que no cuadre.
