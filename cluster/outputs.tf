# cluster/outputs.tf

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

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the API domain"
  value       = aws_acm_certificate_validation.api.certificate_arn
}

output "eks_node_security_group_id" {
  description = "The security group ID attached to the EKS worker nodes"
  value       = module.eks.node_security_group_id
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}
