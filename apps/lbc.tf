resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  values = [
    yamlencode({
      clusterName = data.terraform_remote_state.cluster.outputs.cluster_name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = data.terraform_remote_state.cluster.outputs.lbc_iam_role_arn
        }
      }
    })
  ]
}