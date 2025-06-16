# peering main.tf

provider "aws" {
  region = var.region
}

data "aws_vpc" "shared" {
  filter {
    name   = "cidr-block"
    values = [var.shared_vpc_cidr]
  }
}

data "aws_vpc" "dev" {
  filter {
    name   = "cidr-block"
    values = [var.dev_vpc_cidr]
  }
}

data "aws_route_tables" "dev" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.dev.id]
  }
}

data "aws_route_tables" "shared" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
}

resource "aws_vpc_peering_connection" "dev_to_shared" {
  vpc_id        = data.aws_vpc.dev.id
  peer_vpc_id   = data.aws_vpc.shared.id
  auto_accept   = false
  peer_region   = var.region

  tags = {
    Name = "${var.dev_name}-to-${var.shared_name}"
  }
}

resource "aws_vpc_peering_connection_accepter" "accept_dev_to_shared" {
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_to_shared.id
  auto_accept               = true

  tags = {
    Name = "accept-${var.dev_name}-to-${var.shared_name}"
  }
}

resource "aws_route" "route_dev_to_shared" {
  for_each = toset(data.aws_route_tables.dev.ids)

  route_table_id             = each.key
  destination_cidr_block     = data.aws_vpc.shared.cidr_block
  vpc_peering_connection_id  = aws_vpc_peering_connection.dev_to_shared.id
}

resource "aws_route" "route_shared_to_dev" {
  for_each = toset(data.aws_route_tables.shared.ids)

  route_table_id             = each.key
  destination_cidr_block     = data.aws_vpc.dev.cidr_block
  vpc_peering_connection_id  = aws_vpc_peering_connection.dev_to_shared.id
}
