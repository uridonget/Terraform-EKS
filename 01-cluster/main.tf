# 01-cluster/main.tf

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# VPC

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.4"

  name = "${var.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.name_prefix}-cluster" = "shared"
    "kubernetes.io/role/elb"                           = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.name_prefix}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                  = "1"
  }
}

# EKS

resource "aws_security_group" "eks" {
  name   = "${var.name_prefix}-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.name_prefix}-cluster"
  kubernetes_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true  

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    "${var.name_prefix}-nodegroup" = {
      instance_types = ["t3.medium"]
      ami_type       = "AL2023_x86_64_STANDARD"
      min_size       = 1
      max_size       = 5
      desired_size   = 2
      vpc_security_group_ids = [aws_security_group.eks.id]
    }
  }
}

# RDS

data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = "my-eks-db-credentials"
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.name_prefix}-db-subnet"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "My EKS DB subnet group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-db-sg"
  description = "Allow PostgreSQL traffic from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.name_prefix}-db"
  allocated_storage      = 20
  storage_type           = "gp3"
  engine                 = "postgres"
  engine_version         = "15.7"
  instance_class         = "db.t4g.micro"
  db_name                = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["dbname"]
  username               = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["username"]
  password               = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["password"]
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}

# namespace neves

resource "kubernetes_namespace" "neves" {
  metadata {
    name = "neves"
  }
}