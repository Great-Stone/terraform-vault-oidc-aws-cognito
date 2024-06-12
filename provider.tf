terraform {
  required_version = ">= 1.0"

  required_providers {
    vault = {
      source = "hashicorp/vault"
    }
    aws = {
      source = "hashicorp/aws"
    }
    external = {
      source = "hashicorp/external"
    }
  }
}