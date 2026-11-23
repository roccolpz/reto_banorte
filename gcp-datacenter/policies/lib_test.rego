# Utilidades para las pruebas (`conftest verify`).
package main

ok_labels := {"env": "dev", "app": "lz", "owner": "plataforma", "cost_center": "TI-001", "managed_by": "terraform"}

rc_create(addr, t, after) := {"address": addr, "mode": "managed", "type": t, "change": {"actions": ["create"], "after": after}}

# El recurso, solo en el plan, produce un deny que contiene `needle`.
denies(rc, needle) if {
	inp := {"resource_changes": [rc]}
	msgs := deny with input as inp
	some m in msgs
	contains(m, needle)
}

# El recurso, solo en el plan, no produce ningún deny.
clean(rc) if {
	inp := {"resource_changes": [rc]}
	msgs := deny with input as inp
	count(msgs) == 0
}

test_delete_only_is_ignored if {
	rc := {"address": "google_service_account_key.k", "mode": "managed", "type": "google_service_account_key", "change": {"actions": ["delete"], "after": null}}
	clean(rc)
}
