# Runbook: agregar un entorno o un proyecto de aplicación

## A. Nuevo entorno (p. ej. `uat`)

Un entorno toca todas las etapas. Hazlo en un solo PR por etapa, en este orden.

1. **Decidir el direccionamiento.** Elige un valor `X` libre para `10.X.0.0/16` (usados: 10 dev, 20 qa, 30 y 31 prod)
   y un rango de master de GKE `172.16.X.0/28`. No debe solaparse con `192.168.0.0/16` (on-prem) ni con `10.0.0.0/16`
   (hub). Anótalo en `gcp-datacenter/docs/CONTRATO.md` §5.
2. **Permitir el nombre.** Las variables `env` validan la lista `dev`, `qa`, `prod`; agrega el nuevo valor donde se
   valide (módulos y raíces). Actualiza el contrato §4.
3. **0-bootstrap.** Agrega las SA `3-networks-<env>`, `4-projects-<env>`, `5-workloads-<env>` a
   `stage_service_accounts`. Lo aplica un administrador (no está en el pipeline). Crea las variables de GitHub
   `TF_SA_3_NETWORKS_<ENV>`, `TF_SA_4_PROJECTS_<ENV>` y `TF_SA_5_WORKLOADS_<ENV>`.
4. **1-org.** Carpeta y proyecto `acme-<env>-net-host-xxxx`.
5. **2-security.** Llaves KMS, secretos y perímetro de VPC-SC del entorno (en dry-run).
6. **3-networks, 4-projects, 5-workloads.** Copia `envs/qa` a `envs/<env>` en cada etapa, cambia el `prefix` de
   `backend.tf` a `<etapa>/<env>` y los `locals` del entorno.
7. **CI.** `ci.yml` y `drift.yml` descubren las raíces nuevas solas. `apply.yml` no: agrega tres jobs
   (`net-<env>`, `projects-<env>`, `workloads-<env>`) copiando los de qa, con `environment: <env>`, y agrega las
   raíces a la lista `known`. Crea el environment `<env>` en GitHub.
8. **CODEOWNERS.** Si el entorno tiene dueños distintos, agrega sus rutas.

Comprueba: el PR muestra el plan de las raíces nuevas, y después del merge `apply` las aplica en orden.

## B. Nuevo proyecto de aplicación en un entorno existente

1. En `4-projects/envs/<env>`, agrega el proyecto con el mismo módulo que usan los proyectos `app` y `data`:
   nombre `acme-<env>-<dominio>-xxxx` (máx. 30 caracteres), las 5 etiquetas, adjunto a la Shared VPC del entorno.
2. Si el proyecto guarda datos, agrégalo al perímetro de VPC-SC del entorno: en prod desde 4-projects; en dev y qa
   desde 2-security, que lee las salidas de `4-projects/<env>` (ADR 0007-f). El perímetro ignora cambios en esa lista.
3. Si necesita SA propias, agrégalas a la salida `service_accounts` y documenta la llave en el contrato §6.
4. Abre el PR; revisa el plan y que las políticas pasen. El apply corre en el orden normal.
