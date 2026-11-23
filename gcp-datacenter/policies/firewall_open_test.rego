package main

test_firewall_iap_ok if {
	after := {"direction": "INGRESS", "allow": [{"protocol": "tcp", "ports": ["22"]}], "source_ranges": ["35.235.240.0/20"]}
	clean(rc_create("google_compute_firewall.iap", "google_compute_firewall", after))
}

test_firewall_open_ingress_denied if {
	after := {"direction": "INGRESS", "allow": [{"protocol": "tcp", "ports": ["22"]}], "source_ranges": ["0.0.0.0/0"]}
	denies(rc_create("google_compute_firewall.ssh", "google_compute_firewall", after), "0.0.0.0/0")
}

test_firewall_open_deny_rule_ok if {
	after := {"direction": "INGRESS", "allow": [], "deny": [{"protocol": "all"}], "source_ranges": ["0.0.0.0/0"]}
	clean(rc_create("google_compute_firewall.deny_all", "google_compute_firewall", after))
}

test_firewall_open_egress_ok if {
	after := {"direction": "EGRESS", "allow": [{"protocol": "tcp", "ports": ["443"]}], "destination_ranges": ["0.0.0.0/0"]}
	clean(rc_create("google_compute_firewall.egress", "google_compute_firewall", after))
}

test_hierarchical_rule_open_denied if {
	after := {"action": "allow", "direction": "INGRESS", "match": [{"src_ip_ranges": ["0.0.0.0/0"]}]}
	denies(rc_create("google_compute_firewall_policy_rule.r", "google_compute_firewall_policy_rule", after), "regla de ingreso")
}

test_hierarchical_rule_deny_ok if {
	after := {"action": "deny", "direction": "INGRESS", "match": [{"src_ip_ranges": ["0.0.0.0/0"]}]}
	clean(rc_create("google_compute_firewall_policy_rule.r", "google_compute_firewall_policy_rule", after))
}
