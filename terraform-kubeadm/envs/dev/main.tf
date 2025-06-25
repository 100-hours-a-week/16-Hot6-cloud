# dev main.tf

provider "aws" {
  region = var.region
}

locals {
  cluster_name = "${var.name}-cluster"

  user_data_master = templatefile("${path.root}/../../templates/user_data_master.tpl", {
    nginx_port   = var.nginx_port
  })

  user_data_worker = templatefile("${path.root}/../../templates/user_data_worker.tpl", {
    master_ip  = module.k8s_master.private_ip
    nginx_port = var.nginx_port
  })
}

data "aws_acm_certificate" "ssl_cert" {
  domain       = "*.onthe-top.com"
  statuses     = ["ISSUED"]
  most_recent  = true
}

module "vpc" {
  source     = "../../modules/vpc"
  name       = var.name
  cidr_block = var.vpc_cidr
}

module "public_subnet_a" {
  source            = "../../modules/subnet"
  name              = "${var.name}-public-subnet-a"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = var.public_subnet_cidr_a
  availability_zone = "ap-northeast-2a"
  public            = true
  igw_id            = module.vpc.igw_id
  cluster_name      = local.cluster_name
}

module "public_subnet_c" {
  source            = "../../modules/subnet"
  name              = "${var.name}-public-subnet-c"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = var.public_subnet_cidr_c
  availability_zone = "ap-northeast-2c"
  public            = true
  igw_id            = module.vpc.igw_id
  cluster_name      = local.cluster_name
}

resource "aws_iam_role" "worker_node_role" {
  name = "kubeadm-worker-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "worker_node_policy" {
  name   = "kubeadm-worker-policy"
  role   = aws_iam_role.worker_node_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*",
          "ec2:*",
          "acm:*",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf:*",
          "tag:*",
          "ecr:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "worker_node_profile" {
  name = "kubeadm-worker-instance-profile"
  role = aws_iam_role.worker_node_role.name
}

module "k8s_master" {
  source         = "../../modules/ec2"
  name           = "${var.name}-master"
  ami            = var.ami
  instance_type  = var.instance_type
  subnet_id      = module.public_subnet_a.subnet_id
  vpc_id         = module.vpc.vpc_id
  key_name       = var.key_name
  use_spot       = false
  associate_public_ip = true
  user_data      = local.user_data_master

  iam_instance_profile = aws_iam_instance_profile.worker_node_profile.name

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 10250
      to_port     = 10250
      protocol    = "tcp"
      cidr_blocks = ["10.10.0.0/16"] # dev 내 worker와의 통신
    },
    {
      from_port   = 18080
      to_port     = 18080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      from_port   = 30000
      to_port     = 32767
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # NodePort 접근 허용
    }
  ]

  tags = {
    Role = "k8s-master"
    Env  = "dev",
    "kubernetes.io/cluster/kubeadm-dev-cluster" = "owned"
  }
}

resource "aws_security_group" "worker_sg" {
  name        = "${var.name}-worker-sg"
  description = "Allow Worker Ports"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-worker-sg"
    "kubernetes.io/cluster/kubeadm-dev-cluster" = "owned"
  }
}

module "asg_worker" {
  source             = "../../modules/asg"
  name               = "${var.name}-worker"
  ami                = var.ami
  instance_type      = var.instance_type
  key_name           = var.key_name
  subnet_id          = module.public_subnet_a.subnet_id
  associate_public_ip  = true
  security_group_ids = [
    module.vpc.default_sg_id,
    aws_security_group.worker_sg.id
  ]
  user_data          = local.user_data_worker
  min_size           = 1
  max_size           = 3
  desired_capacity   = 2
  use_spot           = true

  iam_instance_profile = aws_iam_instance_profile.worker_node_profile.name
}
