#!/usr/bin/env bash
# Descubre las raíces de Terraform y los módulos con pruebas.
#
# Uso (rutas relativas a la raíz del repositorio):
#   discover-roots.sh roots              todas las raíces de etapa (dirs con versions.tf bajo stages/)
#   discover-roots.sh changed < files    raíces afectadas por la lista de archivos cambiados (stdin)
#   discover-roots.sh modules            módulos (globales y de etapa, stages/*/modules/*) y raíces de etapa con
#                                        carpeta tests/ (destinos de terraform test)
# Agrega --json como segundo argumento para recibir un arreglo JSON (para matrices de GitHub Actions).
#
# Reglas de "changed":
#   - archivo dentro de una raíz            -> esa raíz
#   - archivo en gcp-datacenter/modules/    -> todas las raíces
#   - archivo en una etapa fuera de raíces  -> todas las raíces de esa etapa (p. ej. stages/5-workloads/modules/env)
# Se excluye el legado stages/test-orchestration.
set -euo pipefail

cd "$(dirname "$0")/../.."

STAGES=gcp-datacenter/stages
MODULES=gcp-datacenter/modules

all_roots() {
  find "$STAGES" -name versions.tf \
    -not -path '*/.terraform/*' -not -path '*/modules/*' -not -path '*/examples/*' \
    -not -path '*/test-orchestration/*' -exec dirname {} \; | sort -u
}

changed_roots() {
  local roots files f r stage
  roots=$(all_roots)
  files=$(cat)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [[ $f == "$MODULES"/* ]]; then
      printf '%s\n' "$roots"
      continue
    fi
    [[ $f == "$STAGES"/* ]] || continue
    local hit=0
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      if [[ $f == "$r"/* ]]; then
        printf '%s\n' "$r"
        hit=1
      fi
    done <<<"$roots"
    if [ "$hit" -eq 0 ]; then
      stage=$(cut -d/ -f1-3 <<<"$f")
      [[ $stage == */test-orchestration ]] && continue
      grep -E "^${stage}(/|$)" <<<"$roots" || true
    fi
  done <<<"$files" | sort -u
}

modules_with_tests() {
  {
    find "$MODULES" -mindepth 2 -maxdepth 2 -type d -name tests -exec dirname {} \;
    find "$STAGES" -mindepth 4 -maxdepth 4 -type d -path '*/modules/*/tests' -exec dirname {} \;
    all_roots | while IFS= read -r r; do if [ -d "$r/tests" ]; then printf '%s\n' "$r"; fi; done
  } | sort -u
}

case "${1:-}" in
  roots) out=$(all_roots) ;;
  changed) out=$(changed_roots) ;;
  modules) out=$(modules_with_tests) ;;
  *)
    echo "uso: $0 roots|changed|modules [--json]" >&2
    exit 2
    ;;
esac

if [ "${2:-}" = "--json" ]; then
  printf '%s' "$out" | jq -R -s -c 'split("\n") | map(select(length > 0))'
else
  [ -z "$out" ] || printf '%s\n' "$out"
fi
