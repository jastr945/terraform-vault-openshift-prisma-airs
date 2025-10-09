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
    aws = {
      source  = "hashicorp/aws"
      version = "6.14.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}
