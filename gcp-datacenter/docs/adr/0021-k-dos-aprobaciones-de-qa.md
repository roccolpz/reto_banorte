# ADR 0021-k: dos aprobaciones de QA antes de aplicar en prod

- Estado: aceptada
- Fecha: 2026-11-24

## Contexto

Un cambio de QA llega a prod solo con la aprobación de dos usuarios de QA con ese privilegio. La documentación
decía que el environment `prod` de GitHub "exige dos aprobaciones", pero GitHub pide **una sola** aprobación de la
lista de reviewers de un environment, sin importar cuántos haya. Revisión de la configuración real (2026-11-24):

- `main`: protección clásica que solo pide el check `ci-ok`, y los administradores se la saltan. Sin rulesets.
  El PR #1 se fusionó con 0 revisiones.
- Environment `prod`: un solo reviewer y "Prevent self-review" apagado: la misma persona hace merge y aprueba.
- El repositorio es de una cuenta personal: los equipos `@acme/...` de CODEOWNERS no existen (ADR 0017-j).
- WIF limitaba las SA de prod al environment `prod`, pero no a la rama `main`.

GitHub no tiene una regla nativa de "N aprobaciones de un grupo concreto": el ruleset cuenta aprobaciones de
cualquiera con escritura, y CODEOWNERS se cumple con un solo dueño.

## Decisión

1. **Job `qa-approval` en `apply.yml`**, del que depende toda la cadena. Si el push afecta una raíz de prod o una
   etapa común, `scripts/check-qa-approvals.sh` busca el PR fusionado del commit y exige al menos 2 aprobaciones:
   - de logins listados en la variable de repositorio `QA_APPROVERS` (solo la editan administradores);
   - sobre el último commit del PR, con la última revisión de cada persona (CHANGES_REQUESTED o DISMISSED anulan);
   - sin contar al autor del PR.
   Falla cerrado: sin `QA_APPROVERS`, sin PR (push directo) o con menos de 2, no se aplica nada de ese push. Corre
   con el código de `main`, no con el de la rama del PR. Pruebas en `scripts/tests/check-qa-approvals.test.sh`
   (job `script-tests` de CI).
2. **Ruleset de `main`** versionado en `.github/rulesets/main.json`: 2 aprobaciones, CODEOWNERS, descartar
   aprobaciones viejas, aprobación posterior al último push, `ci-ok` obligatorio, sin force push y **sin bypass**.
   Lo aplica un administrador con `gh api` (ver docs/README.md).
3. **WIF**: nuevo atributo `attribute.prod_main` en `0-bootstrap`, `"true"` solo con environment `prod` y ref
   `refs/heads/main`. Las SA de prod y de etapas comunes se limitan a ese atributo, para que un error en la
   protección de rama del environment no las abra.
4. **CODEOWNERS** pide la revisión de `@acme/gcp-qa-approvers` en las raíces de prod (aviso, no la regla de dos).
5. El environment `prod` queda con los aprobadores de QA y "Prevent self-review": tercera confirmación al aplicar.

## Alternativas descartadas

- **Solo el environment `prod` con varios reviewers**: sigue pidiendo una aprobación.
- **Check de PR con el evento `pull_request_review`**: corre el workflow de la rama del PR, así que el autor podría
  editarlo para que pase. La puerta en `apply.yml` corre después del merge con el código de `main`.
- **Regla "required reviewers" por equipo de los rulesets**: necesita una organización de GitHub con equipos; el
  repositorio es personal. Puede sustituir a `qa-approval` si el repositorio pasa a una organización.
- **Binary Authorization con dos firmantes**: cubre imágenes de contenedor, no cambios de Terraform. Las imágenes
  de prod quedan cubiertas en ADR 0022-k, con la firma del pipeline detrás de esta misma puerta.

## Consecuencias

- Hasta que un administrador defina `QA_APPROVERS` con al menos 2 logins, ningún push que toque prod o una etapa
  común se aplica (tampoco dev y qa de ese push, porque la cadena pasa por las etapas comunes).
- Con el ruleset, cada PR necesita 2 aprobaciones de personas distintas al autor y a quien hizo el último push.
- Cambiar `attribute.prod_main` exige volver a aplicar `0-bootstrap` (manual, administrador).
- Checklist de puesta en marcha: [runbooks/qa-approvers.md](../runbooks/qa-approvers.md).

## Excepción temporal (2026-11-25)

La variable de repositorio `QA_MIN_APPROVALS` baja el mínimo de aprobaciones de la puerta `qa-approval`; sin ella el
mínimo sigue en 2. Se usa solo cuando no hay aprobadores de QA disponibles (p. ej. un despliegue nocturno de una sola
persona) y se borra al terminar: `gh variable delete QA_MIN_APPROVALS`. Cada corrida con el mínimo reducido deja una
advertencia en el resumen del workflow. Durante la excepción también se baja a 0 la revisión obligatoria del ruleset
`main-protegida`, y se restaura al terminar.

