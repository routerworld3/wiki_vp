
locals {
  ingress_niprnet_config = var.network_config.ingress_niprnet
  # Create the AZ-keyed maps from the readable JSON
  ingress_niprnet_bcap_attach_subnets       = { for k, v in local.ingress_niprnet_config.bcap_attach_subnets : v.availability_zone => v }
  ingress_niprnet_public_subnets            = { for k, v in local.ingress_niprnet_config.public_subnets : v.availability_zone => v }
  ingress_niprnet_private_subnets           = { for k, v in local.ingress_niprnet_config.private_subnets : v.availability_zone => v }
  ingress_niprnet_inspection_attach_subnets = { for k, v in local.ingress_niprnet_config.inspection_attach_subnets : v.availability_zone => v }
}

/*======================================
Niprnet ingress VPC and subnetting
======================================*/

resource "aws_vpc" "ingress_niprnet" {
  cidr_block           = var.network_config.ingress_niprnet.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "${local.name_prefix}ingress-niprnet"
    lifecycle = var.account_lifecycle
    function  = "shared"
    domain    = "nipr"
  }
}

# Primary cidr is rfc1918, secondary is nipr space
resource "aws_vpc_ipv4_cidr_block_association" "ingress_niprnet_secondary" {
  vpc_id     = aws_vpc.ingress_niprnet.id
  cidr_block = var.network_config.ingress_niprnet.secondary_cidr
}

data "aws_route_table" "ingress_niprnet_default" {
  vpc_id = aws_vpc.ingress_niprnet.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

/*========================================
Bcap attachment subnet resources
========================================*/

# Create subnets based on how many azs we deploy to
resource "aws_subnet" "ingress_niprnet_bcap_attach" {
  for_each = local.ingress_niprnet_bcap_attach_subnets

  vpc_id            = aws_vpc.ingress_niprnet.id
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr

  tags = {
    Name = "${local.name_prefix}ingress-niprnet-bcap-attach"
  }
}

/*========================================
Public (NLB) subnet resources
========================================*/

# Create subnets based on how many azs we deploy to
resource "aws_subnet" "ingress_niprnet_public" {
  for_each = local.ingress_niprnet_public_subnets

  vpc_id            = aws_vpc.ingress_niprnet.id
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr

  tags = {
    Name = "${local.name_prefix}ingress-niprnet-public"
  }

  depends_on = [aws_vpc_ipv4_cidr_block_association.ingress_niprnet_secondary]
}

/*========================================
Private (ALB) subnet resources
========================================*/

# Create subnets based on how many azs we deploy to
resource "aws_subnet" "ingress_niprnet_private" {
  for_each = local.ingress_niprnet_private_subnets

  vpc_id            = aws_vpc.ingress_niprnet.id
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr

  tags = {
    Name = "${local.name_prefix}ingress-niprnet-private"
  }
}

/*========================================
Inspection attachment subnet resources
========================================*/

# Create subnets based on how many azs we deploy to
resource "aws_subnet" "ingress_niprnet_inspection_attach" {
  for_each = local.ingress_niprnet_inspection_attach_subnets

  vpc_id            = aws_vpc.ingress_niprnet.id
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr

  tags = {
    Name = "${local.name_prefix}ingress-niprnet-inspection-attach"
  }
}

# Make path to inspection network
resource "aws_route" "ingress_niprnet_inspection_attach_to_inspection" {
  route_table_id             = data.aws_route_table.ingress_niprnet_default.id
  destination_prefix_list_id = aws_ec2_managed_prefix_list.rfc1918.id
  transit_gateway_id         = aws_ec2_transit_gateway.inspection.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.ingress_niprnet_inspection_attach]
}

# Get connectivity to inspection network
resource "aws_ec2_transit_gateway_vpc_attachment" "ingress_niprnet_inspection_attach" {
  subnet_ids         = [for subnet in aws_subnet.ingress_niprnet_inspection_attach : subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.inspection.id
  vpc_id             = aws_vpc.ingress_niprnet.id

  tags = {
    Name = "${local.name_prefix}ingress-niprnet-inspection-attach"
  }

  depends_on = [aws_ec2_transit_gateway.inspection]
}
