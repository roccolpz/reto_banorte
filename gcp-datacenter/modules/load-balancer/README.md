# Módulo `load-balancer`

Balanceador de aplicaciones externo global (`EXTERNAL_MANAGED`) con frontend HTTPS, certificado administrado por
Google, política TLS `MODERN` (TLS 1.2 mínimo) y Cloud Armor delante de un servicio de Cloud Run (NEG serverless).

Cloud Armor aplica las reglas WAF preconfiguradas de OWASP (`sqli`, `xss`, `lfi`, `rce`, versión `v33-stable`) y
`cve-canary` (Log4j); todas responden `403`. El resto del tráfico se permite.

Sin `domain`, el certificado se emite para `<ip>.nip.io`, que resuelve a la IP del balanceador: no hace falta una zona
DNS pública. El certificado tarda de 15 a 60 minutos en quedar `ACTIVE` después del primer apply.

## Uso

```hcl
module "load_balancer" {
  source            = "../../modules/load-balancer"
  name              = "acme-prod-app-lb"
  project_id        = "acme-prod-app-xxxx"
  cloud_run_service = module.cloud_run.service_name
  labels            = { env = "prod", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform" }
}
```

Ejemplo completo en [examples/basic](examples/basic/main.tf).

Comprobación de Cloud Armor:

```sh
curl -s -o /dev/null -w '%{http_code}\n' "https://<ip>.nip.io/"                     # 200
curl -s -o /dev/null -w '%{http_code}\n' "https://<ip>.nip.io/?id=1%27%20OR%20%271%27=%271"  # 403
```

## Entradas

| Nombre | Descripción | Tipo | Default | Requerido |
|---|---|---|---|:-:|
| name | Prefijo de los recursos. | `string` | n/a | sí |
| project_id | Proyecto del balanceador. | `string` | n/a | sí |
| region | Región del servicio de Cloud Run. | `string` | `"us-central1"` | no |
| cloud_run_service | Servicio de Cloud Run de backend. | `string` | n/a | sí |
| domain | Dominio del certificado. `null`: `<ip>.nip.io`. | `string` | `null` | no |
| waf_sensitivity | Sensibilidad de las reglas WAF (1 a 4). | `number` | `1` | no |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | sí |

## Salidas

| Nombre | Descripción |
|---|---|
| ip_address | IP pública. |
| domain | Dominio del certificado. |
| security_policy_name | Política de Cloud Armor. |

## Pruebas

```sh
terraform init -backend=false && terraform test
```
