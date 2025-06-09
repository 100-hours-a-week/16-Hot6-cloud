# shared main.tf

provider "aws" {
  region = var.region
}

# VPC
module "vpc" {
  source     = "../../modules/vpc"
  name       = var.name
  cidr_block = var.vpc_cidr
}

# Subnets
module "public_subnet" {
  source             = "../../modules/subnet"
  name               = "${var.name}-public-subnet"
  vpc_id             = module.vpc.vpc_id
  cidr_block         = var.public_subnet_cidr
  availability_zone  = var.availability_zone
  public             = true
  igw_id             = module.vpc.igw_id
}

module "private_subnet" {
  source             = "../../modules/subnet"
  name               = "${var.name}-private-subnet"
  vpc_id             = module.vpc.vpc_id
  cidr_block         = var.private_subnet_cidr
  availability_zone  = var.availability_zone
  public             = false
}

# 고정 EIP 할당
resource "aws_eip" "vpn_eip" {
  tags = {
    Name = "${var.name}-vpn-eip"
  }
}

# VPN EC2 (Public)
module "vpn_instance" {
  source         = "../../modules/ec2"
  name           = "${var.name}-vpn"
  ami            = var.ami
  instance_type  = var.vpn_instance_type
  subnet_id      = module.public_subnet.subnet_id
  vpc_id         = module.vpc.vpc_id
  key_name       = var.key_name
  use_spot       = false
  associate_public_ip = true
  source_dest_check   = false 
  user_data      = null
  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 51820
      to_port     = 51820
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {
    Role = "vpn"
    Env  = "shared"
  }
}

# EIP와 vpn_instance 연결
resource "aws_eip_association" "vpn_eip_assoc" {
  instance_id   = module.vpn_instance.instance_id
  allocation_id = aws_eip.vpn_eip.id
}

resource "aws_route" "private_subnet_default_nat" {
  route_table_id         = module.private_subnet.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.vpn_instance.primary_network_interface_id
}

# Monitoring EC2 (Private Subnet)
module "monitoring_instance" {
  source         = "../../modules/ec2"
  name           = "${var.name}-monitoring"
  ami            = var.ami
  instance_type  = var.monitoring_instance_type
  subnet_id      = module.private_subnet.subnet_id
  vpc_id         = module.vpc.vpc_id
  key_name       = var.key_name
  use_spot       = false
  associate_public_ip = false
  user_data      = null
  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]  # shared 내부에서만 접근
    },
    {
      from_port   = 4317
      to_port     = 4317
      protocol    = "tcp"
      cidr_blocks = ["10.10.0.0/16", "10.20.0.0/16"]  # OTEL collector용
    }
  ]
  tags = {
    Role = "monitoring"
    Env  = "shared"
  }
}
