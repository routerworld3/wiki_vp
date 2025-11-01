locals {
  attachment_patterns = {
    ingress = { vpc_key = "ingress_niprnet", rt_key = "main", name_suffix = "ingress-niprnet-private" }
    egress  = { vpc_key = "egress_niprnet", rt_key = "public", name_suffix = "egress-niprnet-private" }
  }
  environment_details = {
    cui  = { module = module.inspection, prefix = "" }
    nnpi = { module = module.nnpi_inspection, prefix = "NNPI-" }
  }

  # --- REFACTORED SECTION ---
  bcap_attachments = merge([
    # The outer loop now iterates over the new bcap_connections map
    for env_key, patterns_to_apply in var.bcap_connections : {
      # The inner loop iterates over the list of patterns for that environment (e.g., ["egress"])
      for pattern_key in patterns_to_apply :
      "${env_key}-${pattern_key}" => {
        vpc_id                = local.environment_details[env_key].module[local.attachment_patterns[pattern_key].vpc_key].vpc_id
        console_name          = "${local.environment_details[env_key].prefix}${local.attachment_patterns[pattern_key].name_suffix}"
        subnet_ids_list       = values(local.environment_details[env_key].module[local.attachment_patterns[pattern_key].vpc_key].bcap_attach_subnets)
        target_route_table_id = local.environment_details[env_key].module[local.attachment_patterns[pattern_key].vpc_key].route_table_ids[local.attachment_patterns[pattern_key].rt_key]
      }
    }
  ]...)
}

data "aws_ec2_transit_gateway" "disa_edge" {
  filter {
    name   = "options.amazon-side-asn"
    values = ["64555"]
  }
}

/*==============================
BCAP TGW RAM Acceptance
==============================*/

# does not apply here since we are in bw org
# resource "aws_ram_resource_share_accepter" "disa_edge_tgw" {
#   share_arn = var.bcap_share_arn
# }

/*==============================
BCAP TGW Attachments & Routes
==============================*/

# This single resource block creates all four VPC attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "bcap" {
  for_each = local.bcap_attachments

  # Reference the pre-calculated list directly
  subnet_ids = each.value.subnet_ids_list

  transit_gateway_id = data.aws_ec2_transit_gateway.disa_edge.id
  vpc_id             = each.value.vpc_id

  tags = {
    Name = each.value.console_name
  }
}

resource "aws_route" "bcap" {
  for_each = local.bcap_attachments

  # Reference the pre-calculated route table ID directly
  route_table_id = each.value.target_route_table_id

  transit_gateway_id     = data.aws_ec2_transit_gateway.disa_edge.id
  destination_cidr_block = "0.0.0.0/0"

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.bcap
  ]
}


# TODO: Whats the best refactor on this bcap code?

# locals {
#   bcap_attachments = {
#     cui-ingress = {
#       vpc_id                = module.inspection.ingress_niprnet.vpc_id
#       console_name          = "ingress-niprnet-private"
#       subnet_ids_list       = values(module.inspection.ingress_niprnet.bcap_attach_subnets)
#       target_route_table_id = module.inspection.ingress_niprnet.route_table_ids["main"]
#     }

#     cui-egress = {
#       vpc_id                = module.inspection.egress_niprnet.vpc_id
#       console_name          = "egress-niprnet-private"
#       subnet_ids_list       = values(module.inspection.egress_niprnet.bcap_attach_subnets)
#       target_route_table_id = module.inspection.egress_niprnet.route_table_ids["public"]
#     }

#     nnpi-ingress = {
#       vpc_id                = module.nnpi_inspection.ingress_niprnet.vpc_id
#       console_name          = "NNPI-ingress-niprnet-private"
#       subnet_ids_list       = values(module.nnpi_inspection.ingress_niprnet.bcap_attach_subnets)
#       target_route_table_id = module.nnpi_inspection.ingress_niprnet.route_table_ids["main"]
#     }

#     nnpi-egress = {
#       vpc_id                = module.nnpi_inspection.egress_niprnet.vpc_id
#       console_name          = "NNPI-egress-niprnet-private"
#       subnet_ids_list       = values(module.nnpi_inspection.egress_niprnet.bcap_attach_subnets)
#       target_route_table_id = module.nnpi_inspection.egress_niprnet.route_table_ids["public"]
#     }
#   }
# }
