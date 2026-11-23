# Etiquetas obligatorias (CONTRATO §4) en todo recurso google_* que acepte etiquetas.
package main

required_labels := {"env", "app", "owner", "cost_center", "managed_by"}

# terraform_labels incluye default_labels del provider; labels/resource_labels/user_labels son los del recurso.
label_fields := ["labels", "terraform_labels", "resource_labels", "user_labels"]

# Cloud SQL guarda las etiquetas en settings[0].user_labels.
label_source(rc) := rc.change.after.settings[0] if {
	rc.type == "google_sql_database_instance"
} else := rc.change.after

labelable(obj) if {
	some f in label_fields
	f in object.keys(obj)
}

has_label(obj, k) if {
	some f in label_fields
	is_object(obj[f])
	obj[f][k] != ""
}

deny contains msg if {
	some rc in resources
	startswith(rc.type, "google_")
	obj := label_source(rc)
	labelable(obj)
	missing := {k | some k in required_labels; not has_label(obj, k)}
	count(missing) > 0
	msg := sprintf("%s: faltan etiquetas obligatorias %v", [rc.address, sort(missing)])
}
