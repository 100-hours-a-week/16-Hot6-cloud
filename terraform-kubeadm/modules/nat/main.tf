# vpc module main.tf

resource "aws_eip" "this" {
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = var.public_subnet_id

  tags = {
    Name = var.name
  }
}
