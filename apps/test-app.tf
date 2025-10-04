# test-app.tf

# --- Web Application ---

resource "kubernetes_manifest" "web_deployment" {
  manifest = yamldecode(file("${path.module}/manifests/deployment/web-deployment.yaml"))
}

resource "kubernetes_manifest" "web_service" {
  manifest = yamldecode(file("${path.module}/manifests/service/web-service.yaml"))
  depends_on = [
    kubernetes_manifest.web_deployment
  ]
}

# --- API Application ---

resource "kubernetes_manifest" "api_deployment" {
  manifest = yamldecode(file("${path.module}/manifests/deployment/api-deployment.yaml"))
}

resource "kubernetes_manifest" "api_service" {
  manifest = yamldecode(file("${path.module}/manifests/service/api-service.yaml"))
  depends_on = [
    kubernetes_manifest.api_deployment
  ]
}

# --- Ingress for both applications ---

resource "kubernetes_manifest" "ingress" {
  manifest = yamldecode(file("${path.module}/manifests/ingress/main-ingress.yaml"))

  depends_on = [
    kubernetes_manifest.web_service,
    kubernetes_manifest.api_service
  ]
}