# 02-addons/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.10"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.8"
    }
  }
}

provider "aws" {
  region = var.region
}

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../01-cluster/terraform.tfstate"
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
    }
  }
}

module "alb_controller_irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "5.39.0"

  role_name = "${data.terraform_remote_state.eks.outputs.cluster_name}-alb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      # provider_arn은 기존 코드 방식에 맞춰 data.terraform_remote_state.eks를 참조하도록 수정
      provider_arn               = data.terraform_remote_state.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# 2. Helm을 사용하여 AWS Load Balancer Controller 설치
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1" # 특정 버전으로 고정하여 안정성 확보

  values = [
    yamlencode({
      clusterName = data.terraform_remote_state.eks.outputs.cluster_name
      region      = var.region
      vpcId       = data.terraform_remote_state.eks.outputs.vpc_id

      serviceAccount = {
        create      = true
        name        = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.alb_controller_irsa.iam_role_arn
        }
      }
    })
  ]
}


### 추가한 부분 끝

# ISTIO 설치

resource "helm_release" "istio_base" {
  name             = "istio-base"
  chart            = "base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true
  version          = "1.26.1"
  timeout          = 300
  wait             = true
}

resource "helm_release" "istiod" {
  name       = "istiod"
  chart      = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  namespace  = "istio-system"
  version    = "1.26.1"
  timeout    = 600
  wait       = true

  depends_on = [
    helm_release.istio_base
  ]
}

resource "helm_release" "istio_ingress" {
  name       = "istio-ingress"
  chart      = "gateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  namespace  = "istio-system"
  version    = "1.26.1"
  timeout    = 600
  wait       = false

  values = [
    yamlencode({
      global = {
        webhookTimeoutSeconds = 60
      }
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
        }
      }
    })
  ]
  depends_on = [
    helm_release.istiod
  ]
}
