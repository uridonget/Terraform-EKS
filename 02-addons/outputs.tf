# 02-addons/outputs.tf

output "istio_ingress_gateway_service" {
  description = "Istio Ingress Gateway LoadBalancer hostname"
  value       = try(
    data.kubernetes_service.istio_ingress.status[0].load_balancer[0].ingress[0].hostname,
    "pending"
  )
}

data "kubernetes_service" "istio_ingress" {
  metadata {
    name      = "istio-ingress"
    namespace = "istio-system"
  }

  depends_on = [
    helm_release.istio_ingress
  ]
}