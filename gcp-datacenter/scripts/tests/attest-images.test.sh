#!/usr/bin/env bash
# "cond && ok || ko" es seguro aquí: ok siempre devuelve 0.
# shellcheck disable=SC2015
# Pruebas de scripts/attest-images.sh con un "gcloud" falso que registra cada llamada (sin red ni credenciales).
#   bash gcp-datacenter/scripts/tests/attest-images.test.sh
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../attest-images.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# gcloud falso: "attestations list" devuelve una atestación si la imagen está en $FAKE_ATTESTED.
cat >"$tmp/gcloud" <<'GC'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_LOG"
case "$*" in
  "container binauthz attestations list "*)
    for a in "$@"; do case $a in --artifact-url=*) url=${a#--artifact-url=} ;; esac; done
    if grep -qxF "$url" <<<"${FAKE_ATTESTED:-}"; then echo "projects/p/occurrences/1"; fi
    ;;
  "container binauthz create-signature-payload "*) echo '{"critical":{}}' ;;
  "kms asymmetric-sign "*) for a in "$@"; do case $a in --signature-file=*) echo sig >"${a#--signature-file=}" ;; esac; done ;;
  "container binauthz attestations create "*) ;;
  *) echo "gcloud falso: llamada inesperada $*" >&2; exit 2 ;;
esac
GC
chmod +x "$tmp/gcloud"

D1=$(printf 'a%.0s' {1..64})
D2=$(printf 'b%.0s' {1..64})
IMG1="us-central1-docker.pkg.dev/acme-prod-app-ab12/apps/api@sha256:$D1"
IMG2="registry.example.com:5000/team/web@sha256:$D2"
ATTESTOR="projects/acme-common-security-ab12/attestors/acme-prod-qa-approved"
KV="projects/acme-common-security-ab12/locations/us-central1/keyRings/acme-prod-keyring-ab12/cryptoKeys/binauthz-qa-approved/cryptoKeyVersions/1"

pass=0 fail=0
ok() { pass=$((pass + 1)); echo "ok    $1"; }
ko() { fail=$((fail + 1)); echo "FALLA $1"; }

# run <modo> <contenido del manifiesto> [FAKE_ATTESTED]; deja la salida en $out, el exit en $rc y el log en $log
run() {
  printf '%b' "$2" >"$tmp/manifest.txt"
  log="$tmp/log.$RANDOM"
  : >"$log"
  rc=0
  out=$(PATH="$tmp:$PATH" FAKE_LOG="$log" FAKE_ATTESTED="${3:-}" BINAUTHZ_ATTESTOR="$ATTESTOR" \
    BINAUTHZ_KEY_VERSION="$KV" GITHUB_STEP_SUMMARY="" bash "$script" "$1" "$tmp/manifest.txt" 2>&1) || rc=$?
}

run check "# solo comentarios\n\n"
[ "$rc" -eq 0 ] && grep -q "0 imagen" <<<"$out" && ok "manifiesto vacío es válido" || ko "manifiesto vacío es válido"

run check "$IMG1  # api\n$IMG2\n"
[ "$rc" -eq 0 ] && grep -q "2 imagen" <<<"$out" && ok "imágenes por digest, comentarios y registro con puerto" || ko "imágenes por digest, comentarios y registro con puerto"

run check "us-central1-docker.pkg.dev/p/apps/api:v1.2\n"
[ "$rc" -eq 1 ] && grep -q "line=1" <<<"$out" && ok "rechaza imagen por tag" || ko "rechaza imagen por tag"

run check "$IMG1\nus-central1-docker.pkg.dev/p/apps/api@sha256:abc\n"
[ "$rc" -eq 1 ] && grep -q "line=2" <<<"$out" && ok "rechaza digest incompleto e indica la línea" || ko "rechaza digest incompleto e indica la línea"

run check "US-CENTRAL1-docker.pkg.dev/p/Apps/api@sha256:$D1\n"
[ "$rc" -eq 1 ] && ok "rechaza mayúsculas" || ko "rechaza mayúsculas"

run check "$IMG1\n$IMG1\n"
[ "$rc" -eq 0 ] && grep -q "repetida" <<<"$out" && grep -q "1 imagen" <<<"$out" && ok "repetidas se cuentan una vez con aviso" || ko "repetidas se cuentan una vez con aviso"

run check "$IMG1\n"
[ "$(wc -c <"$log" | tr -d ' ')" -eq 0 ] && ok "check no llama a gcloud" || ko "check no llama a gcloud"

run sign "$IMG1\n$IMG2\n"
if [ "$rc" -eq 0 ] && [ "$(grep -c '^container binauthz attestations create ' "$log")" -eq 2 ] &&
  grep -q -- "--attestor=$ATTESTOR" "$log" &&
  grep -q -- "--public-key-id=//cloudkms.googleapis.com/v1/$KV" "$log" &&
  grep -q -- "--validate" "$log" &&
  grep -q -- "kms asymmetric-sign --project=acme-common-security-ab12 --location=us-central1 --keyring=acme-prod-keyring-ab12 --key=binauthz-qa-approved --version=1 --digest-algorithm=sha256" "$log"; then
  ok "sign firma cada imagen con la llave y el attestor correctos"
else ko "sign firma cada imagen con la llave y el attestor correctos"; fi

run sign "$IMG1\n$IMG2\n" "$IMG1"
[ "$rc" -eq 0 ] && [ "$(grep -c '^container binauthz attestations create ' "$log")" -eq 1 ] &&
  ! grep -q "attestations create .*$D1" "$log" && grep -q "1 nueva(s), 1 ya existían" <<<"$out" &&
  ok "sign no vuelve a firmar una imagen ya atestada" || ko "sign no vuelve a firmar una imagen ya atestada"

run sign "imagen:latest\n"
[ "$rc" -eq 1 ] && [ "$(wc -c <"$log" | tr -d ' ')" -eq 0 ] && ok "sign no firma nada si el manifiesto es inválido" || ko "sign no firma nada si el manifiesto es inválido"

printf '%s\n' "$IMG1" >"$tmp/m.txt"
rc=0
PATH="$tmp:$PATH" FAKE_LOG="$tmp/x" BINAUTHZ_ATTESTOR="acme-prod-qa-approved" BINAUTHZ_KEY_VERSION="$KV" \
  bash "$script" sign "$tmp/m.txt" >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] && ok "sign exige el nombre completo del attestor" || ko "sign exige el nombre completo del attestor"

rc=0
PATH="$tmp:$PATH" FAKE_LOG="$tmp/x" BINAUTHZ_ATTESTOR="$ATTESTOR" BINAUTHZ_KEY_VERSION="" \
  bash "$script" sign "$tmp/m.txt" >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] && ok "sign exige BINAUTHZ_KEY_VERSION" || ko "sign exige BINAUTHZ_KEY_VERSION"

rc=0
bash "$script" check "$tmp/no-existe.txt" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] && ok "manifiesto inexistente falla" || ko "manifiesto inexistente falla"

run check "$(cat "$here/../../release/prod-images.txt")\n"
[ "$rc" -eq 0 ] && ok "release/prod-images.txt del repositorio es válido" || ko "release/prod-images.txt del repositorio es válido"

echo "Resumen: $pass ok, $fail con falla"
[ "$fail" -eq 0 ]
