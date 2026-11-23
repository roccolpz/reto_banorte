# ADR 0006-e: VPC Service Controls primero en modo dry-run

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

VPC Service Controls crea un perímetro por entorno alrededor de las API de datos (Storage, Cloud SQL, KMS, Secret
Manager y otras). Un perímetro aplicado (enforced) con una regla de ingreso mal escrita bloquea al propio pipeline:
Terraform deja de poder leer o escribir recursos dentro del perímetro y el siguiente apply falla, incluido el que
corregiría la regla.

## Decisión

- `2-security` crea los perímetros con `var.vpc_sc_enforce = false` por default: la configuración va en `spec` con
  `use_explicit_dry_run_spec = true`, y las violaciones solo se registran en los logs de auditoría.
- Los perímetros incluyen reglas de ingreso explícitas para las SA de las etapas.
- Se activa el modo aplicado por entorno (primero dev, luego qa y al final prod) solo cuando los logs de dry-run del
  entorno no muestran violaciones legítimas durante al menos una semana.
- Para activarlo se cambia `vpc_sc_enforce` a `true` en el entorno y se aplica por el pipeline normal.

## Alternativas descartadas

- **Aplicar desde el primer día**: alto riesgo de bloquear el pipeline y las cargas en la primera entrega.
- **No usar VPC-SC**: deja abierta la exfiltración de datos con credenciales robadas; la especificación lo pide.

## Consecuencias

- En la entrega, los perímetros existen y registran, pero todavía no bloquean.
- Antes de activar el modo aplicado se revisan los registros con la consulta del runbook de operación y se ajustan las
  reglas de ingreso y egreso.
- Si el modo aplicado bloquea algo, el retroceso es un PR que vuelve `vpc_sc_enforce` a `false`; si el pipeline mismo
  quedó bloqueado, un administrador de Access Context Manager lo cambia desde la consola.
