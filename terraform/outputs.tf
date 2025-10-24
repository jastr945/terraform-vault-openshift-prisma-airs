output "vault_url" {
  value = module.vault-admin.vault_public_url
}
output "vault_admin_token" {
  value     = module.vault-admin.vault_admin_token
  sensitive = true
}
output "vault_kubernetes_auth_backend_path" {
  value = module.vault-trusted-ai.vault_kubernetes_auth_backend_path
}
output "vault_trusted_ai_namespace_token" {
  value     = module.vault-admin.trusted_ai_namespace_token
  sensitive = true
}
output "vault_trusted_ai_namespace_path" {
  value = module.vault-admin.trusted_ai_namespace_path
} 
output "postgres_hostname" {
  description = "PostgreSQL hostname"
  value       = module.postgres.rds_hostname
}
output "postgres_username" {
  description = "PostgreSQL admin username"
  value       = module.postgres.rds_username
}