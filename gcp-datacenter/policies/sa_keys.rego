# Sin llaves JSON de cuentas de servicio; el pipeline usa Workload Identity Federation.
package main

deny contains msg if {
	some rc in resources_of("google_service_account_key")
	msg := sprintf("%s: llaves de cuenta de servicio prohibidas; usar Workload Identity Federation", [rc.address])
}
