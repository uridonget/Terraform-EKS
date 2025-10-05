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
    path = "../cluster/terraform.tfstate"
  }
}

data "terraform_remote_state" "auth" {
  backend = "local"

  config = {
    path = "../authenticate/terraform.tfstate"
  }
}

data "terraform_remote_state" "database" {
  backend = "local"

  config = {
    path = "../database/terraform.tfstate"
  }
}