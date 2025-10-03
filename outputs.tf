output "configure_kubectl" {
  description = "Run this command to configure kubectl to connect to the EKS cluster"
  value       = "aws eks update-kubeconfig --region ap-northeast-2 --name ${module.eks.cluster_name}"
}
