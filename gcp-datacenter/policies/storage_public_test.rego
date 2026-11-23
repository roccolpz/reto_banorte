package main

test_bucket_enforced_ok if {
	clean(rc_create("google_storage_bucket.b", "google_storage_bucket", {"public_access_prevention": "enforced", "labels": ok_labels}))
}

test_bucket_inherited_denied if {
	denies(rc_create("google_storage_bucket.b", "google_storage_bucket", {"public_access_prevention": "inherited", "labels": ok_labels}), "public_access_prevention")
}

test_bucket_unset_denied if {
	denies(rc_create("google_storage_bucket.b", "google_storage_bucket", {"labels": ok_labels}), "public_access_prevention")
}

test_iam_member_private_ok if {
	clean(rc_create("google_storage_bucket_iam_member.m", "google_storage_bucket_iam_member", {"member": "serviceAccount:sa@p.iam.gserviceaccount.com", "role": "roles/storage.objectViewer"}))
}

test_iam_member_all_users_denied if {
	denies(rc_create("google_storage_bucket_iam_member.m", "google_storage_bucket_iam_member", {"member": "allUsers", "role": "roles/storage.objectViewer"}), "IAM público")
}

test_iam_binding_all_authenticated_denied if {
	denies(rc_create("google_project_iam_binding.b", "google_project_iam_binding", {"members": ["user:a@acme.com", "allAuthenticatedUsers"], "role": "roles/viewer"}), "allAuthenticatedUsers")
}

test_iam_policy_all_users_denied if {
	denies(rc_create("google_storage_bucket_iam_policy.p", "google_storage_bucket_iam_policy", {"policy_data": "{\"bindings\":[{\"members\":[\"allUsers\"],\"role\":\"roles/storage.objectViewer\"}]}"}), "allUsers")
}
