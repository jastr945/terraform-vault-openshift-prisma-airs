provider "hcp" {
  client_id     = var.hcp_client_id
  client_secret = var.hcp_client_secret
}

resource "hcp_hvn" "main" {
  project_id     = var.hcp_project_id
  hvn_id         = var.hvn_id
  region         = var.hvn_region
  cidr_block     = var.hvn_cidr
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
  alias   = "admin"
  address = hcp_vault_cluster.vault.vault_public_endpoint_url
  token   = hcp_vault_cluster_admin_token.admin.token
}

resource "vault_namespace" "trusted_ai_secrets" {
  path     = var.vault_namespace
  provider = vault.admin
}

resource "vault_policy" "full_ns_access" {
  provider = vault.admin
  namespace = vault_namespace.trusted_ai_secrets.path
  name     = "trusted-ai-admin"

  policy = <<EOF
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Required for CLI login
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
}

resource "vault_token" "namespace_admin" {
  provider  = vault.admin
  namespace = vault_namespace.trusted_ai_secrets.path

  policies    = ["trusted-ai-admin"]
  display_name = "trusted-ai-namespace-admin"
  period       = "720h"
  renewable    = true
  no_parent    = true
}