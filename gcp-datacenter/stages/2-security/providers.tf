# Access Context Manager exige proyecto de cuota: se usa el proyecto común de seguridad,
# donde opera la SA de 2-security (necesita accesscontextmanager.googleapis.com habilitada).
provider "google" {
  billing_project       = local.security_project_id
  user_project_override = true
}
