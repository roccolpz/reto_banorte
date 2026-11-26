# ADR 0022-k: Binary Authorization en prod con la atestación qa-approved firmada por el pipeline

- Estado: aceptada
- Fecha: 2026-11-24

## Contexto

ADR 0021-k exige 2 aprobaciones de QA antes de aplicar Terraform en prod, pero eso no cubre las imágenes de
contenedor: cualquiera con permisos de despliegue en el clúster podía correr una imagen que QA nunca vio. El módulo
`gke` ya activa Binary Authorization en modo `PROJECT_SINGLETON_POLICY_ENFORCE`, pero ningún proyecto tenía política,
y la política por defecto de GCP admite todo.

Binary Authorization no expresa "2 de N personas": una política exige una atestación de **cada** attestor que lista.

## Decisión

**El pipeline firma, después de la puerta de QA.** Nadie firma a mano.

1. **Manifiesto de release** `gcp-datacenter/release/prod-images.txt`: una imagen por línea, fijada por digest. Los
   tags se rechazan (un tag puede apuntar a otra imagen después de aprobado). CI valida el formato en cada PR.
2. **Puerta**: cambiar el manifiesto exige las 2 aprobaciones de QA del job `qa-approval` (ADR 0021-k), igual que
   una raíz de prod.
3. **Firma**: el job `attest-prod` de `apply.yml` (environment `prod`) usa la SA `attestor-prod` y
   `scripts/attest-images.sh sign`: arma el payload, firma con KMS y crea la atestación con `--validate`. Omite las
   imágenes ya firmadas. Solo comandos GA de gcloud.
4. **Recursos** (2-security, proyecto de seguridad): llave KMS `binauthz-qa-approved` (`ASYMMETRIC_SIGN`,
   `EC_SIGN_P256_SHA256`) en el keyring de prod, nota de Container Analysis y attestor `<prefix>-prod-qa-approved`.
5. **Política** (4-projects-prod, proyecto de app de prod): `REQUIRE_ATTESTATION` con el attestor qa-approved,
   `ENFORCED_BLOCK_AND_AUDIT_LOG`, y `global_policy_evaluation_mode = ENABLE` para las imágenes de sistema de GKE.
   dev y qa quedan con la política por defecto. La variable `binauthz_attestor` es obligatoria cuando `env = prod`.

### Mínimo privilegio

| Identidad | Recibe | Dónde |
|-----------|--------|-------|
| `attestor-prod` (0-bootstrap, nueva) | `cloudkms.signerVerifier` | solo la llave del attestor |
| | `binaryauthorization.attestorsVerifier` | solo el attestor |
| | `containeranalysis.notes.attacher`, `containeranalysis.occurrences.editor` | proyecto de seguridad (solo guarda esta nota y sus atestaciones) |
| | WIF solo con environment `prod` y rama `main` (`attribute.prod_main`) | — |
| | Nada en la organización, sin acceso al bucket de estado | — |
| `2-security` | `binaryauthorization.attestorsAdmin`, `containeranalysis.notes.editor` | proyecto de seguridad |
| `4-projects-prod` | `binaryauthorization.policyEditor` | solo la carpeta prod |
| | rol a medida `attestor_iam_admin` (get/getIamPolicy/setIamPolicy) | solo el attestor |
| Agente de Binary Authorization del proyecto de app de prod | `binaryauthorization.attestorsVerifier` | solo el attestor |
| Personas | nada nuevo: no firman ni administran la llave | — |

## Alternativas descartadas

- **Dos attestors firmados por personas** (dos grupos de QA disjuntos con su propia llave): dos personas reales
  firman cada imagen, pero los grupos deben mantenerse separados a mano y cada release exige firmas manuales. La
  regla de dos ya la aplica `qa-approval`, con los usuarios en un solo lugar (`QA_APPROVERS`).
- **Pipeline y además una persona de QA**: más fuerte, pero duplica la configuración y el trabajo por release sin
  cerrar un hueco que `qa-approval` deje abierto.
- **Firmar por tag o firmar en el pipeline de build de la app**: el tag es mutable, y el build no pasa por la
  aprobación de QA.

## Consecuencias

- En prod solo corren imágenes del manifiesto aprobado y las de sistema de GKE. Los pods que ya corrían siguen, pero
  no se pueden recrear con imágenes sin firmar.
- Quitar una línea del manifiesto **no** revoca la atestación. Para bloquear una imagen ya firmada hay que borrar su
  ocurrencia en Container Analysis (break_glass) o rotar la llave.
- Las llaves asimétricas no rotan solas: para rotar, crear una versión nueva, agregar su llave pública al attestor,
  cambiar `BINAUTHZ_KEY_VERSION` y deshabilitar la anterior.
- En una emergencia, Kubernetes admite la anotación de break-glass de Binary Authorization; queda en los logs de
  auditoría y debe seguir el runbook de break-glass.
- Orden de aplicación: 0-bootstrap (SA nueva, manual) → 1-org (roles y APIs) → 2-security (llave y attestor) →
  4-projects-prod (política). Variables de GitHub nuevas: `TF_SA_ATTESTOR_PROD`, `BINAUTHZ_ATTESTOR`,
  `BINAUTHZ_KEY_VERSION`.
