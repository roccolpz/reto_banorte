output "bucket_name" {
  description = "Nombre del bucket."
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "URL gs:// del bucket."
  value       = google_storage_bucket.this.url
}
