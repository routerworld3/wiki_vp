/*========================================
Inspection transit gateway outputs
========================================*/

output "inspection_transit_gateway" {
  description = "Outputs for the inspection Transit Gateway and its route tables."
  value = {
    id                 = aws_ec2_transit_gateway.inspection.id
    ingress_rt_id      = aws_ec2_transit_gateway_route_table.ingress.id
    egress_rt_id       = aws_ec2_transit_gateway_route_table.egress.id
    pre_inspect_rt_id  = aws_ec2_transit_gateway_route_table.pre_inspect.id
    post_inspect_rt_id = aws_ec2_transit_gateway_route_table.post_inspect.id
  }
}

/*========================================
Inspection network firewall outputs
========================================*/

output "inspection_network_firewall" {
  description = "Outputs for the inspection Network Firewall."
  value = {
    nfw_arn        = aws_networkfirewall_firewall.inspection.arn
    nfw_policy_arn = aws_networkfirewall_firewall.inspection.firewall_policy_arn
  }
}

/*========================================
Ingress niprnet vpc outputs
========================================*/

output "ingress_niprnet" {
  description = "All outputs for the ingress NIPRNet VPC."
  value = {
    vpc_id         = aws_vpc.ingress_niprnet.id
    primary_cidr   = aws_vpc.ingress_niprnet.cidr_block
    secondary_cidr = aws_vpc_ipv4_cidr_block_association.ingress_niprnet_secondary.cidr_block

    # Create a map of { "az" = "subnet_id" } for the subnets
    bcap_attach_subnets = {
      for subnet in aws_subnet.ingress_niprnet_bcap_attach : subnet.availability_zone => subnet.id
    }
    public_subnets = {
      for subnet in aws_subnet.ingress_niprnet_public : subnet.availability_zone => subnet.id
    }
    private_subnets = {
      for subnet in aws_subnet.ingress_niprnet_private : subnet.availability_zone => subnet.id
    }
    inspection_attach_subnets = {
      for subnet in aws_subnet.ingress_niprnet_inspection_attach : subnet.availability_zone => subnet.id
    }

    route_table_ids = {
      main = data.aws_route_table.ingress_niprnet_default.id
    }
  }
}

/*========================================
Egress niprnet vpc outputs
========================================*/

output "egress_niprnet" {
  description = "All outputs for the egress NIPRNet VPC."
  value = {
    vpc_id         = aws_vpc.egress_niprnet.id
    primary_cidr   = aws_vpc.egress_niprnet.cidr_block
    secondary_cidr = aws_vpc_ipv4_cidr_block_association.egress_niprnet_secondary.cidr_block

    # Create a map of { "az" = "subnet_id" } for the subnets
    bcap_attach_subnets = {
      for subnet in aws_subnet.egress_niprnet_bcap_attach : subnet.availability_zone => subnet.id
    }
    public_subnets = {
      for subnet in aws_subnet.egress_niprnet_public : subnet.availability_zone => subnet.id
    }
    inspection_attach_subnets = {
      for subnet in aws_subnet.egress_niprnet_inspection_attach : subnet.availability_zone => subnet.id
    }

    route_table_ids = {
      public = aws_route_table.egress_niprnet_public.id
      # Create a map of { "az" = "route_table_id" } for the private route tables
      private = {
        for key, rt in aws_route_table.egress_niprnet_inspection_attach :
        aws_subnet.egress_niprnet_inspection_attach[key].availability_zone => rt.id
      }
    }
  }
}
