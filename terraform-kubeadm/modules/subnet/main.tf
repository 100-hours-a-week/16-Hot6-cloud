# subnet module main.tf

resource "aws_subnet" "this" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.cidr_block
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = var.public

  tags = {
    Name                                     = var.name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                 = "1"
  }
}

resource "aws_route_table" "this" {
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name}-rt"
  }

  dynamic "route" {
    for_each = var.public ? [] : (var.nat_gateway_id == "" ? [] : [var.nat_gateway_id])
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = route.value
    }
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
