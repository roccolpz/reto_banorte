# Runbook: acceso de emergencia (break_glass)

Cuándo: hay un incidente declarado y el pipeline no puede corregirlo. Por ejemplo, WIF o una SA de etapa están
rotos, una org policy bloquea el propio pipeline, o hay que contener un compromiso ya.
No es para: cambios urgentes sin incidente. Esos van por pull request.

Qué da: el grupo `break_glass` tiene `organizationAdmin`, `folderAdmin` y `orgpolicy.policyAdmin` en la
organización (ADR 0009-g). Los demás grupos humanos solo leen. Fuera de un incidente el grupo no tiene miembros.

## 1. Pedir y aprobar

- Quien atiende el incidente pide el acceso en el canal del incidente: quién, por qué y qué va a hacer.
- Lo aprueba un miembro de `gcp-org-admins` distinto del solicitante. Anota en el incidente quién aprobó y la hora.

## 2. Dar el acceso

Un administrador de Cloud Identity agrega a la persona a `break_glass` en la consola de administración
(Directory > Groups > break_glass > Add members), con su cuenta nominal, nunca una compartida.

El alta queda en el registro de auditoría de Grupos de la consola de administración. Las acciones posteriores
quedan en los Admin Activity audit logs de la organización, que el sink de 1-org guarda con retención bloqueada.

## 3. Trabajar

- Haz solo lo anotado en el paso 1. Anota cada comando o cambio de consola en el incidente.
- Si arreglas el pipeline, vuelve a él en cuanto funcione y termina por pull request.

## 4. Retirar el acceso

En cuanto se cierre la acción, y a más tardar al cerrar el incidente:

1. Quita a la persona de `break_glass`.
2. Comprueba que el grupo quedó vacío.
3. Corre el workflow `drift`. Cada diferencia es un cambio manual del paso 3: llévalo al código por pull request,
   o reviértelo con un apply (ver `drift-response.md`).

## 5. Revisar

En la revisión del incidente, compara las acciones anotadas con los Admin Activity audit logs de la persona en ese
periodo:

```bash
gcloud logging read \
  'protoPayload.authenticationInfo.principalEmail="<correo>" AND logName:"cloudaudit.googleapis.com%2Factivity"' \
  --organization=<ORG_ID> --freshness=2d
```

Cualquier acción no anotada se investiga como parte del incidente.
