

---

## 1. Module: `modules/aws_saml_account`

This module:

* Creates an **Azure AD Application** and **Service Principal** based on the **AWS Single-Account Access** template.
* Creates **app roles** for each AWS IAM role you specify.
* Creates **groups** per role.
* Assigns **group → app role → service principal**.
* Automatically builds the SAML role value:
  `arn:${partition}:iam::${account_id}:role/${iam_role_name},arn:${partition}:iam::${account_id}:saml-provider/${saml_provider_name}`

### `modules/aws_saml_account/variables.tf`

```hcl
variable "app_display_name" {
  description = "Display name of the Azure AD application / Enterprise app for this AWS account"
  type        = string
}

variable "app_notes" {
  description = "Notes for the Azure AD application"
  type        = string
  default     = ""
}

variable "account_id" {
  description = "AWS account ID for this SAML app"
  type        = string
}

variable "saml_provider_name" {
  description = "Name of the AWS SAML provider in this account (NOT the full ARN)"
  type        = string
}

variable "partition" {
  description = "AWS partition (aws, aws-us-gov, aws-cn, etc.)"
  type        = string
  default     = "aws"
}

# roles:
# map key = logical name (e.g. "admin", "readonly", "cyber")
# each value defines IAM role name, app role display/description, and group name.
variable "roles" {
  description = "Map of logical role names to AWS IAM roles and Entra app role/group settings"
  type = map(object({
    iam_role_name         = string   # e.g. "AWS-Admin"
    app_role_display_name = string   # e.g. "AWS Admin"
    app_role_description  = string   # e.g. "AWS Admin role via SAML"
    group_name            = string   # e.g. "aws_saml_Admin"
  }))
}
```

### `modules/aws_saml_account/main.tf`

```hcl
data "azuread_client_config" "current" {}

# AWS Single-Account Access gallery template
data "azuread_application_template" "aws_account_access" {
  display_name = "AWS Single-Account Access"
}

###############################
# Application + Service Principal
###############################

resource "azuread_application" "aws_saml" {
  display_name     = var.app_display_name
  notes            = var.app_notes
  template_id      = data.azuread_application_template.aws_account_access.id
  sign_in_audience = "AzureADMyOrg"

  owners = [
    data.azuread_client_config.current.object_id,
  ]

  lifecycle {
    # Let the gallery/template manage some behind-the-scenes stuff
    ignore_changes = [
      identifier_uris,
      app_role,
    ]
  }
}

resource "azuread_service_principal" "aws_saml" {
  client_id                     = azuread_application.aws_saml.client_id
  use_existing                  = true
  preferred_single_sign_on_mode = "saml"
  app_role_assignment_required  = true

  feature_tags {
    enterprise = true
    gallery    = true
  }
}

###############################
# Roles, groups, assignments
###############################

# Build the SAML value: role-arn,provider-arn for each role
locals {
  aws_roles = {
    for name, cfg in var.roles : name => {
      iam_role_name          = cfg.iam_role_name
      app_role_display_name  = cfg.app_role_display_name
      app_role_description   = cfg.app_role_description
      group_name             = cfg.group_name
      saml_role_value        = "arn:${var.partition}:iam::${var.account_id}:role/${cfg.iam_role_name},arn:${var.partition}:iam::${var.account_id}:saml-provider/${var.saml_provider_name}"
    }
  }
}

# Unique UUID per app role
resource "random_uuid" "role_ids" {
  for_each = local.aws_roles
}

# App roles on the application
resource "azuread_application_app_role" "roles" {
  for_each             = local.aws_roles
  application_id       = azuread_application.aws_saml.id
  role_id              = random_uuid.role_ids[each.key].id
  description          = each.value.app_role_description
  value                = each.value.saml_role_value      # <-- AWS SAML role string
  display_name         = each.value.app_role_display_name
  allowed_member_types = ["User", "Group"]
}

# Entra groups corresponding to each app role
resource "azuread_group" "groups" {
  for_each                = local.aws_roles
  display_name            = each.value.group_name
  security_enabled        = true
  visibility              = "Private"
  description             = "Group for ${each.value.app_role_display_name} (${var.app_display_name})"
  prevent_duplicate_names = true
}

# Assign group -> app role -> service principal
resource "azuread_app_role_assignment" "assignments" {
  for_each            = local.aws_roles
  app_role_id         = azuread_application_app_role.roles[each.key].role_id
  principal_object_id = azuread_group.groups[each.key].object_id
  resource_object_id  = azuread_service_principal.aws_saml.object_id
}
```

### `modules/aws_saml_account/outputs.tf` (optional but handy)

```hcl
output "application_id" {
  description = "Object ID of the Azure AD application"
  value       = azuread_application.aws_saml.id
}

output "service_principal_id" {
  description = "Object ID of the service principal (Enterprise app)"
  value       = azuread_service_principal.aws_saml.object_id
}

output "group_ids" {
  description = "Map of logical role name -> group object ID"
  value = {
    for name, g in azuread_group.groups :
    name => g.object_id
  }
}
```

---

## 2. Root Usage: Multiple Accounts, Multiple Roles

Now in your **root module**, you define your accounts + roles once and let Terraform fan out.

### `variables.tf` in root

```hcl
variable "aws_saml_accounts" {
  description = "All AWS accounts we want Entra SAML apps for"
  type = map(object({
    account_id         = string
    saml_provider_name = string           # e.g. "EntraID" (must match AWS IAM provider name)
    app_display_name   = string           # e.g. "aws-prod-saml"
    app_notes          = string
    partition          = string           # e.g. "aws-us-gov" or "aws"

    roles = map(object({
      iam_role_name         = string
      app_role_display_name = string
      app_role_description  = string
      group_name            = string
    }))
  }))
}
```

### `main.tf` in root – example values for 2 accounts

```hcl
# Example concrete values – you can move this to *.tfvars later
locals {
  aws_saml_accounts = {
    prod = {
      account_id         = "111111111111"
      saml_provider_name = "EntraID"
      app_display_name   = "aws-prod-saml"
      app_notes          = "Prod AWS SAML app"
      partition          = "aws-us-gov"  # or "aws"

      roles = {
        admin = {
          iam_role_name         = "AWS-Admin"
          app_role_display_name = "AWS Admin"
          app_role_description  = "AWS Admin role via SAML (prod)"
          group_name            = "aws_prod_Admin"
        }
        readonly = {
          iam_role_name         = "AWS-ReadOnly"
          app_role_display_name = "AWS ReadOnly"
          app_role_description  = "AWS ReadOnly role via SAML (prod)"
          group_name            = "aws_prod_ReadOnly"
        }
        cyber = {
          iam_role_name         = "AWS-Cyber"
          app_role_display_name = "AWS Cyber"
          app_role_description  = "AWS Cyber/Security role via SAML (prod)"
          group_name            = "aws_prod_Cyber"
        }
      }
    }

    dev = {
      account_id         = "222222222222"
      saml_provider_name = "EntraID"
      app_display_name   = "aws-dev-saml"
      app_notes          = "Dev AWS SAML app"
      partition          = "aws-us-gov"

      roles = {
        admin = {
          iam_role_name         = "AWS-Admin"
          app_role_display_name = "AWS Admin"
          app_role_description  = "AWS Admin role via SAML (dev)"
          group_name            = "aws_dev_Admin"
        }
        readonly = {
          iam_role_name         = "AWS-ReadOnly"
          app_role_display_name = "AWS ReadOnly"
          app_role_description  = "AWS ReadOnly role via SAML (dev)"
          group_name            = "aws_dev_ReadOnly"
        }
        cyber = {
          iam_role_name         = "AWS-Cyber"
          app_role_display_name = "AWS Cyber"
          app_role_description  = "AWS Cyber/Security role via SAML (dev)"
          group_name            = "aws_dev_Cyber"
        }
      }
    }
  }
}
```

### Calling the module with `for_each`

```hcl
module "aws_saml_accounts" {
  source = "./modules/aws_saml_account"

  for_each           = local.aws_saml_accounts
  account_id         = each.value.account_id
  saml_provider_name = each.value.saml_provider_name
  app_display_name   = each.value.app_display_name
  app_notes          = each.value.app_notes
  partition          = each.value.partition
  roles              = each.value.roles
}
```

This will:

* Create **one Entra app/SP per AWS account**.
* For each account, create **Admin**, **ReadOnly**, **Cyber** (or whatever roles you define).
* Create **named groups** like `aws_prod_Admin`, `aws_dev_ReadOnly`, etc.
* Wire each group to the correct app role / Enterprise app for that account.

---


* Add an optional **claims_mapping_policy** into the module (if you want to override the default `user.assignedroles → Role` behavior).
* Or add an output showing the computed **role SAML values**, so you can use them to double-check IAM trust policies and AWS side config.
