#!/usr/bin/env bash
# Puerta de QA (ADR 0021-k): verifica que un commit de main venga de un pull request fusionado con al menos
# QA_MIN_APPROVALS aprobaciones de usuarios de QA sobre su último commit.
#
#   check-qa-approvals.sh <owner/repo> <sha>
#
# Variables:
#   QA_APPROVERS      logins de GitHub de los aprobadores de QA, separados por coma o espacio (variable del repo)
#   QA_MIN_APPROVALS  aprobaciones necesarias (default 2)
#   BASE_BRANCH       rama a la que se fusionó el PR (default main)
#   GH_TOKEN          token con lectura de pull requests (en Actions: github.token)
#
# Reglas, iguales a las de GitHub para "dismiss stale reviews":
#   - cuenta la última revisión de cada usuario; COMMENTED y PENDING no cambian su estado;
#   - la aprobación debe ser sobre el último commit del PR (head);
#   - el autor del PR no cuenta, aunque esté en QA_APPROVERS.
# Falla cerrado: sin QA_APPROVERS, sin PR o sin aprobaciones suficientes, sale con 1.
set -euo pipefail
export LC_ALL=C

repo=${1:?uso: check-qa-approvals.sh <owner/repo> <sha>}
sha=${2:?uso: check-qa-approvals.sh <owner/repo> <sha>}
min=${QA_MIN_APPROVALS:-2}
base=${BASE_BRANCH:-main}

fail() {
  echo "::error::$1"
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "❌ Puerta de QA: $1" >>"$GITHUB_STEP_SUMMARY"
  exit 1
}

lower() { tr '[:upper:]' '[:lower:]'; }

approvers=$(tr -s ', ' '\n' <<<"${QA_APPROVERS:-}" | sed '/^$/d' | lower | sort -u)
[ -n "$approvers" ] || fail "la variable QA_APPROVERS está vacía: nadie puede aprobar pases a prod (ver docs/runbooks/qa-approvers.md)."
n_approvers=$(wc -l <<<"$approvers" | tr -d ' ')
[ "$n_approvers" -ge "$min" ] ||
  fail "QA_APPROVERS tiene $n_approvers usuario(s); se necesitan al menos $min para poder juntar $min aprobaciones."

pr=$(gh api "repos/$repo/commits/$sha/pulls" \
  --jq "[.[] | select(.merged_at != null and .base.ref == \"$base\")] | first // empty | [.number, .user.login, .head.sha] | @tsv")
[ -n "$pr" ] || fail "el commit $sha no viene de un pull request fusionado a $base (¿push directo?)."
IFS=$'\t' read -r number author head <<<"$pr"
author=$(lower <<<"$author")
echo "PR #$number de $author, último commit $head"

# Última revisión con estado de cada usuario, en orden cronológico (la API las devuelve así).
approved_on_head=$(
  gh api --paginate "repos/$repo/pulls/$number/reviews" --jq '.[] | [.user.login, .state, .commit_id] | @tsv' |
    awk -F'\t' '$2 != "COMMENTED" && $2 != "PENDING" { u = tolower($1); state[u] = $2; commit[u] = $3 }
      END { for (u in state) print u "\t" state[u] "\t" commit[u] }' |
    awk -F'\t' -v head="$head" '$2 == "APPROVED" && $3 == head { print $1 }' | sort -u
)

valid=$(comm -12 <(echo "$approvers") <(echo "$approved_on_head") | grep -vxF "$author" || true)
count=$(sed '/^$/d' <<<"$valid" | wc -l | tr -d ' ')

echo "Aprobaciones de QA válidas: $count de $min necesarias${valid:+ ($(paste -sd, - <<<"$valid"))}"
[ "$count" -ge "$min" ] ||
  fail "el PR #$number tiene $count aprobación(es) de QA sobre su último commit; se necesitan $min."

[ -n "${GITHUB_STEP_SUMMARY:-}" ] &&
  echo "✅ Puerta de QA: PR #$number aprobado por $(paste -sd, - <<<"$valid")" >>"$GITHUB_STEP_SUMMARY"
exit 0
