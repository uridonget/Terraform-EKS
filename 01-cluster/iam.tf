# cluster/iam.tf

data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc_iam_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM Policy for AWS Load Balancer Controller"
  policy      = data.http.lbc_iam_policy.response_body
}

data "aws_iam_policy_document" "lbc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lbc_iam_role" {
  name               = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "lbc_iam_role_policy_attachment" {
  policy_arn = aws_iam_policy.lbc_iam_policy.arn
  role       = aws_iam_role.lbc_iam_role.name
}





