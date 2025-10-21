# 02-addons/main.tf

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../01-cluster/terraform.tfstate"
  }
}

# IRSA

module "alb_controller_irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "5.39.0"
  role_name = "${data.terraform_remote_state.eks.outputs.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# AWS Load Balancer Controller 설치

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"

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

  depends_on = [
    module.alb_controller_irsa
  ]
}

# External DNS

module "external_dns_irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "5.39.0"

  role_name = "${var.name_prefix}-external-dns"

  role_policy_arns = {
    policy = aws_iam_policy.external_dns.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

resource "aws_iam_policy" "external_dns" {
  name        = "${var.name_prefix}-external-dns"
  description = "Allows ExternalDNS to modify Route 53"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones", "route53:ListResourceRecordSets"]
        Resource = ["*"]
      }
    ]
  })
}

output "external_dns_iam_role_arn" {
  description = "IAM role ARN for ExternalDNS"
  value       = module.external_dns_irsa.iam_role_arn
}

# Istio Base 설치

resource "helm_release" "istio_base" {
  name             = "istio-base"
  chart            = "base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true
  version          = "1.27.1"
  timeout          = 300
  wait             = true
}

# Istiod 설치

resource "helm_release" "istiod" {
  name       = "istiod"
  chart      = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  namespace  = "istio-system"
  version    = "1.27.1"
  timeout    = 600
  wait       = true

  depends_on = [
    helm_release.istio_base,
    helm_release.aws_lb_controller,
    null_resource.wait_for_prometheus_crds
  ]

  values = [
    yamlencode({
      meshConfig = {
        enablePrometheusMerge = true
      }
    })
  ]
}

# Istio Ingress 설치

resource "helm_release" "istio_ingress" {
  name       = "istio-ingress"
  chart      = "gateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  namespace  = "istio-system"
  version    = "1.27.1"
  timeout    = 600
  wait       = true

  values = [
    yamlencode({
      global = {
        webhookTimeoutSeconds = 60
      }
      service = {
        type = "ClusterIP"
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

resource "kubernetes_labels" "istio_injection" {
  for_each = toset(var.istio_enabled_namespaces)
  api_version = "v1"
  kind        = "Namespace"

  metadata {
    name = each.key
  }

  labels = {
    "istio-injection" = "enabled"
  }

  depends_on = [
    helm_release.istiod
  ]
}

# Prometheus & Grafana 설치

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "67.2.0"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 600
  wait             = true

  depends_on = [
    helm_release.aws_lb_controller
  ]

  values = [
    yamlencode({
      alertmanager = {
        persistence = { enabled = false }
      }
      prometheus = {
        prometheusSpec = {
          storageSpec = {}
          serviceMonitorNamespaceSelector = {
            matchNames = [
              "monitoring",
              "istio-system"
            ]
          }
          podMonitorNamespaceSelector = {
            matchNames = [
              "monitoring",
              "istio-system"
            ]
          }
        }
      }
      grafana = {
        persistence = { enabled = false }
        adminPassword = var.grafana_admin_password

        "grafana.ini" = {
          server = {
            root_url = "https://api.haechan.net/grafana"
            serve_from_sub_path = true
          }
        }
      }
    })
  ]
}

# Prometheus CRD가 생성될 때까지 대기

resource "null_resource" "wait_for_prometheus_crds" {
  depends_on = [
    helm_release.prometheus
  ]

  provisioner "local-exec" {
    command = <<EOT
      kubectl wait --for=condition=Established crd/podmonitors.monitoring.coreos.com --timeout=120s
      kubectl wait --for=condition=Established crd/servicemonitors.monitoring.coreos.com --timeout=120s
    EOT
  }
}

# Metrics Server 설치

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.0"
  namespace  = "kube-system"

  depends_on = [
    helm_release.aws_lb_controller
  ]

  values = [
    yamlencode({
      args = [
        "--kubelet-insecure-tls"
      ]
    })
  ]
}

# Prometheus Adapter 설치

resource "helm_release" "prometheus_adapter" {
  name       = "prometheus-adapter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-adapter"
  version    = "4.11.0"
  namespace  = "monitoring"

  depends_on = [
    helm_release.prometheus
  ]

  values = [
    yamlencode({
      prometheus = {
        url  = "http://prometheus-kube-prometheus-prometheus.monitoring.svc"
        port = 9090
      }
      rules = {
        default = false
        custom = [
          {
            seriesQuery = "istio_requests_total{reporter=\"destination\",destination_workload_namespace!=\"\",pod_name!=\"\"}"
            resources = {
              overrides = {
                destination_workload_namespace = { resource = "namespace" }
                pod_name                       = { resource = "pod" }
              }
            }
            name = {
              matches = "^(.*)_total$"
              as      = "istio_requests_per_second"
            }
            metricsQuery = "sum(rate(<<.Series>>{<<.LabelMatchers>>,reporter=\"destination\"}[2m])) by (<<.GroupBy>>)"
          }
        ]
      }
    })
  ]
}

# Kiali 설치

resource "helm_release" "kiali" {
  name             = "kiali"
  repository       = "https://kiali.org/helm-charts"
  chart            = "kiali-server"
  version          = "2.2.0"
  namespace        = "istio-system"
  create_namespace = false

  depends_on = [
    helm_release.prometheus,
    helm_release.istiod
  ]

  values = [
    yamlencode({
      auth = {
        strategy = "anonymous"
      }
      external_services = {
        prometheus = {
          url = "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
        }
      }
      deployment = {
        istio_namespace = "istio-system"
      }
    })
  ]
}

# Namespace tarot

resource "kubernetes_namespace" "tarot" {
  metadata {
    name = "tarot"
  } 
}