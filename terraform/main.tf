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
  vault_namespace = var.vault_namespace
  gemini_api_key      = var.gemini_api_key
  prisma_airs_api_key = var.prisma_airs_api_key
  prisma_airs_profile = var.prisma_airs_profile
}

module "openshift-vso" {
  source            = "./modules/openshift-vso"
  openshift_host    = var.openshift_host
  openshift_token   = var.openshift_token
  openshift_namespace         = var.openshift_namespace
  vault_addr        = module.vault.vault_public_url
  vault_admin_token = module.vault.admin_token
  vault_namespace = var.vault_namespace
  vault_transit_mount_path = module.vault.vault_transit_mount_path
  vault_transit_key_name = module.vault.vault_transit_key_name
  app_name = var.app_name
  image             = var.app_image
}
