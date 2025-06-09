# vpc module outputs.tf

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "default_sg_id" {
  description = "The ID of the default security group"
  value       = aws_security_group.default.id
}
