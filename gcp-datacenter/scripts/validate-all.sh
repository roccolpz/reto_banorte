#!/usr/bin/env bash
# Validación local completa, sin credenciales ni backend:
#   1. terraform fmt -check en módulos y etapas
#   2. init -backend=false + validate en cada raíz y en cada examples/* de módulo
#   3. terraform test en cada módulo y raíz con carpeta tests/
# Sale con código distinto de cero si algo falla; imprime un resumen al final.
# Usa TF_PLUGIN_CACHE_DIR si está definido para no descargar proveedores en cada raíz.
set -euo pipefail

cd "$(dirname "$0")/../.."
DISCOVER=gcp-datacenter/scripts/discover-roots.sh

pass=0
fail=0
failed=()
log=$(mktemp)
trap 'rm -f "$log"' EXIT

run() {
  local label=$1
  shift
  if "$@" >"$log" 2>&1; then
    pass=$((pass + 1))
    echo "ok    $label"
  else
    fail=$((fail + 1))
    failed+=("$label")
    echo "FALLA $label"
    sed 's/^/      /' "$log" | tail -n 20
  fi
}

# init puede agregar hashes de la plataforma local al lock file versionado, o crear uno nuevo;
# al terminar se restaura el original o se borra el creado.
tf_run() {
  local dir=$1 cmd=$2 lock="$1/.terraform.lock.hcl" saved="" rc=0
  [ -f "$lock" ] && saved=$(cat "$lock")
  terraform -chdir="$dir" init -backend=false -input=false >/dev/null &&
    terraform -chdir="$dir" "$cmd" -no-color || rc=$?
  if [ -n "$saved" ]; then printf '%s\n' "$saved" >"$lock"; else rm -f "$lock"; fi
  return "$rc"
}

echo "== fmt"
for d in gcp-datacenter/modules gcp-datacenter/stages/*/; do
  d=${d%/}
  [ -d "$d" ] || continue
  run "fmt $d" terraform fmt -check -recursive "$d"
done

echo "== validate"
roots=$(bash "$DISCOVER" roots)
examples=$(find gcp-datacenter/modules -mindepth 3 -maxdepth 3 -type d -path '*/examples/*' | sort)
for d in $roots $examples; do
  [ -d "$d" ] || continue
  run "validate $d" tf_run "$d" validate
done

echo "== terraform test"
for m in $(bash "$DISCOVER" modules); do
  run "test $m" tf_run "$m" test
done

echo
echo "Resumen: $pass ok, $fail con falla"
for f in "${failed[@]+"${failed[@]}"}"; do
  echo "  - $f"
done
[ "$fail" -eq 0 ]
