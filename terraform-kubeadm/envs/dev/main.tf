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
}

module "public_subnet_c" {
  source            = "../../modules/subnet"
  name              = "${var.name}-public-subnet-c"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = var.public_subnet_cidr_c
  availability_zone = "ap-northeast-2c"
  public            = true
  igw_id            = module.vpc.igw_id
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
    Env  = "dev"
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

  tags = {
    Name = "${var.name}-worker-sg"
  }
}

module "asg_worker" {
  source             = "../../modules/asg"
  name               = "${var.name}-worker"
  ami                = var.ami
  instance_type      = var.instance_type
  key_name           = var.key_name
  subnet_id          = module.public_subnet_a.subnet_id
  security_group_ids = [
    module.vpc.default_sg_id,
    aws_security_group.worker_sg.id
  ]
  user_data          = local.user_data_worker
  min_size           = 1
  max_size           = 3
  desired_capacity   = 2
  use_spot           = true
}

resource "aws_lb" "ingress" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [
    module.public_subnet_a.subnet_id,
    module.public_subnet_c.subnet_id
  ]
}

resource "aws_security_group" "alb_sg" {
  name        = "${var.name}-alb-sg"
  description = "Allow HTTP and HTTPS to ALB"
  vpc_id      = module.vpc.vpc_id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-alb-sg"
  }
}

resource "aws_lb_target_group" "ingress" {
  name     = "${var.name}-tg"
  port     = 30494
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    path                = "/healthz"
    protocol            = "HTTP"
    port                = "30494"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.ssl_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

module "ingress_node" {
  source         = "../../modules/ec2"
  name           = "${var.name}-ingress"
  ami            = var.ami
  instance_type  = var.instance_type
  subnet_id      = module.public_subnet_a.subnet_id
  vpc_id         = module.vpc.vpc_id
  key_name       = var.key_name
  associate_public_ip = true
  use_spot       = false
  user_data      = local.user_data_worker

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 10250
      to_port     = 10250
      protocol    = "tcp"
      cidr_blocks = ["10.10.0.0/16"]
    },
    {
      from_port   = 30000
      to_port     = 32767
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 8472
      to_port     = 8472
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  tags = {
    Role = "k8s-ingress"
    Env  = "dev"
  }
}

resource "aws_lb_target_group_attachment" "ingress_node" {
  # ingress 노드 여러개 되면 foreach 추가
  target_group_arn = aws_lb_target_group.ingress.arn
  target_id        = module.ingress_node.instance_id
  port             = 30494
}
