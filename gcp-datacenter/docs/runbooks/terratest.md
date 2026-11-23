# Runbook: pruebas de integración con Terratest

Qué: `gcp-datacenter/test/integration` tiene una prueba Go por módulo con `examples/`. Cada prueba aplica un fixture
de `gcp-datacenter/test/fixtures/<módulo>`, comprueba que un segundo plan no tenga cambios, revisa las salidas y
destruye. El workflow `terratest` las corre cada noche (06:00 UTC) y a mano, en un proyecto efímero que crea al
inicio y borra al final aunque las pruebas fallen.

En cada PR, el job `terratest-compile` de `ci.yml` compila las pruebas y valida los fixtures sin credenciales.

Quién prepara: `gcp-org-admins`, una sola vez. 0-bootstrap no crea estos recursos: viven fuera de la jerarquía
de la landing zone para que una prueba no toque dev, qa ni prod.

## 1. Folder y facturación de pruebas

- Un folder aparte, p. ej. `terratest`, fuera de `common`, `dev`, `qa` y `prod`. Las políticas de organización
  se heredan igual: las pruebas comprueban los módulos con las mismas restricciones.
- Una cuenta de facturación de pruebas, o la de la organización con un presupuesto y alerta propios.

## 2. Cuenta de servicio `sa-tf-terratest`

Créala en el proyecto semilla de 0-bootstrap y otórgale:

| Rol | Dónde | Para qué |
|-----|-------|----------|
| `roles/resourcemanager.projectCreator` | folder de pruebas | crear el proyecto efímero (queda como owner) y el de `TestProjectFactory` |
| `roles/resourcemanager.projectDeleter` | folder de pruebas | borrar los proyectos al terminar |
| `roles/billing.user` | cuenta de facturación de pruebas | vincular la facturación |
| `roles/accesscontextmanager.policyEditor` | política de acceso de pruebas (opcional) | `TestVPCSC` |

Vincúlala al WIF de 0-bootstrap solo para este repositorio:

```bash
gcloud iam service-accounts add-iam-policy-binding sa-tf-terratest@<proyecto-semilla>.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/<pool>/attribute.repository/<owner>/<repo>"
```

`<pool>` es el nombre completo del pool (`projects/<número>/locations/global/workloadIdentityPools/<id>`).

## 3. Política de acceso de pruebas (opcional)

`TestVPCSC` crea un perímetro en dry-run. No uses la política de la organización: crea una política con alcance
al folder de pruebas (`gcloud access-context-manager policies create --scopes=folders/<n>`). Sin
`TEST_ACCESS_POLICY`, la prueba se omite.

## 4. Variables del repositorio

| Variable | Valor |
|----------|-------|
| `TF_SA_TERRATEST` | correo de `sa-tf-terratest` |
| `TEST_FOLDER_ID` | `folders/<n>` del folder de pruebas |
| `TEST_BILLING_ACCOUNT` | ID de la cuenta de facturación de pruebas |
| `TEST_ACCESS_POLICY` | número de la política de acceso de pruebas (opcional) |

`WIF_PROVIDER` ya existe (paso 3 de `bootstrap-first-apply.md`).

## 5. Correr

- Todas: Actions > `terratest` > Run workflow.
- Algunas: en "run" escribe un filtro de `go test -run`, p. ej. `TestKMS|TestStorage`.
- En local, solo con un proyecto de pruebas propio y credenciales de usuario:

  ```bash
  cd gcp-datacenter/test
  export TEST_PROJECT_ID=<proyecto-de-pruebas> TEST_REGION=us-central1
  go test -v -count=1 -timeout 170m -run TestKMS ./integration/...
  ```

  Sin `TEST_PROJECT_ID` cada prueba se omite (`SKIP`), así que `go test ./...` es seguro sin credenciales.

Duración: GKE y Cloud SQL dominan, entre 30 y 60 minutos. El workflow corta a las 3 horas.

## 6. Cuando falla

- Lee el log del paso `go test`: Terratest imprime cada `terraform apply` y `destroy` con el fixture.
- "segundo plan con cambios": el módulo no es idempotente; abre un issue con el diff del plan.
- Error de cuota o API deshabilitada: agrega la API a la lista del paso "Crear el proyecto efímero" de
  `.github/workflows/terratest.yml`.
- El paso "Borrar el proyecto efímero" corre siempre. Si también falló, borra a mano los proyectos `acme-tt-*` y
  `tt-pf-*` del folder de pruebas:

  ```bash
  gcloud projects list --filter="parent.id=<n> AND projectId:acme-tt-" --format='value(projectId)'
  gcloud projects delete <proyecto> --quiet
  ```

  Un proyecto borrado queda 30 días en estado `DELETE_REQUESTED` y cuenta para la cuota de proyectos.

## 7. Agregar una prueba

1. Crea `test/fixtures/<módulo>/main.tf` con las variables `project_id`, `suffix` y `region`, y salidas para lo
   que vas a comprobar. Usa `../_network` si el módulo necesita VPC.
2. Agrega `Test<Módulo>` en `test/integration/modules_test.go` con `options` y `applyIdempotent`.
3. `go vet ./...` y `terraform -chdir=fixtures/<módulo> validate` deben pasar; `terratest-compile` lo comprueba en
   el PR.
