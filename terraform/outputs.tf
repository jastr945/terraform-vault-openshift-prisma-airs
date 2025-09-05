output "vault_url" {
  value = module.vault.vault_public_url
}

output "vault_admin_token" {
  value     = module.vault.admin_token
  sensitive = true
}
