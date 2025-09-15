variable "openshift_token" {}
variable "openshift_host" {}

variable "namespace" {
  description = "Namespace/project to create"
  type        = string
  default     = "default"
}

variable "image" {
  description = "Full container image to run (registry/name:tag)"
  type        = string
}

variable "replicas" {
  type    = number
  default = 1
}

variable "app_name" {
  type    = string
  default = "ai-chatbot"
}
