# ADR 0015-j: GKE para contenedores y grupos de VM para lo que no se puede contener

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

Fase 3 muestra tres opciones de cómputo por entorno: GKE, Compute Engine y Cloud Run. Cloud Run queda fuera de
esta entrega (ADR 0001). Hay que decidir qué carga va a cada plataforma y si se despliegan las dos.

## Decisión

Se despliegan las dos en cada entorno (5-workloads), cada una para un tipo de carga:

- **GKE** (`modules/gke`) es la plataforma por defecto para las aplicaciones en contenedores: clúster privado,
  Workload Identity, nodos Shielded con la etiqueta segura `gke-nodes`. En prod es regional y tiene un clúster de
  DR en us-east4 (master `172.16.31.0/28`).
- **Grupo de instancias administrado** (`modules/compute-mig`) para software que no se puede contener: productos
  de terceros con licencia por VM, agentes que necesitan el sistema operativo completo o cargas heredadas. Usa
  una familia de imagen endurecida, autoescalado y autohealing, y la etiqueta segura `vm`.

Una carga nueva va a GKE salvo que tenga una de esas restricciones; la excepción se anota en el PR.

## Alternativas descartadas

- **Solo GKE**: deja sin lugar al software de terceros que no se distribuye en contenedores.
- **Solo VM**: cada aplicación necesitaría su propia imagen, escalado y despliegue; GKE resuelve eso una vez
  para todas.
- **GKE Autopilot**: menos operación, pero no permite fijar la cuenta de servicio, los pools ni el tamaño de
  nodo por entorno (`gke_node_pools`) como se diseñó. Se puede revisar en la siguiente fase.
- **Cloud Run**: fuera de alcance (ADR 0001).

## Consecuencias

- Hay dos plataformas que operar y endurecer: la imagen de las VM y la versión de GKE.
- El firewall distingue las dos por etiqueta segura (`gke-nodes`, `vm`), así que una regla puede abrir una sin
  la otra.
