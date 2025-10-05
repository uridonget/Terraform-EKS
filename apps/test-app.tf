# apps/test-app.tf


# Secrets Manager에서 DB 자격 증명을 직접 읽어옵니다.
data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = "my-eks-db-credentials"
}

# 읽어온 Secret 값(JSON)을 Terraform에서 사용할 수 있도록 파싱합니다.
locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
}

# ==============================================================================
# Namespace
# ==============================================================================
# 'neves' 네임스페이스를 생성합니다.
resource "kubernetes_namespace" "neves" {
  metadata {
    name = "neves"
  }
}

# ==============================================================================
# User Server
# ==============================================================================

resource "kubernetes_manifest" "user_server_configmap" {
  manifest = yamldecode(templatefile("${path.module}/manifests/configmap/user-server-configmap.yaml", {
    db_host     = data.terraform_remote_state.database.outputs.db_address
    db_port     = data.terraform_remote_state.database.outputs.db_port
    db_name     = local.db_creds.dbname
    db_user     = local.db_creds.username
    db_password = local.db_creds.password
  }))

  depends_on = [kubernetes_namespace.neves]
}

resource "kubernetes_manifest" "user_server_service" {
  manifest = yamldecode(file("${path.module}/manifests/service/user-server-service.yaml"))
  depends_on = [kubernetes_namespace.neves]
}

resource "kubernetes_manifest" "user_server_deployment" {
  manifest = yamldecode(file("${path.module}/manifests/deployment/user-server-deploy.yaml"))
  depends_on = [
    kubernetes_manifest.user_server_configmap,
    kubernetes_manifest.user_server_service
  ]
}

# ==============================================================================
# Common Ingress
# ==============================================================================

resource "kubernetes_manifest" "ingress" {
  manifest = yamldecode(templatefile("${path.module}/manifests/ingress/main-ingress.yaml", {
    acm_certificate_arn = data.terraform_remote_state.cluster.outputs.acm_certificate_arn
  }))

  depends_on = [
    kubernetes_manifest.user_server_service
  ]

  timeouts {
    delete = "15m"
  }
}
