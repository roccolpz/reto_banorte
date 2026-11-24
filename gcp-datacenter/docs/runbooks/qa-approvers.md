# Runbook: alta de los aprobadores de QA

Checklist para activar la regla "dos usuarios de QA aprueban cada pase a prod" (ADR 0020-k y ADR 0021-k).
El código ya está; falta dar de alta a las personas y aplicar la configuración. Los pasos marcados **(admin)**
los hace un administrador del repositorio (`roccolpz`) o de la organización de GCP.

## 0. Quiénes son

Llenar antes de empezar. Se necesitan **al menos 2** personas (con 3 o más, una ausencia no bloquea prod).
Ninguna debería ser quien normalmente abre los PR de prod: el autor del PR no cuenta como aprobación.

| Nombre | Login de GitHub | Correo de Google (Cloud Identity) | GitHub ✔ | Google ✔ |
|--------|-----------------|-----------------------------------|----------|----------|
|        |                 |                                   | [ ]      | [ ]      |
|        |                 |                                   | [ ]      | [ ]      |
|        |                 |                                   | [ ]      | [ ]      |

## 1. GitHub

- [ ] **(admin)** Invitar a cada login como colaborador con permiso **Write** (Settings > Collaborators). Sin
      escritura, su aprobación no cuenta para el ruleset ni para el environment.
- [ ] **(admin)** Variable de repositorio `QA_APPROVERS` (Settings > Secrets and variables > Actions > Variables),
      logins separados por coma, p. ej. `ana,beto,caro`:
      `gh variable set QA_APPROVERS --repo roccolpz/reto_banorte --body "ana,beto,caro"`
      ⚠️ Mientras esté vacía o tenga menos de 2 logins, `qa-approval` bloquea todo push que toque prod o una
      etapa común.
- [ ] **(admin)** Environment `prod` (Settings > Environments > prod): en **Required reviewers** poner a los
      aprobadores de QA (máx. 6) y activar **Prevent self-review**. Rama de despliegue: solo `main` (ya está).
- [ ] **(admin)** Aplicar el ruleset de `main`:
      `gh api -X POST repos/roccolpz/reto_banorte/rulesets --input .github/rulesets/main.json`
- [ ] **(admin)** Quitar la protección clásica de `main` (Settings > Branches) para que el ruleset sea la única
      regla.
- [ ] Si el repositorio pasa a una organización de GitHub: crear el equipo `gcp-qa-approvers` con estas personas
      (CODEOWNERS ya lo usa en las raíces de prod) y revisar el prefijo `acme` (ADR 0017-j).

## 2. Google Cloud

- [ ] **(admin)** Crear el grupo `gcp-qa-approvers@<dominio>` en Cloud Identity / Workspace y agregar los
      correos de la tabla.
- [ ] Agregarlo a los grupos de `1-org` (tfvars o `TF_VAR_groups`):
      `groups = { qa_approvers = "gcp-qa-approvers@<dominio>" }`
      Da solo lectura en las carpetas `qa` y `prod` (ADR 0020-k). Se aplica por PR como cualquier cambio de `1-org`.
- [ ] **(admin)** Volver a aplicar `0-bootstrap` a mano ([bootstrap-first-apply](bootstrap-first-apply.md)) para
      que WIF use `attribute.prod_main` (environment `prod` **y** rama `main`). Hasta entonces sigue la condición
      anterior (solo environment `prod`).

## 3. Binary Authorization de prod (ADR 0022-k)

Orden: cada paso usa lo que crea el anterior.

- [ ] **(admin)** Volver a aplicar `0-bootstrap` (si no se hizo en el paso 2): crea la SA `attestor-prod`.
- [ ] **(admin)** Variable `TF_SA_ATTESTOR_PROD` con el correo de `stage_service_accounts["attestor-prod"]`.
- [ ] Aplicar `1-org` por PR: APIs de Binary Authorization y Container Analysis en el proyecto de seguridad, rol a
      medida `attestor_iam_admin` y roles de `2-security`, `attestor-prod` y `4-projects-prod`.
- [ ] Aplicar `2-security` por PR: llave `binauthz-qa-approved`, nota y attestor `qa-approved`.
- [ ] **(admin)** Variables `BINAUTHZ_ATTESTOR` (salida `binauthz_attestor.id`) y `BINAUTHZ_KEY_VERSION` (salida
      `binauthz_key_version`) de 2-security.
- [ ] Aplicar `4-projects-prod` por PR: política del proyecto de app de prod.
      ⚠️ Desde aquí, prod solo corre imágenes del manifiesto firmadas. Si ya hay cargas en prod, agregar sus
      imágenes (por digest) a `release/prod-images.txt` **antes** de este paso.
- [ ] Prueba: un PR que agrega una imagen por digest a `release/prod-images.txt` → 2 aprobaciones de QA → merge →
      `attest-prod` firma → `kubectl run` con esa imagen en prod funciona; con otra imagen, el admission la rechaza.

Bloquear una imagen ya firmada: quitarla del manifiesto no basta. Un miembro de `break_glass` borra la ocurrencia
de la atestación en Container Analysis (proyecto de seguridad) o se rota la llave (ADR 0022-k).

## 4. Prueba de punta a punta

- [ ] Abrir un PR que cambie algo menor en una raíz de prod (p. ej. un comentario en
      `stages/5-workloads/envs/prod/main.tf`).
- [ ] Con **una** aprobación de QA: el ruleset no deja fusionar (pide 2).
- [ ] Con 2 aprobaciones que **no** sean de QA: se puede fusionar, pero `qa-approval` falla en `apply.yml` y no se
      aplica nada. Revisar el mensaje del job.
- [ ] Con 2 aprobaciones de QA sobre el último commit: `qa-approval` pasa, dev y qa se aplican, y cada job de prod
      espera la aprobación del environment.
- [ ] Un push nuevo después de aprobar descarta las aprobaciones (hay que volver a pedirlas).

## Bajas y cambios

- Quitar el login de `QA_APPROVERS`, del environment `prod` y, si aplica, del equipo de GitHub.
- Quitar el correo del grupo de Google. No hace falta cambiar Terraform.
