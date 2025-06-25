# dev variables.tf

variable "region" {
  type        = string
  default     = "ap-northeast-2"
  description = "AWS Region"
}

variable "name" {
  type        = string
  default     = "kubeadm-dev"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_a" {
  type        = string
}

variable "public_subnet_cidr_c" {
  type        = string
}

variable "private_subnet_cidr_a" {
  type        = string
}

variable "private_subnet_cidr_c" {
  type        = string
}

variable "db_subnet_cidr" {
  type        = string
}

variable "availability_zone" {
  type        = string
  default     = "ap-northeast-2a"
}

variable "ami" {
  type        = string
  default     = "ami-0e43cd0b963b3bdee"
  description = "Ubuntu 24.04 AMI ID (ap-northeast-2)"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "EC2 접속용 SSH 키 이름"
}

variable "nginx_port" {
  type        = number
  default     = 8080
}
