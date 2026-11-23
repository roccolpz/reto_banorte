locals {
  env    = "dev"
  labels = merge(var.labels, { env = local.env, managed_by = "terraform" })
}

# Toda la lógica vive en el módulo compartido; los entornos solo cambian local.env.
module "env" {
  source = "../../modules/env"

  env          = local.env
  state_bucket = var.state_bucket
  prefix       = var.prefix
  labels       = local.labels
}
