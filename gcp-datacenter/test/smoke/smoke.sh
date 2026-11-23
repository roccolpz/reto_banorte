#!/usr/bin/env bash
# Pruebas de humo de un entorno recién aplicado. apply.yml las corre en dev (job tests-dev) y qa solo se
# aplica si pasan. Uso: smoke.sh gcp-datacenter/stages/5-workloads/envs/<env>
# La raíz ya debe estar inicializada con su backend y la SA de 5-workloads-<env> (la deja así tf-init).
# Comprueba: segundo plan sin cambios, GKE en RUNNING, Cloud SQL en RUNNABLE y el MIG estable.
set -euo pipefail

root=${1:?"uso: smoke.sh <raíz de 5-workloads/envs/<env>>"}
fail() { echo "::error::smoke $root: $*"; exit 1; }
tf() { terraform -chdir="$root" "$@"; }

# 1. Idempotencia: 0 = sin cambios, 2 = cambios pendientes después del apply.
set +e
tf plan -input=false -lock=false -no-color -detailed-exitcode >/dev/null
rc=$?
set -e
case $rc in
  0) echo "plan sin cambios" ;;
  2) fail "el plan posterior al apply tiene cambios" ;;
  *) fail "terraform plan falló (código $rc)" ;;
esac

# Proyectos de 4-projects, leídos del estado remoto que ya usa la raíz.
app=$(echo 'local.projects.app_project_id' | tf console | tr -d '"')
data=$(echo 'local.projects.data_project_id' | tf console | tr -d '"')
gke=$(tf output -raw gke_cluster_name)
sql=$(tf output -raw sql_instance_name)
mig=$(tf output -raw mig_name)

# 2. GKE.
status=$(gcloud container clusters list --project "$app" --filter "name=$gke" --format 'value(status)')
[ "$status" = RUNNING ] || fail "GKE $gke en estado '${status:-no encontrado}'"
echo "GKE $gke RUNNING"

# 3. Cloud SQL.
state=$(gcloud sql instances describe "$sql" --project "$data" --format 'value(state)')
[ "$state" = RUNNABLE ] || fail "Cloud SQL $sql en estado '$state'"
echo "Cloud SQL $sql RUNNABLE"

# 4. MIG: todas las VM creadas y sanas (autohealing) en a lo más 10 minutos.
region=$(gcloud compute instance-groups managed list --project "$app" --filter "name=$mig" --format 'value(region.basename())')
[ -n "$region" ] || fail "MIG $mig no encontrado"
gcloud compute instance-groups managed wait-until "$mig" --stable --region "$region" --project "$app" --timeout 600
echo "MIG $mig estable en $region"
