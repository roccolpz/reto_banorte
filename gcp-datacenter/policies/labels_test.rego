package main

test_labels_complete_ok if {
	clean(rc_create("google_kms_crypto_key.k", "google_kms_crypto_key", {"labels": ok_labels}))
}

test_labels_from_default_labels_ok if {
	clean(rc_create("google_kms_crypto_key.k", "google_kms_crypto_key", {"labels": null, "terraform_labels": ok_labels}))
}

test_labels_missing_owner_denied if {
	denies(rc_create("google_kms_crypto_key.k", "google_kms_crypto_key", {"labels": object.remove(ok_labels, ["owner"])}), "owner")
}

test_labels_null_denied if {
	denies(rc_create("google_kms_crypto_key.k", "google_kms_crypto_key", {"labels": null}), "faltan etiquetas")
}

test_gke_resource_labels_ok if {
	clean(rc_create("google_container_cluster.c", "google_container_cluster", {"resource_labels": ok_labels, "private_cluster_config": [{"enable_private_nodes": true}]}))
}

test_sql_user_labels_missing_denied if {
	after := {"settings": [{"user_labels": {"env": "dev"}, "ip_configuration": [{"ipv4_enabled": false}]}]}
	denies(rc_create("google_sql_database_instance.db", "google_sql_database_instance", after), "cost_center")
}

test_non_labelable_ignored if {
	clean(rc_create("google_compute_router.r", "google_compute_router", {"name": "acme-common-net-hub-router"}))
}
