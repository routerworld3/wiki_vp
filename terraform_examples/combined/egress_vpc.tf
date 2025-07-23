# ----------------------------
# EGRESS NIPRNET VPC MODULE
# ----------------------------

locals {
  egress_primary_cidr   = var.egress_cidr_blocks[0]
  egress_secondary_cidrs = slice(var.egress_cidr_blocks, 1, length(var.egress_cidr_blocks))
}

resource "aws_vpc" "egress" {
  cidr_block           = local.egress_primary_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = var.egress_name })
}

resource "aws_vpc_ipv4_cidr_block_association" "egress_secondary" {
  for_each   = toset(local.egress_secondary_cidrs)
  vpc_id     = aws_vpc.egress.id
  cidr_block = each.key
}

resource "aws_subnet" "egress" {
  for_each = {
    nat_a      = { cidr = var.egress_nat_subnet_cidrs[0], az = var.azs[0] }
    nat_b      = { cidr = var.egress_nat_subnet_cidrs[1], az = var.azs[1] }
    tgw_vdss_a = { cidr = var.egress_tgw_vdss_subnet_cidrs[0], az = var.azs[0] }
    tgw_vdss_b = { cidr = var.egress_tgw_vdss_subnet_cidrs[1], az = var.azs[1] }
    tgw_edge_a = { cidr = var.egress_tgw_edge_subnet_cidrs[0], az = var.azs[0] }
    tgw_edge_b = { cidr = var.egress_tgw_edge_subnet_cidrs[1], az = var.azs[1] }
  }
  vpc_id            = aws_vpc.egress.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(var.tags, { Name = "${var.egress_name}-${each.key}" })
  depends_on        = [aws_vpc_ipv4_cidr_block_association.egress_secondary]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "egress_vdss" {
  vpc_id             = aws_vpc.egress.id
  subnet_ids         = [
    aws_subnet.egress["tgw_vdss_a"].id,
    aws_subnet.egress["tgw_vdss_b"].id
  ]
  transit_gateway_id = var.tgw_vdss_id
  tags               = merge(var.tags, { Name = "${var.egress_name}-vdss-attachment" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "egress_edge" {
  vpc_id             = aws_vpc.egress.id
  subnet_ids         = [
    aws_subnet.egress["tgw_edge_a"].id,
    aws_subnet.egress["tgw_edge_b"].id
  ]
  transit_gateway_id = var.tgw_edge_id
  tags               = merge(var.tags, { Name = "${var.egress_name}-edge-attachment" })
}

resource "aws_route_table" "egress_private" {
  vpc_id = aws_vpc.egress.id
  tags   = merge(var.tags, { Name = "${var.egress_name}-private-rt" })
}

resource "aws_route" "egress_private_vdss" {
  route_table_id         = aws_route_table.egress_private.id
  destination_cidr_block = var.private_rfc_1918_cidr
  transit_gateway_id     = var.tgw_vdss_id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.egress_vdss]
}

