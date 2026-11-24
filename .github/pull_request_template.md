## Qué cambia

<!-- Una o dos líneas: qué y por qué. -->

## Raíces afectadas

- [ ] 1-org
- [ ] 2-security
- [ ] 3-networks (hub / dev / qa / prod)
- [ ] 4-projects (dev / qa / prod)
- [ ] 5-workloads (dev / qa / prod)
- [ ] Solo módulos, políticas, CI o documentación

## Revisión

- [ ] Revisé el comentario del plan de cada raíz: no hay destrucciones inesperadas.
- [ ] Las políticas (conftest) pasan, o explico abajo por qué se cambia una política.
- [ ] Los recursos nuevos llevan las etiquetas `env`, `app`, `owner`, `cost_center`, `managed_by`.
- [ ] No agrego llaves de cuenta de servicio, IPs públicas ni secretos.
- [ ] Si cambia una salida que otra etapa lee por `terraform_remote_state`, actualicé `gcp-datacenter/docs/CONTRATO.md`.
- [ ] Si afecta prod, sé quién aprueba el environment `prod` después del merge.

## Notas para quien revisa

<!-- Riesgos, orden de apply, pasos manuales. -->
