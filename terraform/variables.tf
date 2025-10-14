variable "hcp_client_id" {}
variable "hcp_client_secret" {}
variable "hcp_project_id" {}
variable "hvn_id" {
  default = "vault-hvn"
}
variable "hvn_region" {
  default = "us-west-2"
}
variable "hvn_cidr" {
  default = "172.25.0.0/16"
}
variable "hvn_cloud_provider" {
  description = "Cloud provider for the HVN"
  type        = string
  default     = "aws"
}
variable "vault_cluster_id" {
  default = "vault-dedicated"
}
variable "vault_namespace" {
  default = "admin"
}
variable "gemini_api_key" {
  description = "LLM API Key"
  type = string
}
variable "prisma_airs_api_key" {
  description = "Prisma AIRS API key"
  type = string
}
variable "prisma_airs_profile" {
  description = "Prisma AIRS deployment profile"
  type = string
}
variable "db_name" {
  description = "Unique name to assign to RDS instance"
  default = "aiagentdb"
}
variable "db_username" {
  description = "RDS root username"
  default = "aiagent"
}
variable "db_password" {
  description = "RDS root user password (careful with special chars - not everything is accepted!)"
  sensitive   = true
}
variable "db_port" {
  default = 5432
}