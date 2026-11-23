# Etapa 4-projects

Crea por entorno los proyectos de servicio `<prefix>-<env>-app-<suffix>` y `<prefix>-<env>-data-<suffix>`, los une a la
Shared VPC de 3-networks y deja listos los permisos que necesita 5-workloads. Cada `envs/<env>` llama a
`modules/env`; solo cambia `local.env`.

Qué hace `modules/env`:

- Proyectos con `modules/project-factory` y sus APIs.
- `roles/compute.networkUser` por subred para el robot de GKE y el agente de Google APIs del proyecto de app;
  `roles/container.hostServiceAgentUser` en el host para el robot de GKE.
- Cuentas `gke_nodes`, `app_workload` y `vm` con roles mínimos.
- `roles/cloudkms.cryptoKeyEncrypterDecrypter` sobre `kms_keys[env]` de 2-security. El prefijo del propósito elige el
  agente: `storage*` → Cloud Storage (datos), `sql*` → Cloud SQL (datos), `gke*` → GKE (app).
- Proyectos de app y datos en el perímetro VPC-SC del entorno: spec dry-run con `vpc_sc_enforce = false` (default),
  status aplicado con `true`. Debe coincidir con 2-security.
- Permisos de la SA `5-workloads-<env>` de 0-bootstrap: roles de proyecto que 1-org no da en el folder
  (`deployer_roles`), `networkUser` en el host, `serviceAccountUser` sobre `gke_nodes` y `vm`, y `serviceAccountAdmin`
  solo sobre `app_workload` (para el binding de Workload Identity).

Lee el estado de `0-bootstrap`, `1-org`, `2-security` y `3-networks/<env>`.

```sh
cd envs/dev
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
terraform plan
```

Pruebas del módulo compartido: `cd modules/env && terraform init -backend=false && terraform test`.

Salidas (contrato §6): `app_project_id`, `app_project_number`, `data_project_id`, `data_project_number`,
`service_accounts`.
