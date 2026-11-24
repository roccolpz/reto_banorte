# Módulos congelados del legado

Copia de `modules/gke`, `modules/project-factory` y `modules/vpc-sc` en el commit 9a54d6c.
`test-orchestration` tiene estado local con recursos vivos. Las versiones nuevas de esos módulos
cambian nombres, tipos de máquina y scopes del node pool, y un apply reemplazaría el clúster.
Con esta copia el plan del legado no cambia. No editar: se borra junto con `test-orchestration`.
