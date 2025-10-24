output "vault_public_url" {
  value = hcp_vault_cluster.vault.vault_public_endpoint_url
}

output "vault_admin_token" {
  value     = hcp_vault_cluster_admin_token.admin.token
  sensitive = true
  description = "The HCP Vault cluster admin token"
}

output "trusted_ai_namespace_path" {
  value = vault_namespace.trusted_ai_secrets.id
} 

output "trusted_ai_namespace_token" {
  value     = vault_token.namespace_admin.client_token
  sensitive = true
}