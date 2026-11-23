# Utilidades compartidas por las políticas. Entrada: salida de `terraform show -json tfplan`.
package main

# Recursos gestionados que existirán después del apply (se excluyen los que solo se borran).
resources contains rc if {
	some rc in input.resource_changes
	rc.mode == "managed"
	rc.change.actions != ["delete"]
}

resources_of(t) := {rc | some rc in resources; rc.type == t}
