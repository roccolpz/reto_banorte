#!/usr/bin/env bash
# Prueba e2e de conectividad híbrida, después del apply de prod.
# Entra por IAP SSH a una VM del MIG de prod y comprueba, desde dentro de la VPC:
#   1. ping a la IP privada on-prem (por HA VPN y NCC),
#   2. curl HTTP a esa IP,
#   3. resolución DNS de un nombre de corp.acme.internal (zona de reenvío).
# Requiere gcloud autenticado con permiso de IAP TCP forwarding y compute.instances.osLogin.
#
# Uso:
#   PROJECT_ID=... MIG_NAME=... ONPREM_IP=192.168.10.10 ./connectivity.sh
# Variables:
#   PROJECT_ID        proyecto de la app de prod (salida app_project_id de 4-projects/envs/prod)
#   MIG_NAME          nombre del MIG (salida mig_name de 5-workloads/envs/prod)
#   REGION            región del MIG regional (por defecto us-central1)
#   ONPREM_IP         IP privada de la VM on-prem simulada (192.168.10.0/24)
#   ONPREM_HTTP_PORT  puerto HTTP on-prem (por defecto 80)
#   DNS_NAME          nombre a resolver (por defecto app.corp.acme.internal)
set -euo pipefail

: "${PROJECT_ID:?definir PROJECT_ID}"
: "${MIG_NAME:?definir MIG_NAME}"
: "${ONPREM_IP:?definir ONPREM_IP}"
REGION=${REGION:-us-central1}
ONPREM_HTTP_PORT=${ONPREM_HTTP_PORT:-80}
DNS_NAME=${DNS_NAME:-app.corp.acme.internal}

fail=0
check() {
  local label=$1
  shift
  if "$@"; then
    echo "OK    $label"
  else
    echo "FALLA $label"
    fail=1
  fi
}

# basename(): gcloud recorta la URL de instance según la versión, así que no se parsea a mano.
instance=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" \
  --project "$PROJECT_ID" --region "$REGION" --limit 1 --format 'value(instance.basename())')
[ -n "$instance" ] || {
  echo "El MIG $MIG_NAME no tiene instancias" >&2
  exit 1
}
zone=$(gcloud compute instances list --project "$PROJECT_ID" --filter "name=$instance" --format 'value(zone.basename())')
echo "VM de prueba: $instance ($zone)"

remote() {
  gcloud compute ssh "$instance" --project "$PROJECT_ID" --zone "$zone" \
    --tunnel-through-iap --quiet --command "$1"
}

check "ping a $ONPREM_IP" remote "ping -c 3 -W 2 $ONPREM_IP"
check "HTTP a $ONPREM_IP:$ONPREM_HTTP_PORT" remote "curl -fsS -m 5 -o /dev/null http://$ONPREM_IP:$ONPREM_HTTP_PORT/"
check "DNS $DNS_NAME" remote "getent hosts $DNS_NAME"

exit "$fail"
