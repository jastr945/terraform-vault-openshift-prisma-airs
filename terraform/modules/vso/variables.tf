variable "openshift_token" {}
variable "openshift_host" {}

variable "namespace" {
  description = "Namespace to install VSO and Vault auth resources"
  type        = string
  default     = "default"
}

variable "vault_addr" {
  description = "Address/URL of Vault (e.g. https://<vault-host>:8200)"
  type        = string
}

variable "vault_admin_token" {
  description = "Vault admin token (sensitive) - used only to bootstrap a VaultAuth Kubernetes secret for the operator"
  type        = string
  sensitive   = true
}

variable "vso_chart_version" {
  description = "Vault Secrets Operator Helm chart version (optional)"
  type        = string
  default     = "0.9.0"
}
