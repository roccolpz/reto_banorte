# Runbook: rotar un secreto o una llave

Terraform crea los contenedores de Secret Manager (salida `secret_ids` de `2-security`) pero no sus versiones: el valor
nunca está en el código ni en el estado.

## A. Secreto de Secret Manager

1. Identifica el secreto: `terraform output -json secret_ids` en `2-security`, o
   `gcloud secrets list --project acme-common-security-xxxx`.
2. Genera el valor nuevo en el sistema dueño (p. ej. la contraseña de Cloud SQL con
   `gcloud sql users set-password`).
3. Agrega la versión sin dejar el valor en el historial del shell:

   ```bash
   gcloud secrets versions add <secreto> --project <proyecto> --data-file=-
   # pega el valor, Enter, Ctrl-D
   ```

4. Reinicia o recarga las cargas que lo leen (las que fijan `latest` toman la versión nueva al reiniciar).
5. Comprueba que funcionan y deshabilita la versión anterior:

   ```bash
   gcloud secrets versions disable <versión-anterior> --secret <secreto> --project <proyecto>
   ```

6. Destrúyela después de un periodo de gracia (p. ej. 7 días). Destruir es irreversible:
   `gcloud secrets versions destroy <versión> --secret <secreto> --project <proyecto>`.

## B. Llaves KMS

Procedimiento completo, con el recifrado por servicio: [rotacion-llaves-kms.md](rotacion-llaves-kms.md).

Las llaves de `2-security` rotan solas cada 90 días (`rotation_period`). La rotación crea una versión primaria nueva;
los datos ya cifrados siguen legibles con las versiones anteriores, que no se deshabilitan.

Rotación manual (llave comprometida):

```bash
gcloud kms keys versions create --key <llave> --keyring <keyring> --location <región> \
  --project acme-common-security-xxxx --primary
```

Después, vuelve a cifrar los datos que lo necesiten y deshabilita la versión comprometida. Nunca destruyas una versión
que todavía protege datos: se pierden.

## C. Credenciales del pipeline

No hay llaves de SA que rotar: CI usa Workload Identity Federation (ADR 0004-e). Para revocar el acceso de CI,
quita el binding `roles/iam.workloadIdentityUser` de la SA afectada en `0-bootstrap`.

## D. Secreto compartido de HA VPN

Rota los dos lados a la vez: agrega la versión nueva y aplica `3-networks/hub` en una ventana de mantenimiento, un
túnel a la vez. Si un túnel no vuelve, sigue `vpn-down.md`.
