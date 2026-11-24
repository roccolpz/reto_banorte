terraform {
  backend "gcs" {
    prefix = "0-bootstrap"
  }
}
