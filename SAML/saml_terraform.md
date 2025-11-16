

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


Nice, this will scale really well across your 5–10 accounts.

Below is an **updated module** that:

* Keeps the same behavior as before.
* Adds an **optional claims mapping policy** for AWS:

  * Maps `user.assignedroles` → SAML `Role` claim (`https://aws.amazon.com/SAML/Attributes/Role`)
  * Maps `userprincipalname` (by default) → SAML `RoleSessionName`
  * Optional mapping for `SessionDuration`
* Uses **sensible defaults**, but exposes knobs so you can tune if needed.
* Includes a **README.md** to document how to use it.

I’ll show:

1. Updated **module files** (`variables.tf`, `main.tf`, `outputs.tf`)
2. A **README.md** for `modules/aws_saml_account`
3. (Root usage from before still works; I’ll only tweak a tiny bit to mention claims policy)

---

## 1. Module: `modules/aws_saml_account/variables.tf`

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
  # For you, GovCloud is common; override in root if needed.
  default     = "aws-us-gov"
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

#########################################
# Claims mapping policy configuration
#########################################

variable "create_claims_mapping_policy" {
  description = "Whether to create and assign a claims mapping policy for AWS SAML attributes"
  type        = bool
  default     = true
}

variable "role_session_name_source_id" {
  description = "User property ID to use for RoleSessionName (typically 'userprincipalname' or 'mail')"
  type        = string
  default     = "userprincipalname"
}

variable "session_duration_source_id" {
  description = "User property ID to use for SessionDuration (e.g. extensionAttribute1). Leave empty to omit SessionDuration."
  type        = string
  default     = ""
}
```

---

## 2. Module: `modules/aws_saml_account/main.tf`

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
    # Let the gallery/template / portal manage some behind-the-scenes stuff
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

#############################################
# Claims mapping policy for AWS SAML (optional)
#############################################

# Build the ClaimsSchema for the policy
locals {
  # Base: Role + RoleSessionName
  claims_schema_base = [
    {
      # user.assignedroles -> AWS Role attribute
      "Source"        = "user"
      "ID"            = "assignedroles"
      "SamlClaimType" = "https://aws.amazon.com/SAML/Attributes/Role"
    },
    {
      # user.<role_session_name_source_id> -> AWS RoleSessionName
      "Source"        = "user"
      "ID"            = var.role_session_name_source_id
      "SamlClaimType" = "https://aws.amazon.com/SAML/Attributes/RoleSessionName"
    }
  ]

  claims_schema = var.session_duration_source_id == "" ?
    local.claims_schema_base :
    concat(
      local.claims_schema_base,
      [
        {
          # user.<session_duration_source_id> -> AWS SessionDuration
          "Source"        = "user"
          "ID"            = var.session_duration_source_id
          "SamlClaimType" = "https://aws.amazon.com/SAML/Attributes/SessionDuration"
        }
      ]
    )
}

resource "azuread_claims_mapping_policy" "aws_saml" {
  count       = var.create_claims_mapping_policy ? 1 : 0
  display_name = "${var.app_display_name} AWS Claims Policy"

  # This JSON structure follows the ClaimsMappingPolicy schema used by Entra/Graph.
  definition = [
    jsonencode({
      ClaimsMappingPolicy = {
        Version              = 1
        IncludeBasicClaimSet = "true"
        ClaimsSchema         = local.claims_schema
      }
    })
  ]
}

resource "azuread_service_principal_claims_mapping_policy_assignment" "aws_saml" {
  count                   = var.create_claims_mapping_policy ? 1 : 0
  claims_mapping_policy_id = azuread_claims_mapping_policy.aws_saml[0].id
  service_principal_id     = azuread_service_principal.aws_saml.object_id
}
```

---

## 3. Module: `modules/aws_saml_account/outputs.tf`

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

output "claims_mapping_policy_id" {
  description = "ID of the claims mapping policy (if created)"
  value       = try(azuread_claims_mapping_policy.aws_saml[0].id, null)
}
```

---

## 4. README: `modules/aws_saml_account/README.md`

````markdown
# aws_saml_account Terraform Module

This module creates a **Microsoft Entra (Azure AD)** Enterprise Application for a **single AWS account** using the **“AWS Single-Account Access”** gallery template, and wires it up for SAML-based role federation.

Per account, it creates:

- An **Azure AD Application** and corresponding **Service Principal**.
- One or more **App Roles**, each representing an AWS IAM role.
- A matching **Azure AD security group** per role.
- **App role assignments** from each group to the AWS Enterprise app.
- An optional **claims mapping policy** that maps:
  - `user.assignedroles` → AWS `Role` SAML attribute
  - `userprincipalname` (by default) → AWS `RoleSessionName`
  - Optional user attribute → AWS `SessionDuration`

You call this module **once per AWS account**, typically via `for_each` in your root module.

---

## Inputs

### Required

| Name                | Type   | Description |
|---------------------|--------|-------------|
| `app_display_name`  | string | Display name of the Entra application / Enterprise app for this AWS account. |
| `account_id`        | string | AWS account ID (e.g. `111111111111`). |
| `saml_provider_name`| string | Name of the AWS SAML provider in this account (the name portion of the ARN, not the full ARN). |
| `roles`             | map(object) | Map of logical role keys to IAM role and group config (see below). |

`roles` is a map of objects:

```hcl
roles = {
  admin = {
    iam_role_name         = "AWS-Admin"         # IAM role name in this account
    app_role_display_name = "AWS Admin"         # Display name shown in Entra
    app_role_description  = "AWS Admin via SAML"
    group_name            = "aws_prod_Admin"    # Group name to create in Entra
  }
  readonly = {
    iam_role_name         = "AWS-ReadOnly"
    app_role_display_name = "AWS ReadOnly"
    app_role_description  = "AWS ReadOnly via SAML"
    group_name            = "aws_prod_ReadOnly"
  }
}
````

For each role:

* The module constructs the required AWS SAML attribute value:

  ```text
  arn:${partition}:iam::${account_id}:role/${iam_role_name},arn:${partition}:iam::${account_id}:saml-provider/${saml_provider_name}
  ```

* This string becomes the **app role value** and ends up in the SAML `Role` attribute.

### Optional Inputs

| Name                           | Type   | Default               | Description                                                                                                        |
| ------------------------------ | ------ | --------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `app_notes`                    | string | `""`                  | Optional notes/comment for the application.                                                                        |
| `partition`                    | string | `"aws-us-gov"`        | AWS partition (`aws`, `aws-us-gov`, `aws-cn`, etc.).                                                               |
| `create_claims_mapping_policy` | bool   | `true`                | Whether to create & assign a claims mapping policy.                                                                |
| `role_session_name_source_id`  | string | `"userprincipalname"` | User property ID to use for `RoleSessionName`. Common values: `userprincipalname`, `mail`.                         |
| `session_duration_source_id`   | string | `""`                  | User property ID to use for `SessionDuration`. Leave empty to omit this attribute (AWS will use default duration). |

**Note on `source_id`** values:

* These map to **user properties** as seen by Entra / Graph in a claims mapping policy.
* `userprincipalname` and `assignedroles` are standard IDs.
* For custom duration, you can store a numeric string (e.g. `"3600"`) in an extension attribute such as `extensionAttribute1` and set `session_duration_source_id = "extensionattribute1"`.

---

## Outputs

| Name                       | Description                                                 |
| -------------------------- | ----------------------------------------------------------- |
| `application_id`           | Object ID of the Azure AD application.                      |
| `service_principal_id`     | Object ID of the service principal (Enterprise app).        |
| `group_ids`                | Map of logical role name → group object ID.                 |
| `claims_mapping_policy_id` | ID of the claims mapping policy (or `null` if not created). |

---

## Example Usage (Single Account)

```hcl
module "aws_prod_saml" {
  source = "./modules/aws_saml_account"

  app_display_name   = "aws-prod-saml"
  app_notes          = "Prod AWS SAML app"
  account_id         = "111111111111"
  saml_provider_name = "EntraID"      # must match AWS IAM SAML provider name
  partition          = "aws-us-gov"   # override if not GovCloud

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

  # Optional tuning
  create_claims_mapping_policy = true
  role_session_name_source_id  = "userprincipalname"
  # session_duration_source_id = "extensionattribute1"  # if you store per-user duration
}
```

---

## Example Usage (Multiple Accounts with for_each)

In your **root module**, define a map of accounts:

```hcl
locals {
  aws_saml_accounts = {
    prod = {
      account_id         = "111111111111"
      saml_provider_name = "EntraID"
      app_display_name   = "aws-prod-saml"
      app_notes          = "Prod AWS SAML app"
      partition          = "aws-us-gov"

      roles = {
        admin = {
          iam_role_name         = "AWS-Admin"
          app_role_display_name = "AWS Admin"
          app_role_description  = "AWS Admin via SAML (prod)"
          group_name            = "aws_prod_Admin"
        }
        readonly = {
          iam_role_name         = "AWS-ReadOnly"
          app_role_display_name = "AWS ReadOnly"
          app_role_description  = "AWS ReadOnly via SAML (prod)"
          group_name            = "aws_prod_ReadOnly"
        }
        cyber = {
          iam_role_name         = "AWS-Cyber"
          app_role_display_name = "AWS Cyber"
          app_role_description  = "AWS Cyber via SAML (prod)"
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
          app_role_description  = "AWS Admin via SAML (dev)"
          group_name            = "aws_dev_Admin"
        }
        readonly = {
          iam_role_name         = "AWS-ReadOnly"
          app_role_display_name = "AWS ReadOnly"
          app_role_description  = "AWS ReadOnly via SAML (dev)"
          group_name            = "aws_dev_ReadOnly"
        }
        cyber = {
          iam_role_name         = "AWS-Cyber"
          app_role_display_name = "AWS Cyber"
          app_role_description  = "AWS Cyber via SAML (dev)"
          group_name            = "aws_dev_Cyber"
        }
      }
    }
  }
}

module "aws_saml_accounts" {
  source = "./modules/aws_saml_account"

  for_each           = local.aws_saml_accounts
  app_display_name   = each.value.app_display_name
  app_notes          = each.value.app_notes
  account_id         = each.value.account_id
  saml_provider_name = each.value.saml_provider_name
  partition          = each.value.partition
  roles              = each.value.roles

  # You can also override claims mapping behavior per account if needed
  create_claims_mapping_policy = true
  role_session_name_source_id  = "userprincipalname"
  # session_duration_source_id = "extensionattribute1"
}
```

---


