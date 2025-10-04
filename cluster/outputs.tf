output "configure_kubectl" {
  description = "Run this command to configure kubectl to connect to the EKS cluster"
  value       = "aws eks update-kubeconfig --region ap-northeast-2 --name ${module.eks.cluster_name}"
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

output "lbc_iam_role_arn" {
  description = "ARN of the IAM role for the AWS Load Balancer Controller"
  value       = aws_iam_role.lbc_iam_role.arn
}

output "eks_managed_node_group_iam_role_arn" {
  description = "IAM role ARN of the managed node group"
  value       = module.eks.eks_managed_node_groups["general"].iam_role_arn
}
