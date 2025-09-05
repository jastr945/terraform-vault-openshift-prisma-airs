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
  }
}
