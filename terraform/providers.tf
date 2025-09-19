terraform {
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "0.109.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.2.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}
