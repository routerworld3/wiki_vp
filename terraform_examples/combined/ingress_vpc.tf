# ----------------------------
# INGRESS NIPRNET VPC MODULE
# ----------------------------

locals {
  ingress_primary_cidr   = var.ingress_cidr_blocks[0]
  ingress_secondary_cidrs = slice(var.ingress_cidr_blocks, 1, length(var.ingress_cidr_blocks))
}

resource "aws_vpc" "ingress" {
  cidr_block           = local.ingress_primary_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = var.ingress_name })
}

resource "aws_vpc_ipv4_cidr_block_association" "ingress_secondary" {
  for_each   = toset(local.ingress_secondary_cidrs)
  vpc_id     = aws_vpc.ingress.id
  cidr_block = each.key
}

resource "aws_subnet" "ingress" {
  for_each = {
    alb_a      = { cidr = var.ingress_alb_subnet_cidrs[0], az = var.azs[0] }
    alb_b      = { cidr = var.ingress_alb_subnet_cidrs[1], az = var.azs[1] }
    tgw_vdss_a = { cidr = var.ingress_tgw_vdss_subnet_cidrs[0], az = var.azs[0] }
    tgw_vdss_b = { cidr = var.ingress_tgw_vdss_subnet_cidrs[1], az = var.azs[1] }
    tgw_edge_a = { cidr = var.ingress_tgw_edge_subnet_cidrs[0], az = var.azs[0] }
    tgw_edge_b = { cidr = var.ingress_tgw_edge_subnet_cidrs[1], az = var.azs[1] }
  }
  vpc_id            = aws_vpc.ingress.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(var.tags, { Name = "${var.ingress_name}-${each.key}" })
  depends_on        = [aws_vpc_ipv4_cidr_block_association.ingress_secondary]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "ingress_vdss" {
  vpc_id             = aws_vpc.ingress.id
  subnet_ids         = [
    aws_subnet.ingress["tgw_vdss_a"].id,
    aws_subnet.ingress["tgw_vdss_b"].id
  ]
  transit_gateway_id = var.tgw_vdss_id
  tags               = merge(var.tags, { Name = "${var.ingress_name}-vdss-attachment" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "ingress_edge" {
  vpc_id             = aws_vpc.ingress.id
  subnet_ids         = [
    aws_subnet.ingress["tgw_edge_a"].id,
    aws_subnet.ingress["tgw_edge_b"].id
  ]
  transit_gateway_id = var.tgw_edge_id
  tags               = merge(var.tags, { Name = "${var.ingress_name}-edge-attachment" })
}

resource "aws_route_table" "ingress_main" {
  vpc_id = aws_vpc.ingress.id
  tags   = merge(var.tags, { Name = "${var.ingress_name}-main-rt" })
}

resource "aws_route" "ingress_to_vdss" {
  route_table_id         = aws_route_table.ingress_main.id
  destination_cidr_block = var.vdss_cidr
  transit_gateway_id     = var.tgw_vdss_id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.ingress_vdss]
}

resource "aws_route" "ingress_to_edge" {
  route_table_id         = aws_route_table.ingress_main.id
  destination_cidr_block = var.edge_cidr
  transit_gateway_id     = var.tgw_edge_id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.ingress_edge]
}
