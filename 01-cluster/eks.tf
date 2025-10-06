# cluster/eks.tf

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.33"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  authentication_mode = "API_AND_CONFIG_MAP"

  eks_managed_node_groups = {
    general = {
      min_size     = 1
      max_size     = 5
      desired_size = 3

      instance_types = ["t3.medium"]
      ami_type = "AL2023_x86_64_STANDARD"
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
}
