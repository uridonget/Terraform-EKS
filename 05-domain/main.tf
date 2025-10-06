# domain/main.tf

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "../01-cluster/terraform.tfstate"
  }
}
