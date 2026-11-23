# Configuración de tflint para módulos y etapas. En CI se usa con ruta absoluta:
#   tflint --init --config "$PWD/.tflint.hcl"
#   tflint --chdir <dir> --config "$PWD/.tflint.hcl"

config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Versión fijada del ruleset de Google; actualizar por PR.
plugin "google" {
  enabled = true
  version = "0.41.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
