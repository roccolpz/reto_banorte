# ADR 0013-g: egreso de VPC-SC al proyecto de respaldo y accesores de secretos por entorno

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

Fase 3 pide reglas de egreso explícitas en los perímetros y que los secretos solo los lean las identidades
autorizadas. Antes, 2-security no pasaba reglas de egreso y los secretos no tenían ningún accesor. Las SAs de
carga (`gke_nodes`, `app_workload`, `vm`) las crea 4-projects de cada entorno, que corre después de 2-security.

## Decisión

- 2-security lee la salida `service_accounts` del estado `4-projects/<env>` de los tres entornos. Lista el
  prefijo antes de leerlo, igual que en el ADR 0007-f, para que la primera corrida no falle.
- `app_workload` y `vm` de cada entorno reciben `roles/secretmanager.secretAccessor` solo sobre los secretos de
  su entorno. `gke_nodes` no lo recibe: los pods leen secretos con su propia identidad (`app_workload`).
- Cada perímetro tiene una sola regla de egreso: `app_workload` del entorno puede usar `storage.googleapis.com`
  en el proyecto común `backup` (número leído de la salida `common_project_numbers` de 1-org). Es el destino de
  los respaldos fuera del perímetro.
- `vpc_sc_enforce` pasa a ser un mapa por entorno (`dev`, `qa`, `prod`) y 2-security lo publica como salida para
  4-projects.

## Alternativas descartadas

- **Accesores en 4-projects**: la SA de 4-projects necesitaría IAM sobre los secretos del proyecto `security`,
  que comparte con los demás entornos.
- **Meter el proyecto de respaldo en cada perímetro**: un proyecto solo puede estar en un perímetro normal.

## Consecuencias

- Tras crear 4-projects de cada entorno hay que volver a correr 2-security para que se creen los accesores y el
  egreso. Hasta entonces las cargas no leen secretos.
- Pregunta abierta: si el respaldo de Cloud SQL o de GKE usa otra identidad o servicio, la regla de egreso debe
  incluirla. Hoy solo cubre escrituras a GCS de `app_workload`.
