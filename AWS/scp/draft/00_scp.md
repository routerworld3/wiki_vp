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


```

Yes — and that is actually the cleaner long-term design.

Instead of keeping one resource for the Parent OU and another `for_each` resource for everything else, convert the **existing attachment resource itself** into a `for_each` resource that manages **all targets**.

The only thing to watch is **Terraform state addressing**.

Suppose you currently have:

```hcl
resource "aws_organizations_policy_attachment" "scp_a" {
  policy_id = aws_organizations_policy.scp_a.id
  target_id = aws_organizations_organizational_unit.parent.id
}
```

and you change it to:

```hcl
resource "aws_organizations_policy_attachment" "scp_a" {
  for_each = local.all_scp_targets

  policy_id = aws_organizations_policy.scp_a.id
  target_id = each.value
}
```

Terraform now sees different resource addresses.

Before:

```text
aws_organizations_policy_attachment.scp_a
```

After:

```text
aws_organizations_policy_attachment.scp_a["ou-abcd-parent"]
aws_organizations_policy_attachment.scp_a["ou-abcd-child1"]
aws_organizations_policy_attachment.scp_a["111111111111"]
...
```

So you need to tell Terraform:

> The old singleton attachment is now one instance of the new `for_each` resource.

### Option 1 — use a `moved` block

If you know the Parent OU ID, this is very clean:

```hcl
moved {
  from = aws_organizations_policy_attachment.scp_a
  to   = aws_organizations_policy_attachment.scp_a["ou-abcd-12345678"]
}
```

Then your configuration becomes:

```hcl
locals {
  all_scp_targets = setunion(
    toset([local.root_id]),
    local.ou_ids,
    local.member_account_ids
  )
}

resource "aws_organizations_policy_attachment" "scp_a" {
  for_each = local.all_scp_targets

  policy_id = aws_organizations_policy.scp_a.id
  target_id = each.value
}

moved {
  from = aws_organizations_policy_attachment.scp_a
  to   = aws_organizations_policy_attachment.scp_a["ou-abcd-12345678"]
}
```

Terraform will interpret this as:

```text
Existing:

SCP-A → Parent OU
        │
        │ moved
        ▼
scp_a["ou-abcd-12345678"]

New:
scp_a["r-root"]
scp_a["ou-abcd-parent"]       ← existing attachment retained
scp_a["ou-abcd-child"]
scp_a["111111111111"]
scp_a["222222222222"]
```

That means the existing Parent OU attachment should **not be destroyed and recreated**.

### Option 2 — use a map with friendly keys

I actually prefer this if you are refactoring a larger Organizations module because the Terraform addresses are easier to read.

Instead of:

```hcl
for_each = local.all_scp_targets
```

you can create:

```hcl
locals {
  scp_a_targets = merge(
    {
      root   = local.root_id
      parent = aws_organizations_organizational_unit.parent.id
    },

    {
      for ou_id in local.ou_ids :
      "ou-${ou_id}" => ou_id
      if ou_id != aws_organizations_organizational_unit.parent.id
    },

    {
      for account_id in local.member_account_ids :
      "account-${account_id}" => account_id
    }
  )
}
```

Then:

```hcl
resource "aws_organizations_policy_attachment" "scp_a" {
  for_each = local.scp_a_targets

  policy_id = aws_organizations_policy.scp_a.id
  target_id = each.value
}
```

Now Terraform state looks like:

```text
scp_a["root"]
scp_a["parent"]
scp_a["ou-ou-abcd-1234"]
scp_a["account-111111111111"]
scp_a["account-222222222222"]
```

And the move is very simple:

```hcl
moved {
  from = aws_organizations_policy_attachment.scp_a
  to   = aws_organizations_policy_attachment.scp_a["parent"]
}
```

I prefer this because you don't have to hard-code the actual Parent OU ID in the `moved` block.

### Your resulting migration

You no longer need this:

```hcl
locals {
  new_scp_targets = setsubtract(
    local.all_scp_targets,
    toset([
      aws_organizations_organizational_unit.parent.id
    ])
  )
}
```

Instead:

```hcl
locals {
  all_scp_targets = setunion(
    toset([local.root_id]),
    local.ou_ids,
    local.member_account_ids
  )
}
```

and:

```hcl
resource "aws_organizations_policy_attachment" "scp_a" {
  for_each = local.all_scp_targets

  policy_id = aws_organizations_policy.scp_a.id
  target_id = each.value
}
```

Then migrate the old state address.

### Very important: run `terraform plan`

You want the plan to look conceptually like:

```text
# Existing attachment moved
aws_organizations_policy_attachment.scp_a
  -> aws_organizations_policy_attachment.scp_a["ou-parent"]

# New attachments
+ scp_a["r-root"]
+ scp_a["ou-child-1"]
+ scp_a["ou-child-2"]
+ scp_a["111111111111"]
+ scp_a["222222222222"]
```

You **do not** want:

```text
- SCP-A from Parent
+ SCP-A to Parent
```

If you see destroy/recreate for the Parent attachment, stop and fix the state migration first.

So yes: **convert your existing attachment resource to `for_each` and let that one resource manage Root + all OUs + all member accounts.** That is cleaner than maintaining a special-case exclusion for the Parent OU.
