# subnet module variables.tf

variable "name" {
  type        = string
  description = "Name of the subnet"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "cidr_block" {
  type        = string
  description = "CIDR block for subnet"
}

variable "availability_zone" {
  type        = string
  description = "AZ for subnet"
}

variable "public" {
  type        = bool
  default     = false
  description = "Whether this subnet assigns public IPs"
}

variable "igw_id" {
  type        = string
  description = "Internet Gateway ID"
  default     = ""
}

variable "nat_gateway_id" {
  type    = string
  default = ""
}

variable "cluster_name" {
  description = "Kubernetes cluster name used for tagging"
  type        = string
  default     = ""
}
