# authenticate/automation.tf

resource "null_resource" "update_kubeconfig" {
  depends_on = [
    aws_eks_access_policy_association.luckyseven_cluster_admin,
    aws_eks_access_policy_association.luckyseven_admin,
  ]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ap-northeast-2 --name ${data.terraform_remote_state.cluster.outputs.cluster_name} --role-arn ${aws_iam_role.eks_luckyseven_admin_role.arn}"
  }
}
