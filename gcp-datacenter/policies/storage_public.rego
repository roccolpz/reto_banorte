# Sin buckets públicos: prevención de acceso público forzada y ningún binding IAM a allUsers/allAuthenticatedUsers.
package main

public_principals := {"allUsers", "allAuthenticatedUsers"}

deny contains msg if {
	some rc in resources_of("google_storage_bucket")
	object.get(rc.change.after, "public_access_prevention", "") != "enforced"
	msg := sprintf("%s: public_access_prevention debe ser \"enforced\"", [rc.address])
}

# *_iam_member
deny contains msg if {
	some rc in resources
	endswith(rc.type, "_iam_member")
	rc.change.after.member in public_principals
	msg := sprintf("%s: IAM público (%s) no permitido", [rc.address, rc.change.after.member])
}

# *_iam_binding
deny contains msg if {
	some rc in resources
	endswith(rc.type, "_iam_binding")
	some m in rc.change.after.members
	m in public_principals
	msg := sprintf("%s: IAM público (%s) no permitido", [rc.address, m])
}

# *_iam_policy: policy_data es un JSON en texto.
deny contains msg if {
	some rc in resources
	endswith(rc.type, "_iam_policy")
	some p in public_principals
	contains(rc.change.after.policy_data, p)
	msg := sprintf("%s: IAM público (%s) no permitido", [rc.address, p])
}
