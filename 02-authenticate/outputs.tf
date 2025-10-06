# authenticate/outputs.tf

output "eks_admin_role_arn" {
  description = "The ARN of the IAM role for EKS admins"
  value       = aws_iam_role.eks_luckyseven_admin_role.arn
}
