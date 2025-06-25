# NAT module variables.tf

variable "name" {
  type        = string
  description = "Name of NAT Gateway"
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet to attach NAT Gateway"
}
