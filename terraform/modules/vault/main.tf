provider "hcp" {
  client_id     = var.hcp_client_id
  client_secret = var.hcp_client_secret
}

resource "hcp_hvn" "main" {
  project_id = var.hcp_project_id
  hvn_id     = var.hvn_id
  region     = var.hvn_region
  cidr_block = var.hvn_cidr
  cloud_provider = var.hvn_cloud_provider
}

resource "hcp_vault_cluster" "vault" {
  project_id      = var.hcp_project_id
  cluster_id      = var.vault_cluster_id
  hvn_id          = hcp_hvn.main.hvn_id
  tier            = "dev"
  public_endpoint = true
}

resource "hcp_vault_cluster_admin_token" "admin" {
  cluster_id = hcp_vault_cluster.vault.cluster_id
  project_id = var.hcp_project_id
  depends_on = [hcp_vault_cluster.vault]
}

provider "vault" {
  address = hcp_vault_cluster.vault.vault_public_endpoint_url
  token   = hcp_vault_cluster_admin_token.admin.token
}

resource "vault_mount" "kvv2" {
  path        = "kv"
  type        = "kv-v2"
  description = "Secrets for chatbot"
}

resource "vault_kv_secret_v2" "gemini_key" {
  mount = vault_mount.kvv2.path
  name  = "chatbot"

  data_json = jsonencode({
    GEMINI_API_KEY = var.gemini_api_key
    PRISMA_AIRS_API_KEY = var.prisma_airs_api_key
    PRISMA_AIRS_PROFILE = var.prisma_airs_profile
  })
}
