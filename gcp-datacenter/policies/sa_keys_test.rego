package main

test_service_account_ok if {
	clean(rc_create("google_service_account.sa", "google_service_account", {"account_id": "sa-tf-plan"}))
}

test_service_account_key_denied if {
	denies(rc_create("google_service_account_key.k", "google_service_account_key", {"service_account_id": "sa-tf-plan"}), "llaves de cuenta de servicio")
}
