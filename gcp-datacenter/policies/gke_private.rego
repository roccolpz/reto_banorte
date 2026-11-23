# GKE con nodos privados.
package main

gke_private_nodes(after) if {
	after.private_cluster_config[0].enable_private_nodes == true
}

deny contains msg if {
	some rc in resources_of("google_container_cluster")
	not gke_private_nodes(rc.change.after)
	msg := sprintf("%s: GKE debe usar nodos privados (private_cluster_config.enable_private_nodes)", [rc.address])
}
