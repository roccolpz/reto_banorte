# Cloud SQL solo con IP privada.
package main

sql_private_only(after) if {
	after.settings[0].ip_configuration[0].ipv4_enabled == false
}

deny contains msg if {
	some rc in resources_of("google_sql_database_instance")
	not sql_private_only(rc.change.after)
	msg := sprintf("%s: Cloud SQL debe tener ip_configuration.ipv4_enabled = false", [rc.address])
}
