# apps/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.5"
    }
  }
}

data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "../01-cluster/terraform.tfstate"
  }
}

data "terraform_remote_state" "auth" {
  backend = "local"

  config = {
    path = "../02-authenticate/terraform.tfstate"
  }
}

data "terraform_remote_state" "database" {
  backend = "local"

  config = {
    path = "../03-database/terraform.tfstate"
  }
}