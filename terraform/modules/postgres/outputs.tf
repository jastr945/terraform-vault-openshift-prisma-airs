output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.ai_agent.address
}

output "rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.ai_agent.username
}