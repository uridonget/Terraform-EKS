# 01-cluster/main.tf

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
      desired_size   = 3
      vpc_security_group_ids = [aws_security_group.eks.id]
    }
  }
}


# IAM Role for EC2 (SSM Access)

resource "aws_iam_role" "db_instance_role" {
  name = "${var.name_prefix}-db-instance-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.db_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "db_instance_profile" {
  name = "${var.name_prefix}-db-instance-profile"
  role = aws_iam_role.db_instance_role.name
}

# EC2 for PostgreSQL Database

data "aws_ssm_parameter" "ubuntu_ami_id" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_security_group" "db" {
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

  tags = {
    Name = "${var.name_prefix}-db-sg"
  }
}

resource "aws_instance" "user_db" {
  ami           = data.aws_ssm_parameter.ubuntu_ami_id.value
  instance_type = "t3.medium"
  subnet_id     = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.db.id]
  iam_instance_profile = aws_iam_instance_profile.db_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              docker run -d --name user-db -p 5432:5432 \
                -e POSTGRES_USER=${var.user_db_env.user} \
                -e POSTGRES_PASSWORD='${var.user_db_env.password}' \
                -e POSTGRES_DB=${var.user_db_env.db_name} \
                --restart always \
                public.ecr.aws/h4h3p3x3/tarot-jeong/user-db
              EOF

  depends_on = [
    module.vpc
  ]

  tags = {
    Name = "${var.name_prefix}-user-db"
  }
}

# EC2 for Redis Database

resource "aws_security_group" "redis_db" {
  name        = "${var.name_prefix}-redis-db-sg"
  description = "Allow Redis traffic from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-redis-db-sg"
  }
}

resource "aws_instance" "redis_db" {
  ami           = data.aws_ssm_parameter.ubuntu_ami_id.value
  instance_type = "t3.medium"
  subnet_id     = module.vpc.private_subnets[1]
  vpc_security_group_ids = [aws_security_group.redis_db.id]
  iam_instance_profile = aws_iam_instance_profile.db_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              docker run -d --name redis-db -p 6379:6379 \
                -e REDIS_ARGS='${var.redis_db_args}' \
                --restart always \
                public.ecr.aws/h4h3p3x3/tarot-jeong/redis-cache
              EOF

  depends_on = [
    module.vpc
  ]

  tags = {
    Name = "${var.name_prefix}-redis-db"
  }
}
