Below is a **two-part** example showing how to:

1. **Create** and **assign** a **custom claims mapping policy** in Microsoft Entra ID (Azure AD) via **Terraform** so you can emit an internal attribute (e.g., `certificateUserIds`) in a token.  
2. **Copy** users’ `certificateUserIds` **into** a **different attribute** (such as `employeeId` or a custom extension attribute) using **PowerShell** and the **Microsoft Graph** SDK.  

> **Important**  
>  - As of this writing, **Terraform** support for “Custom Claims Mapping Policy” is still evolving. The below example uses the **azuread** provider’s resources (and syntax) available in current or preview releases. If your provider or version doesn’t yet support these resources, you may need to use the **msgraph** provider or resort to a **local-exec** with the Microsoft Graph REST API.  
>  - If `certificateUserIds` is **multi-valued**, you may need to **join** the values into a single string before assigning them to attributes like `employeeId`.

---

# 1. Sample Terraform for a Custom Claims Mapping Policy

Below is an **illustrative** example. Adjust resource names, versions, and references according to your setup.

```hcl
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.35.0" # Example: pick a version that supports custom policies
    }
  }
}

provider "azuread" {
  # Either use environment vars (ARM_CLIENT_ID, etc.)
  # or specify additional config for authentication
}

# ------------------------------------------------------------------------------
# 1. Create (or reference) an Azure AD Application and its Service Principal
# ------------------------------------------------------------------------------
resource "azuread_application" "example_app" {
  display_name = "My SAML App"
  owners       = ["00000000-0000-0000-0000-000000000000"] # optional
}

resource "azuread_service_principal" "example_sp" {
  application_id = azuread_application.example_app.application_id
}

# ------------------------------------------------------------------------------
# 2. Create a Custom Claims Mapping Policy in Azure AD
# ------------------------------------------------------------------------------
resource "azuread_custom_claims_mapping_policy" "example_claims_policy" {
  display_name = "MyCertificateUserIdsPolicy"
  # 'definition' must be a JSON array with your policy JSON
  definition = [
    <<POLICYDEF
{
  "ClaimsMappingPolicy": {
    "Version": 1,
    "IncludeBasicClaimSet": "true",
    "ClaimsSchema": [
      {
        "Source": "user",
        "ID": "certificateUserIds",
        "JwtClaimType": "certificateUserIds"
      }
    ]
  }
}
POLICYDEF
  ]
}

# ------------------------------------------------------------------------------
# 3. Assign the Policy to the Service Principal
# ------------------------------------------------------------------------------
resource "azuread_service_principal_policy_assignment" "example_assignment" {
  service_principal_id = azuread_service_principal.example_sp.id
  policy_id           = azuread_custom_claims_mapping_policy.example_claims_policy.id
}
```

### Explanation

1. **`azuread_application`** and **`azuread_service_principal`**: Represents your SAML-based application in Entra ID.  
2. **`azuread_custom_claims_mapping_policy`**: Creates a custom policy that says, “Emit the `certificateUserIds` attribute as a claim named `certificateUserIds` in tokens.”  
3. **`azuread_service_principal_policy_assignment`**: Binds the above policy to your application’s service principal, so the SAML/JWT tokens issued to this application include the custom claim.  

> **Note**: You must ensure your **Azure AD plan (Premium)** supports custom claims mapping policies. If the provider or version you’re using does **not** have these resources, you may need to call the Microsoft Graph REST API directly from Terraform (e.g., using `local-exec`) or use the **msgraph** provider if still available.

---

# 2. PowerShell Script to Copy `certificateUserIds` to Another Attribute

Below is a **PowerShell** script using the **Microsoft Graph PowerShell module** to:

- **Iterate** all users  
- **Read** each user’s `certificateUserIds` (if any)  
- **Copy** that to either `employeeId` (a built-in attribute) or a custom extension property

> **Prerequisites**  
>  - [Install the Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation).  
>  - Sufficient permissions to read/write user attributes (e.g., **User.ReadWrite.All** in Graph).

### Example: Copying to `employeeId`

```powershell
# 1. Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All"

# 2. Retrieve all users (may need additional parameters for large tenants)
$allUsers = Get-MgUser -All

foreach ($usr in $allUsers) {
    # 'certificateUserIds' is often an array. Check if it's non-empty.
    if ($usr.certificateUserIds -and $usr.certificateUserIds.Count -gt 0) {
        # If multiple values, join them into one string
        $joinedValues = $usr.certificateUserIds -join ";"

        Write-Host "Updating user $($usr.DisplayName) with certificateUserIds -> employeeId: $joinedValues"

        # 3. Update the user's 'employeeId' attribute
        Update-MgUser -UserId $usr.Id -EmployeeId $joinedValues
    }
}
```

- **`-join ";"`** merges multiple cert IDs into a semicolon-delimited string. Adjust the delimiter as needed.  
- If the user has **no** `certificateUserIds`, we skip them.

### Example: Copying to a Custom Extension Attribute

If you prefer to store the data in an **extension property**, define it first. For example, create an **Open Extension** or a **Schema Extension**. Let’s assume you have a property named `extension_1234567890abcdef_certificateUserIds`.

```powershell
# Connect as before
Connect-MgGraph -Scopes "User.ReadWrite.All"

$allUsers = Get-MgUser -All

foreach ($usr in $allUsers) {
    if ($usr.certificateUserIds -and $usr.certificateUserIds.Count -gt 0) {
        $joinedValues = $usr.certificateUserIds -join ";"

        Write-Host "Updating $($usr.DisplayName) with certificateUserIds extension: $joinedValues"

        # Prepare a hash of additional properties
        $extensionProps = @{
            "extension_1234567890abcdef_certificateUserIds" = $joinedValues
        }

        # Update the user with extension property
        Update-MgUser -UserId $usr.Id -AdditionalProperties $extensionProps
    }
}
```

- Now, you can **map** `extension_1234567890abcdef_certificateUserIds` in your **Claims** settings or via the Terraform **azuread_application**/**azuread_custom_claims_mapping_policy** if it’s recognized.

---

## 3. Summary

1. **Terraform Custom Claims Policy**  
   - Create a resource that **exposes** `certificateUserIds` as a SAML/JWT claim.  
   - Assign the policy to your service principal (application).  
2. **Copying the Data**  
   - If Azure AD cannot directly emit `certificateUserIds` (or if your application needs it in `employeeId` or a custom extension), **copy** the value using **PowerShell** + **Microsoft Graph**:
     - Save into an official attribute (like `employeeId`).
     - Or store it in a custom extension property, then emit **that** property as a claim.  

By combining these steps, you’ll be able to **manage** the `certificateUserIds` attribute in your tenant **and** include it in **SAML assertions** (or other tokens) for downstream applications.
