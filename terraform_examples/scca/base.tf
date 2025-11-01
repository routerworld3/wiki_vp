/*===
Main TF File.

This is intended for things like "global" data calls and shared local blocks for things like tags.
===*/

# Data Calls for the default provider
data "aws_caller_identity" "default" {}
data "aws_partition" "default" {}
data "aws_region" "default" {}

### Custom Data Calls
# These data calls are used commonly to build KMS and IAM policies
data "aws_iam_roles" "iac_role_verify" {
  path_prefix = "/github-auth/"
  name_regex  = "${var.account_lifecycle}-verify$"
}

data "aws_iam_roles" "iac_role_deploy" {
  path_prefix = "/github-auth/"
  name_regex  = "${var.account_lifecycle}-deploy$"
}

# Get Organization ID
data "aws_ram_resource_share" "organization_id" {
  name           = "ORGANIZATION_ID"
  resource_owner = "OTHER-ACCOUNTS"
}

data "aws_ssm_parameter" "organization_id" {
  name = data.aws_ram_resource_share.organization_id.resource_arns[0]
}

locals {
  network_file = var.account_lifecycle == "main" ? "network.json" : "network_test.json"
  network_data = jsondecode(file("${path.module}/${local.network_file}"))
}

module "inspection" {
  source                               = "git::https://git.aws.example.org/NAVSEA-Bluewater/module-opentofu-aws-scca-inspection?ref=v1"
  network_config                       = local.network_data.cui
  account_lifecycle                    = var.account_lifecycle
  naval_nuclear_propulsion_information = false
  firewall_policy_arn                  = aws_networkfirewall_firewall_policy.bluewater_baseline.arn
}

module "nnpi_inspection" {
  source                               = "git::https://git.aws.example.org/NAVSEA-Bluewater/module-opentofu-aws-scca-inspection?ref=v1"
  network_config                       = local.network_data.nnpi
  account_lifecycle                    = var.account_lifecycle
  naval_nuclear_propulsion_information = true
  firewall_policy_arn                  = aws_networkfirewall_firewall_policy.bluewater_baseline.arn
}
