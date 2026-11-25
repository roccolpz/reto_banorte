# ADR 0024: versionado semántico de módulos con tags de git

- Estado: aceptada
- Fecha: 2026-11-24

## Contexto

La especificación (Gobierno) pide módulos versionados con tags del tipo `modules/gke/v1.2.0`. Las etapas llaman a los
módulos por ruta relativa (`../../modules/gke`), así que hoy todas usan la versión del mismo commit.

## Decisión

- Cada módulo de `gcp-datacenter/modules/` se versiona con un tag anotado `modules/<nombre>/vX.Y.Z` sobre `main`.
- La primera versión de cada módulo existente es `v1.0.0`, sobre el merge que agrega este ADR.
- Mayor: cambia o quita una variable o salida, o un cambio fuerza recrear recursos. Menor: variable u salida nueva
  con default. Parche: corrección sin cambio de interfaz.
- Las etapas siguen usando rutas relativas: el monorepo se despliega desde un solo commit y el tag marca qué versión de
  cada módulo se liberó. Un consumidor externo usaría
  `source = "git::https://github.com/roccolpz/reto_banorte.git//gcp-datacenter/modules/gke?ref=modules/gke/v1.0.0"`.

Crear los tags:

```sh
git switch main && git pull
for m in gcp-datacenter/modules/*/; do
  n=$(basename "$m"); [ "$n" = network-host ] && continue   # legado (ver .checkov.yaml)
  git tag -a "modules/$n/v1.0.0" -m "modules/$n v1.0.0"
done
git push origin --tags
```

## Consecuencias

- Quien cambia un módulo sube su versión en un tag después del merge; el PR dice qué tipo de cambio es.
- `network-host` (legado) no se versiona.
