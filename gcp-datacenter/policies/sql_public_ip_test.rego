package main

test_sql_private_ok if {
	after := {"settings": [{"user_labels": ok_labels, "ip_configuration": [{"ipv4_enabled": false, "private_network": "projects/p/global/networks/acme-prod-net-vpc"}]}]}
	clean(rc_create("google_sql_database_instance.db", "google_sql_database_instance", after))
}

test_sql_public_ip_denied if {
	after := {"settings": [{"user_labels": ok_labels, "ip_configuration": [{"ipv4_enabled": true}]}]}
	denies(rc_create("google_sql_database_instance.db", "google_sql_database_instance", after), "ipv4_enabled")
}

test_sql_without_ip_configuration_denied if {
	after := {"settings": [{"user_labels": ok_labels, "ip_configuration": []}]}
	denies(rc_create("google_sql_database_instance.db", "google_sql_database_instance", after), "ipv4_enabled")
}
