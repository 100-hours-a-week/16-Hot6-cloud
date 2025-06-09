# vpc module main.tf

resource "aws_subnet" "this" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.cidr_block
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = var.public

  tags = {
    Name = var.name
  }
}

resource "aws_route_table" "this" {
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name}-rt"
  }
}

resource "aws_route" "default" {
  count                  = var.public ? 1 : 0
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.igw_id
}

resource "aws_route_table_association" "this" {
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_route_table.this.id
}
