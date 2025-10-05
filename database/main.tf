# database/main.tf

# cluster 모듈의 결과값을 가져옵니다.
data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "../cluster/terraform.tfstate"
  }
}

data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = "my-eks-db-credentials"
}

resource "aws_db_subnet_group" "rds" {
  name       = "my-eks-db-subnet-group"
  subnet_ids = data.terraform_remote_state.cluster.outputs.private_subnets

  tags = {
    Name = "My EKS DB subnet group"
  }
}

resource "aws_security_group" "rds" {
  name        = "my-eks-db-sg"
  description = "Allow PostgreSQL traffic from EKS nodes"
  vpc_id      = data.terraform_remote_state.cluster.outputs.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.cluster.outputs.eks_node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "my-eks-db-instance"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.7"
  instance_class         = "db.t4g.micro"
  db_name                = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["dbname"]
  port                   = 5432
  username               = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["username"]
  password               = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["password"]
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true # 개발/테스트 환경에서는 true로 설정하는 것을 권장합니다.
  publicly_accessible    = false
}