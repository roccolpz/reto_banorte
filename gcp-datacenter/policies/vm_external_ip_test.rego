package main

test_vm_internal_only_ok if {
	after := {"labels": ok_labels, "network_interface": [{"subnetwork": "acme-prod-net-app-usc1", "access_config": []}]}
	clean(rc_create("google_compute_instance_template.t", "google_compute_instance_template", after))
}

test_vm_external_ip_denied if {
	after := {"labels": ok_labels, "network_interface": [{"subnetwork": "acme-prod-net-app-usc1", "access_config": [{"nat_ip": null}]}]}
	denies(rc_create("google_compute_instance.vm", "google_compute_instance", after), "IP externa")
}
