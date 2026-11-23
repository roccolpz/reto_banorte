terraform {
  backend "gcs" {
    prefix = "5-workloads/qa"
  }
}
