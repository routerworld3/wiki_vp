``` terraform
data "aws_organizations_organization" "this" {}

locals {
  root_id = data.aws_organizations_organization.this.roots[0].id
}

data "aws_organizations_organizational_unit_descendant_organizational_units" "all" {
  parent_id = local.root_id
}

locals {
  ou_ids = toset([
    for ou in data.aws_organizations_organizational_unit_descendant_organizational_units.all.children :
    ou.id
  ])

  member_account_ids = toset([
    for account in data.aws_organizations_organization.this.non_master_accounts :
    account.id
  ])

  all_scp_targets = setunion(
    toset([local.root_id]),
    local.ou_ids,
    local.member_account_ids
  )
}

resource "aws_organizations_policy" "scp_a" {
  name        = "SCP-A"
  description = "Enterprise authorization and guardrail SCP"

  content = file("${path.module}/policies/scp-a.json")
}

resource "aws_organizations_policy_attachment" "scp_a_all_targets" {
  for_each = local.all_scp_targets

  policy_id = aws_organizations_policy.scp_a.id
  target_id = each.value
}

locals {
  new_scp_targets = setsubtract(
    local.all_scp_targets,
    toset([aws_organizations_organizational_unit.parent.id])
  )
}

resource "aws_organizations_policy_attachment" "scp_a_all_targets" {
  for_each = local.new_scp_targets

  policy_id = aws_organizations_policy.scp_a.id
  target_id = each.value
}
```
