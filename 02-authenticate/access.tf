# authenticate/access.tf

data "aws_iam_group" "luckyseven" {
  group_name = "Luckyseven"
}

resource "aws_iam_role" "eks_luckyseven_admin_role" {
  name = "eks-luckyseven-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = data.aws_iam_group.luckyseven.users[*].arn
        },
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_eks_access_entry" "luckyseven_role_entry" {
  cluster_name  = data.terraform_remote_state.cluster.outputs.cluster_name
  principal_arn = aws_iam_role.eks_luckyseven_admin_role.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "luckyseven_cluster_admin" {
  cluster_name  = data.terraform_remote_state.cluster.outputs.cluster_name
  principal_arn = aws_iam_role.eks_luckyseven_admin_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_policy_association" "luckyseven_admin" {
  cluster_name  = data.terraform_remote_state.cluster.outputs.cluster_name
  principal_arn = aws_iam_role.eks_luckyseven_admin_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  access_scope {
    type = "cluster"
  }
}