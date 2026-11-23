output "keyring_id" {
  description = "ID del keyring: projects/<p>/locations/<r>/keyRings/<nombre>."
  value       = google_kms_key_ring.this.id
}

output "key_ids" {
  description = "Mapa propósito → ID de la llave (projects/.../cryptoKeys/<propósito>)."
  value       = { for k, v in google_kms_crypto_key.keys : k => v.id }
}
