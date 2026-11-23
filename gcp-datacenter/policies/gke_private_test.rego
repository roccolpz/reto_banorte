package main

test_gke_private_nodes_ok if {
	after := {"resource_labels": ok_labels, "private_cluster_config": [{"enable_private_nodes": true, "master_ipv4_cidr_block": "172.16.30.0/28"}]}
	clean(rc_create("google_container_cluster.c", "google_container_cluster", after))
}

test_gke_public_nodes_denied if {
	after := {"resource_labels": ok_labels, "private_cluster_config": [{"enable_private_nodes": false}]}
	denies(rc_create("google_container_cluster.c", "google_container_cluster", after), "nodos privados")
}

test_gke_without_private_config_denied if {
	after := {"resource_labels": ok_labels, "private_cluster_config": []}
	denies(rc_create("google_container_cluster.c", "google_container_cluster", after), "nodos privados")
}
