# domain/main.tf

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "../cluster/terraform.tfstate"
  }
}
