output "vault_public_url" {
  value = hcp_vault_cluster.vault.vault_public_endpoint_url
}

output "admin_token" {
  value     = hcp_vault_cluster_admin_token.admin.token
  sensitive = true
}

output "vault_transit_mount_path" {
  value = vault_mount.transit.path
}

output "vault_transit_key_name" {
  value = vault_transit_secret_backend_key.transit.name
}