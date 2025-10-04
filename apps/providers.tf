# apps/providers.tf

provider "aws" {
  region = "ap-northeast-2"
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.cluster.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", data.terraform_remote_state.cluster.outputs.cluster_name,
      "--role-arn", data.terraform_remote_state.auth.outputs.eks_admin_role_arn
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.cluster.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", data.terraform_remote_state.cluster.outputs.cluster_name,
        "--role-arn", data.terraform_remote_state.auth.outputs.eks_admin_role_arn
      ]
    }
  }
}
