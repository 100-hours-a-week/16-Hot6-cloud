# asg module variables.tf

variable "name" {
  type = string
}

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "desired_capacity" {
  type = number
}

variable "use_spot" {
  type    = bool
  default = false
}

variable "user_data" {
  description = "User data script for EC2"
  type        = string
  default     = null
  nullable    = true
}
