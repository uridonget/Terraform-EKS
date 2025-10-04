# authenticate/access.tf

# Luckyseven 그룹 정보를 가져와서 멤버들의 ARN 목록을 확보합니다.
data "aws_iam_group" "luckyseven" {
  group_name = "Luckyseven"
}

# Luckyseven 그룹 멤버들만 사용할 수 있는 IAM 역할을 생성합니다.
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