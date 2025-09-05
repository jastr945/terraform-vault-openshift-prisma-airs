output "vault_public_url" {
  value = hcp_vault_cluster.vault.vault_public_endpoint_url
}

output "admin_token" {
  value     = hcp_vault_cluster_admin_token.admin.token
  sensitive = true
}
