# ec2 module variables.tf

variable "name" {
  type        = string
  description = "EC2 instance name"
}

variable "ami" {
  type        = string
  description = "AMI ID to use"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the instance in"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the instance's security group"
}

variable "key_name" {
  type        = string
  description = "SSH key name"
}

variable "use_spot" {
  type        = bool
  default     = false
  description = "스팟 인스턴스를 사용할지 여부"
}

variable "associate_public_ip" {
  type    = bool
  default = false
}

variable "user_data" {
  description = "User data script for EC2"
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

variable "source_dest_check" {
  type    = bool
  default = true
}
