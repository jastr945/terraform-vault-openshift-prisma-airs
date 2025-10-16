output "vault_url" {
  value = module.vault.vault_public_url
}

output "postgres_hostname" {
  description = "PostgreSQL hostname"
  value       = module.postgres.rds_hostname
}

output "postgres_username" {
  description = "PostgreSQL admin username"
  value       = module.postgres.rds_username
}