"""Alta de usuarios de CiberNova desde el CSV (Anexo I).

PENDIENTE DE DECIDIR: el lenguaje del script todavía no está aprobado
(PowerShell, Ansible o PowerShell lanzado desde Ansible). Este fichero solo
reserva el sitio en la estructura; no contiene lógica.

Requisitos que tendrá que cumplir (Anexo I y reglas del proyecto):
- Leer usuarios_cibernova.csv y crear OU, grupos G_ y DL_, usuarios y carpetas personales.
- Ser idempotente: una segunda ejecución no crea duplicados.
- No guardar contraseñas en claro.
"""
