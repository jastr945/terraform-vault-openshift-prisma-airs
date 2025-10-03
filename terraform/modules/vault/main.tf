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
  namespace = var.vault_namespace
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

/* Kubernetes Auth Method Configuration */

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
  description = "Enables the Kubernetes authentication method in Vault"
}

resource "vault_policy" "ai_chatbot_policy" {
  name     = "ai-chatbot-policy"
  policy   = <<EOT
# Allows to read K/V secrets 
path "kv/data/chatbot" {
  capabilities = ["read", "list", "subscribe"]
  subscribe_event_types = ["*"]
}

# Allows reading K/V secret versions and metadata
path "kv/metadata/chatbot" {
  capabilities = ["list", "read"]
}

path "sys/events/subscribe/kv*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "my_app_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "ai-chatbot-role"
  bound_service_account_names      = ["chatbot"] # to be built in k8s-vso module
  bound_service_account_namespaces = ["ai-chatbot"] # to be built in k8s-vso module
  token_policies                   = [vault_policy.ai_chatbot_policy.name]
  token_ttl                        = 3600      # 1 hour
  token_type                       = "default"
  audience                         = "https://kubernetes.default.svc"
}