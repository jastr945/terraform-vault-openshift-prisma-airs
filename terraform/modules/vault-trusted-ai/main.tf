provider "vault" {
  alias     = "trusted-ai-secrets"
  address   = var.vault_addr
  token     = var.trusted_ai_namespace_token
  namespace = var.trusted_ai_namespace_path
}

resource "vault_mount" "kvv2" {
  provider    = vault.trusted-ai-secrets
  path        = "kv"
  type        = "kv-v2"
  description = "Secrets for chatbot"
}

resource "vault_kv_secret_v2" "gemini_key" {
  provider = vault.trusted-ai-secrets
  mount    = vault_mount.kvv2.path
  name     = "chatbot"

  data_json = jsonencode({
    GEMINI_API_KEY          = var.gemini_api_key
    PRISMA_AIRS_API_KEY     = var.prisma_airs_api_key
    PRISMA_AIRS_PROFILE     = var.prisma_airs_profile
    CHATBOT_WELCOME_MESSAGE = "Hello! I am your AI assistant, here to help you with your queries."
    AWS_DB_HOST             = var.db_host
  })
}

/* Kubernetes Auth Method Configuration */

resource "vault_auth_backend" "kubernetes" {
  provider    = vault.trusted-ai-secrets
  type        = "kubernetes"
  path        = "kubernetes"
  description = "Enables the Kubernetes authentication method in Vault"
}

resource "vault_policy" "ai_chatbot_policy" {
  provider = vault.trusted-ai-secrets
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

path "postgres/creds/*" {
  capabilities = ["read", "list"]
}

path "sys/leases/renew" {
  capabilities = ["update"]
}

path "sys/leases/revoke" {
  capabilities = ["update"]
}

path "auth/kubernetes/login" {
  capabilities = ["create", "read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "my_app_role" {
  provider                         = vault.trusted-ai-secrets
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "ai-chatbot-role"
  bound_service_account_names      = ["chatbot"]    # to be built in k8s-vso module
  bound_service_account_namespaces = ["trusted-ai"] # to be built in k8s-vso module
  token_policies                   = [vault_policy.ai_chatbot_policy.name]
  token_ttl                        = 3600 # 1 hour
  token_type                       = "default"
  audience                         = "https://kubernetes.default.svc"
}
/* Dynamic Database Credential Configuration */

resource "vault_mount" "db" {
  provider = vault.trusted-ai-secrets
  path     = "postgres"
  type     = "database"
}

resource "vault_database_secret_backend_connection" "postgres" {
  provider      = vault.trusted-ai-secrets
  backend       = vault_mount.db.path
  name          = "postgresql"
  allowed_roles = ["ai-agent-app"]

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@${var.db_host}:${var.db_port}/${var.db_name}?sslmode=require"
    username       = var.db_username
    password       = var.db_password
  }
}

resource "vault_database_secret_backend_role" "ai_agent_app" {
  provider = vault.trusted-ai-secrets
  backend  = vault_mount.db.path
  name     = "ai-agent-app"
  db_name  = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT USAGE ON SCHEMA terraform_remote_state TO \"{{name}}\";",
    "GRANT SELECT ON ALL TABLES IN SCHEMA terraform_remote_state TO \"{{name}}\";"
  ]
  default_ttl = "30"
  max_ttl     = "60"
}