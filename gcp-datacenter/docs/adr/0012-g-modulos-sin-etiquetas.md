# ADR 0012-g: los módulos sin recursos etiquetables no reciben `labels`

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

El contrato pide que cada módulo acepte `var.labels` con `app`, `env`, `owner` y `cost_center`. Algunos recursos
de GCP no tienen etiquetas: el perímetro de VPC Service Controls, sus reglas de ingreso y egreso, y las reglas
de firewall. `modules/vpc-sc` no tiene `var.labels`; `modules/firewall` sí la recibe y la valida, pero no puede
usarla.

## Decisión

- Un módulo cuyos recursos no admiten etiquetas no declara `var.labels`. `modules/vpc-sc` queda así.
- Las etiquetas del entorno siguen en los proyectos que contienen esos recursos, así que el costo se atribuye
  igual.
- `modules/firewall` pertenece a la pista de redes; aplicar esta regla ahí (quitar la variable) le corresponde.

## Alternativas descartadas

- **Agregar `var.labels` a vpc-sc sin usarla**: una variable que no hace nada confunde a quien llama.

## Consecuencias

- La verificación del contrato debe excluir los módulos listados en este ADR.
- Si GCP agrega etiquetas a estos recursos, el módulo recibe la variable en ese momento.
