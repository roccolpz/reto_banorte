# ADR 0008-i: de dónde sale la imagen endurecida de las VM del MIG

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

El reto pide VM endurecidas. El módulo `compute-mig` ya aplica lo que Terraform controla en la plantilla:
Shielded VM (secure boot, vTPM, integrity monitoring), OS Login, bloqueo de llaves SSH del proyecto, puerto serie
apagado, sin IP externa y una SA dedicada. Lo que falta es el endurecimiento del sistema operativo (perfil CIS,
paquetes mínimos, agentes de monitoreo). Eso vive en la imagen, no en la plantilla.

## Decisión

- El módulo recibe `image_family` con la forma `projects/<proyecto>/global/images/family/<familia>`. Usar una
  familia, y no una imagen fija, hace que cada nueva plantilla tome la última imagen publicada en esa familia.
- La imagen endurecida se construye fuera de este repositorio de Terraform. Un pipeline de imágenes (por ejemplo
  Packer con el perfil CIS Level 1, o una imagen CIS publicada en Marketplace) la publica en una familia de un
  proyecto de imágenes de `common`. Las VM del MIG la usan con `image_family`.
- Mientras ese pipeline no exista, el default es `projects/debian-cloud/global/images/family/debian-12`. Esa imagen
  pública soporta Shielded VM, pero no trae endurecimiento CIS.
- Para usar una imagen de otro proyecto, la SA de las VM y el agente de Compute del proyecto de app necesitan
  `roles/compute.imageUser` en el proyecto de imágenes.

## Alternativas descartadas

- **Construir la imagen con Terraform (`google_compute_image` desde un disco)**: mezcla el ciclo de vida de la
  imagen con el de la infraestructura y no aplica un perfil CIS por sí sola.
- **Endurecer en el arranque con `startup_script`**: cada VM nueva queda expuesta mientras corre el script, y un
  fallo deja VM a medio endurecer dentro del MIG.

## Consecuencias

- La entrega arranca con Debian 12 público. Endurecer el sistema operativo exige crear el proyecto de imágenes y el
  pipeline, y luego cambiar `image_family` en `5-workloads`. Ninguno de los dos está en esta entrega.
- El cambio de familia produce una plantilla nueva, y el MIG reemplaza las VM con su política de actualización
  `PROACTIVE` sin bajar capacidad (`max_unavailable_fixed = 0`).
