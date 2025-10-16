module "vault" {
  source              = "./modules/vault"
  hcp_client_id       = var.hcp_client_id
  hcp_client_secret   = var.hcp_client_secret
  hcp_project_id      = var.hcp_project_id
  hvn_id              = var.hvn_id
  hvn_region          = var.hvn_region
  hvn_cidr            = var.hvn_cidr
  hvn_cloud_provider  = var.hvn_cloud_provider
  vault_cluster_id    = var.vault_cluster_id
  vault_namespace     = var.vault_namespace
  gemini_api_key      = var.gemini_api_key
  prisma_airs_api_key = var.prisma_airs_api_key
  prisma_airs_profile = var.prisma_airs_profile
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  db_port             = var.db_port
  db_host             = module.postgres.rds_hostname
}

module "postgres" {
  source      = "./modules/postgres"
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}