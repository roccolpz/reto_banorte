# ADR 0019-i: desviaciones de 4-projects y 5-workloads frente al contrato

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

La ronda 2 pide etiquetas seguras en nodos de GKE y VM, un clúster GKE DR en us-east4, tamaños por entorno y un
uptime check. Varias piezas no se pueden hacer como están escritas con las salidas actuales del contrato §6.

## Decisiones

1. **Llave de las etiquetas seguras.** `resource_manager_tags` de GKE y de las plantillas de Compute exige pares
   `tagKeys/ID = tagValues/ID`. El contrato publica solo `secure_tag_values` (`tagValues/ID`), y GCP no deja derivar la
   llave desde el ID del valor sin una llamada a la API. Las raíces de 5-workloads buscan la llave con el data source
   `google_tags_tag_key` por el nombre que le da 3-networks: `<prefix>-<env>-net-fw` en el proyecto host. Es un
   acoplamiento a un nombre interno de otro frente. Se quita cuando 3-networks publique `secure_tag_keys` en §6.
2. **Clúster DR sin CMEK en etcd.** 2-security solo crea `gke` en us-central1, y una llave de KMS debe estar en la
   región del clúster. El clúster DR usa `kms_keys["gke-dr"]` si existe; mientras no exista, los secretos de etcd
   quedan con cifrado de Google. Basta con que 2-security agregue `gke-dr` en us-east4 para prod; no hay cambio aquí.
3. **S4 solo cubre el master CIDR.** La validación contra `192.168.0.0/16` aplica a `master_ipv4_cidr_block`. No aplica
   a `master_authorized_networks`, porque los administradores on-prem entran desde 192.168.x.
4. **Uptime check opcional.** `uptime_check_host` queda en null en los tfvars de ejemplo: la aplicación no tiene aún un
   host público. El uptime check se crea cuando el equipo de la aplicación lo defina.
5. **tagUser de las VM.** 4-projects da `roles/resourcemanager.tagUser` sobre el valor `vm` al deployer y al agente
   `cloudservices` del proyecto de app, que es quien crea las VM del MIG. No está confirmado en la documentación que
   el MIG use esa identidad; si el primer apply falla al ligar la etiqueta, se agrega el agente de Compute.

## Consecuencias

- Abrir en 3-networks la salida `secure_tag_keys` (mapa `gke-nodes`, `vm` → `tagKeys/ID`) y borrar el data source.
- Abrir en 2-security la llave `gke-dr` (prod, us-east4).
- La alerta de túneles VPN solo existe en prod, y solo prod agrega el hub a su metrics scope. El deployer de prod
  necesita permiso de metrics scope sobre el hub (frente G).
