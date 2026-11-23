# VM sin IP externa (instancias y plantillas de MIG).
package main

vm_types := {
	"google_compute_instance",
	"google_compute_instance_template",
	"google_compute_region_instance_template",
}

deny contains msg if {
	some rc in resources
	rc.type in vm_types
	some nic in rc.change.after.network_interface
	count(object.get(nic, "access_config", [])) > 0
	msg := sprintf("%s: la VM no debe tener IP externa (access_config)", [rc.address])
}
