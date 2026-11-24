#!/usr/bin/env bash
# Firma de imágenes de prod con el attestor qa-approved de Binary Authorization (ADR 0022-k).
#
#   attest-images.sh check <manifiesto>   valida el formato (CI de PR; sin gcloud ni credenciales)
#   attest-images.sh sign  <manifiesto>   firma cada imagen que aún no tenga atestación (apply.yml, job attest-prod)
#
# Manifiesto: una imagen por línea, fijada por digest (<registro>/<ruta>@sha256:<64 hex>); # inicia un comentario.
#
# Variables de sign (de las salidas de 2-security, guardadas como variables de GitHub):
#   BINAUTHZ_ATTESTOR     projects/<proyecto>/attestors/<nombre>
#   BINAUTHZ_KEY_VERSION  projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>/cryptoKeyVersions/<v>
#
# Solo usa comandos GA de gcloud: create-signature-payload, kms asymmetric-sign y attestations create --validate.
set -euo pipefail
export LC_ALL=C

mode=${1:-}
manifest=${2:-}
[[ $mode == check || $mode == sign ]] && [ -n "$manifest" ] || {
  echo "uso: attest-images.sh check|sign <manifiesto>" >&2
  exit 2
}
[ -f "$manifest" ] || {
  echo "::error::no existe el manifiesto $manifest"
  exit 1
}

# Registro con puerto opcional, uno o más segmentos de ruta en minúsculas, y digest sha256.
image_re='^[a-z0-9]([a-z0-9.-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+@sha256:[0-9a-f]{64}$'

images=()
errors=0
n=0
while IFS= read -r line || [ -n "$line" ]; do
  n=$((n + 1))
  entry=${line%%#*}
  entry=$(tr -d '[:space:]' <<<"$entry")
  [ -n "$entry" ] || continue
  if [[ ! $entry =~ $image_re ]]; then
    echo "::error file=$manifest,line=$n::'$entry' no es una imagen fijada por digest (<registro>/<ruta>@sha256:<64 hex>); los tags no se aceptan."
    errors=$((errors + 1))
    continue
  fi
  if printf '%s\n' "${images[@]+"${images[@]}"}" | grep -qxF "$entry"; then
    echo "::warning file=$manifest,line=$n::'$entry' está repetida."
    continue
  fi
  images+=("$entry")
done <"$manifest"

[ "$errors" -eq 0 ] || exit 1
echo "Manifiesto válido: ${#images[@]} imagen(es)."
[ "$mode" = check ] && exit 0

# ---------------- sign ----------------
attestor=${BINAUTHZ_ATTESTOR:?falta BINAUTHZ_ATTESTOR}
key_version=${BINAUTHZ_KEY_VERSION:?falta BINAUTHZ_KEY_VERSION}

attestor_re='^projects/([^/]+)/attestors/([^/]+)$'
[[ $attestor =~ $attestor_re ]] || { echo "::error::BINAUTHZ_ATTESTOR no es projects/<p>/attestors/<n>"; exit 1; }
attestor_project=${BASH_REMATCH[1]}

kv_re='^projects/([^/]+)/locations/([^/]+)/keyRings/([^/]+)/cryptoKeys/([^/]+)/cryptoKeyVersions/([0-9]+)$'
[[ $key_version =~ $kv_re ]] || { echo "::error::BINAUTHZ_KEY_VERSION no es una versión de llave de KMS completa"; exit 1; }
kms_project=${BASH_REMATCH[1]} kms_location=${BASH_REMATCH[2]} kms_keyring=${BASH_REMATCH[3]}
kms_key=${BASH_REMATCH[4]} kms_version=${BASH_REMATCH[5]}
# Mismo ID que la llave pública del attestor en 2-security/binauthz.tf.
public_key_id="//cloudkms.googleapis.com/v1/$key_version"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

signed=0 skipped=0
for image in "${images[@]+"${images[@]}"}"; do
  existing=$(gcloud container binauthz attestations list --project="$attestor_project" --attestor="$attestor" \
    --artifact-url="$image" --format='value(name)')
  if [ -n "$existing" ]; then
    echo "ya firmada: $image"
    skipped=$((skipped + 1))
    continue
  fi
  gcloud container binauthz create-signature-payload --artifact-url="$image" >"$work/payload.json"
  gcloud kms asymmetric-sign --project="$kms_project" --location="$kms_location" --keyring="$kms_keyring" \
    --key="$kms_key" --version="$kms_version" --digest-algorithm=sha256 \
    --input-file="$work/payload.json" --signature-file="$work/signature.bin"
  gcloud container binauthz attestations create --project="$attestor_project" --attestor="$attestor" \
    --artifact-url="$image" --signature-file="$work/signature.bin" --public-key-id="$public_key_id" --validate
  echo "firmada: $image"
  signed=$((signed + 1))
done

echo "Atestaciones qa-approved: $signed nueva(s), $skipped ya existían."
[ -n "${GITHUB_STEP_SUMMARY:-}" ] &&
  echo "🔏 Binary Authorization: $signed imagen(es) firmada(s), $skipped ya firmada(s)" >>"$GITHUB_STEP_SUMMARY"
exit 0
