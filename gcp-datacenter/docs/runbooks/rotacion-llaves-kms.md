# Runbook: rotación de llaves KMS

Cuándo: revisión trimestral de la rotación automática, o una llave comprometida.
Quién: seguridad (rol `cloudkms.admin` en el proyecto de seguridad, vía la SA de `2-security` o break-glass).

Las llaves de `2-security` (`storage`, `storage-us`, `sql`, `sql-dr`, `gke` por entorno, y la del estado en
`0-bootstrap`) son simétricas y rotan solas cada 90 días (`rotation_period = 7776000s`). Rotar crea una versión primaria
nueva; los datos ya cifrados siguen legibles con las versiones anteriores, que siguen habilitadas. La llave de firma de
Binary Authorization es asimétrica y no rota sola (ADR 0022-k).

## 1. Revisar la rotación automática

```bash
SEC=<proyecto de seguridad: salida de 1-org>
for kr in $(gcloud kms keyrings list --location us-central1 --project "$SEC" --format 'value(name)'); do
  gcloud kms keys list --keyring "$kr" --location us-central1 --project "$SEC" \
    --format 'table(name.basename(),rotationPeriod,nextRotationTime,primary.name.basename())'
done
```

Repite con `--location us-east4` y `--location us`. Cada llave simétrica debe tener `rotationPeriod: 7776000s` y un
`nextRotationTime` a menos de 90 días. Si falta, el drift lo detecta; corrígelo con un PR, no en la consola.

## 2. Rotación manual (llave comprometida)

```bash
gcloud kms keys versions create --key <llave> --keyring <keyring> --location <región> \
  --project "$SEC" --primary
```

Los datos nuevos usan la versión nueva desde ese momento. Para los existentes:

| Servicio | Recifrar |
|---|---|
| Cloud Storage | Reescribir los objetos: `gcloud storage objects update gs://<bucket>/** --encryption-key=<llave>` |
| Cloud SQL | No se recifra en sitio: clonar la instancia (`gcloud sql instances clone`) y cambiar las aplicaciones a la nueva |
| GKE (secretos en etcd) | `gcloud container clusters update <clúster> --database-encryption-key <llave>` vuelve a cifrar los secretos |
| Estado de Terraform | El siguiente `apply` de cada etapa reescribe su objeto con la versión nueva |

## 3. Deshabilitar la versión comprometida

Solo cuando ningún dato dependa de ella (revisa con `gcloud kms keys versions describe` y los registros de auditoría
de `cloudkms.googleapis.com` que no haya `Decrypt` recientes con esa versión):

```bash
gcloud kms keys versions disable <versión> --key <llave> --keyring <keyring> --location <región> --project "$SEC"
```

Destruirla es irreversible y los datos que aún cifre se pierden. GCP la programa a 30 días; durante ese plazo se puede
restaurar con `gcloud kms keys versions restore`.

## 4. Cerrar

- Registra la llave, la versión y la causa en el issue del incidente.
- Si la rotación fue por compromiso, revisa quién tenía `cryptoKeyEncrypterDecrypter` sobre la llave (salida de
  `gcloud kms keys get-iam-policy`).
