output "vault_url" {
  value = module.vault.vault_public_url
}

output "vault_admin_token" {
  value     = module.vault.admin_token
  sensitive = true
}

output "vault_transit_mount_path" {
  value = module.vault.vault_transit_mount_path
}

output "vault_transit_key_name" {
  value = module.vault.vault_transit_key_name
}