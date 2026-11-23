# Ninguna regla de firewall permite ingreso desde 0.0.0.0/0 o ::/0.
package main

open_ranges := {"0.0.0.0/0", "::/0"}

# Firewall de VPC: si no se indica dirección, GCP usa INGRESS.
deny contains msg if {
	some rc in resources_of("google_compute_firewall")
	after := rc.change.after
	object.get(after, "direction", "INGRESS") in {"INGRESS", null}
	count(object.get(after, "allow", [])) > 0
	some r in object.get(after, "source_ranges", [])
	r in open_ranges
	msg := sprintf("%s: firewall de ingreso permite %s", [rc.address, r])
}

# Firewall jerárquico (organización/carpeta) y de red.
policy_rule_types := {"google_compute_firewall_policy_rule", "google_compute_network_firewall_policy_rule"}

deny contains msg if {
	some rc in resources
	rc.type in policy_rule_types
	after := rc.change.after
	after.action == "allow"
	after.direction == "INGRESS"
	some m in after.match
	some r in object.get(m, "src_ip_ranges", [])
	r in open_ranges
	msg := sprintf("%s: regla de ingreso permite %s", [rc.address, r])
}
