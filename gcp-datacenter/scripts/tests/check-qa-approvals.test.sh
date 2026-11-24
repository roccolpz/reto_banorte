#!/usr/bin/env bash
# Pruebas de scripts/check-qa-approvals.sh con un "gh" falso (sin red ni token).
#   bash gcp-datacenter/scripts/tests/check-qa-approvals.test.sh
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../check-qa-approvals.sh"
fake=$(mktemp -d)
trap 'rm -rf "$fake"' EXIT

# El gh falso devuelve lo que el script pediría con --jq: el PR como TSV y las revisiones como TSV.
cat >"$fake/gh" <<'GH'
#!/usr/bin/env bash
case "$*" in
  *"/commits/"*) printf '%s' "$FAKE_PR" ;;
  *"/reviews"*) printf '%s' "$FAKE_REVIEWS" ;;
  *) echo "gh falso: llamada inesperada $*" >&2; exit 2 ;;
esac
GH
chmod +x "$fake/gh"

pass=0 fail=0
HEAD=h2
PR=$'7\tautor\th2'

# check <nombre> <exit esperado> <QA_APPROVERS> <revisiones "login estado commit" separadas por ;>
check() {
  local name=$1 want=$2 approvers=$3 reviews=$4 got=0
  reviews=$(tr ';' '\n' <<<"$reviews" | sed '/^$/d' | tr ' ' '\t')
  PATH="$fake:$PATH" FAKE_PR=${FAKE_PR_OVERRIDE-$PR} FAKE_REVIEWS="$reviews" QA_APPROVERS="$approvers" \
    GITHUB_STEP_SUMMARY="" bash "$script" o/r sha >/dev/null 2>&1 || got=$?
  if [ "$got" -eq "$want" ]; then pass=$((pass + 1)); echo "ok    $name"; else
    fail=$((fail + 1)); echo "FALLA $name (exit $got, se esperaba $want)"; fi
}

check "dos QA aprueban el último commit"           0 "ana,beto,caro" "ana APPROVED $HEAD;beto APPROVED $HEAD"
check "una sola aprobación de QA no basta"         1 "ana,beto"      "ana APPROVED $HEAD"
check "aprobación de alguien fuera de QA no cuenta" 1 "ana,beto"     "ana APPROVED $HEAD;zeta APPROVED $HEAD"
check "aprobación sobre un commit viejo no cuenta" 1 "ana,beto"      "ana APPROVED $HEAD;beto APPROVED h1"
check "el autor del PR no cuenta"                  1 "ana,autor"     "ana APPROVED $HEAD;autor APPROVED $HEAD"
check "cambio a CHANGES_REQUESTED anula"           1 "ana,beto"      "ana APPROVED $HEAD;beto APPROVED $HEAD;beto CHANGES_REQUESTED $HEAD"
check "un comentario posterior no anula"           0 "ana,beto"      "ana APPROVED $HEAD;beto APPROVED $HEAD;beto COMMENTED $HEAD"
check "DISMISSED anula"                            1 "ana,beto"      "ana APPROVED $HEAD;beto APPROVED $HEAD;beto DISMISSED $HEAD"
check "logins sin distinguir mayúsculas"           0 "Ana, BETO"     "ana APPROVED $HEAD;Beto APPROVED $HEAD"
check "la misma persona dos veces cuenta una"      1 "ana,beto"      "ana APPROVED $HEAD;ana APPROVED $HEAD"
check "QA_APPROVERS vacía falla cerrado"           1 ""              "ana APPROVED $HEAD;beto APPROVED $HEAD"
check "QA_APPROVERS con menos de 2 falla"          1 "ana"           "ana APPROVED $HEAD"
FAKE_PR_OVERRIDE="" check "commit sin PR (push directo) falla" 1 "ana,beto" "ana APPROVED $HEAD;beto APPROVED $HEAD"

echo "Resumen: $pass ok, $fail con falla"
[ "$fail" -eq 0 ]
