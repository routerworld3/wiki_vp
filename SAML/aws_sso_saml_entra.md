

---

# 🔵 **UPDATED: AWS SSO Integration With Azure – Deep-Dive on User/Group Mapping**

We keep the earlier structure but now add the **identity mapping logic**, **AWS group creation logic**, and **permission set → AWS account assignment**.

---

# 🟦 **1. Azure → AWS Identity Mapping: Key Concepts**

Assigning users or groups to the Azure Enterprise App **does NOT** give AWS permissions by itself.

It only means:

* Azure will allow this user to **authenticate** via SSO
* Azure will **send the SAML assertion** for this user
* (If SCIM enabled) Azure will **push user/group to AWS Identity Center directory**

Actual IAM permissions in AWS come **only from AWS Identity Center**, not Azure.

---

# 🟧 **2. Mapping Logic Overview (High Level)**

```
Azure User
   │
   ▼
Azure Group(s)
   │  (Assigned to Enterprise App)
   ▼
SCIM Provisioning
   │
   ▼
AWS Identity Center Group(s)
   │
   ▼
Assigned Permission Set(s)
   │
   ▼
AWS Account(s) with Permission Set → Role
   │
   ▼
STS Role in AWS (Generated dynamically)
   ▼
Final AWS Console Access
```

This is **not** SAML-to-role mapping.
This is **group → permission set → account** mapping in AWS Identity Center.

---

# 🟦 **3. How Azure Groups Become AWS Identity Center Groups**

This happens via **SCIM**.

## **SCIM Provisioning Flow**

When SCIM is enabled:

### ✔ Azure pushes:

* Users
* Groups
* Group membership

### ✔ AWS Identity Center creates:

* A **User object** in AWS Identity Center Directory
* A **Group object** in AWS Identity Center Directory

  * Name = Azure AD security group name
  * External ID = Azure AD group object ID
* User → Group memberships

You can see these under:
**AWS → IAM Identity Center → Users / Groups**

---

# 🟧 **4. Assigning Groups to AWS Accounts & Permission Sets**

Assigning Azure groups to the Enterprise App **DOES NOT determine permissions**.

Instead, permissions are assigned **inside AWS IAM Identity Center**, not Azure.

### In AWS:

IAM Identity Center → **AWS Accounts**
Select an AWS Account → **Assign Users or Groups**

Then choose:

* AWS Identity Center Group (created from Azure)
* Permission Sets (role templates)

AWS then creates an IAM Role in that target AWS Account:

```
AWSReservedSSO_<PermissionSetName>_<GUID>
```

---

# 🟩 **5. How Permission Sets Work**

A **Permission Set** is an AWS Identity Center object that defines:

* IAM policies
* Session duration
* Boundary policies (optional)
* Tags

Examples:

* `AdministratorAccess`
* `PowerUserAccess`
* `ReadOnlyAccess`
* Custom policies

These are **templates**.

When assigned to an AWS account:

* AWS creates an IAM Role inside that account
* AWS wires the role to Identity Center (STS trust)

---

# 🟩 **6. The EXACT Mapping Chain (You Asked for This)**

Let’s break it down in plain English.

---

## **STEP 1 — Azure User Is a Member of Azure Group**

Example:

```
User: john.doe@company.com
Azure Group: "SecOps-ReadOnly"
```

---

## **STEP 2 — Azure Group is Assigned to Enterprise App**

This allows SSO **authentication**, not authorization.

Azure → Enterprise App → Assignments:

```
SecOps-ReadOnly → AWS SSO App
```

Without this step:
✔ Group will sync to AWS
✖ But user cannot SSO into AWS

---

## **STEP 3 — SCIM Pushes Group to AWS Identity Center**

Azure SCIM pushes:

```
Group "SecOps-ReadOnly"
User "john.doe@company.com"
Membership = user belongs to group
```

AWS Identity Center now has:

Groups:

```
SecOps-ReadOnly  (External ID = Azure GUID)
```

Users:

```
john.doe@company.com
```

Membership:

```
john.doe → SecOps-ReadOnly
```

---

## **STEP 4 — AWS Admin Assigns Permission Set to This Group**

AWS → IAM Identity Center → AWS Accounts → Assign

Choose:

* Group: `SecOps-ReadOnly`
* Permission Sets: `ReadOnlyAccess`
* Accounts: `Production`, `Dev`

This produces IAM roles inside those AWS accounts:

```
AWSReservedSSO_ReadOnlyAccess_xxxxx
```

---

## **STEP 5 — User Logs in Through Azure**

User signs in via SAML.

AWS receives SAML:

```
<NameID>john.doe@company.com</NameID>
```

AWS Identity Center checks:

* Match user
* Check group membership
* Check which accounts/permission sets assigned

---

## **STEP 6 — AWS Injects Role Attribute into SAML Response**

Azure does NOT generate AWS roles.

AWS dynamically constructs:

```
arn:aws:iam::<ACCOUNT-ID>:role/AWSReservedSSO_ReadOnlyAccess_xxxxx,
arn:aws:iam::<ACCOUNT-ID>:saml-provider/AzureAD
```

---

## **STEP 7 — AWS Issues the Final Session**

User sees accounts such as:

```
AWS Account: Production
Role: ReadOnlyAccess
```

---

# 🟫 **7. Why Assigning Groups in Azure Doesn’t Provide AWS Permissions**

Because Azure only provides **authentication**, not authorization.

Authorization is **inside AWS** via:

* Identity Center Groups
* Permission Sets
* Account Assignments

---

# 🟨 **8. FINAL MASTER DIAGRAM**

```
(1) Azure AD Users & Groups
      │
      ▼
(2) Assign to Enterprise App → Allows SSO (authentication)
      │
      ▼
(3) SCIM → Pushes Users + Groups to AWS Identity Center
      │
      ▼
(4) AWS Admin → Assigns Identity Center Groups to
      - Permission Sets (IAM templates)
      - AWS Accounts
      │
      ▼
(5) AWS Creates IAM Roles in Accounts
      │
      ▼
(6) User Logs In → SAML → AWS Identity Center
      │
      ▼
(7) AWS Evaluates Identity Center Group → Permission Set → Account
      │
      ▼
(8) AWS Issues STS Role Session (final access)
```

**Azure controls WHO you are.**
**AWS controls WHAT you can access.**

---

Here is a **full, end-to-end, deep-detail ASCII diagram** showing:

✔ AWS ↔ Azure SAML
✔ SCIM provisioning
✔ Enterprise App assignments
✔ Identity Center Groups
✔ Permission sets → AWS Accounts
✔ SAML login flow
✔ Role injection
✔ STS session generation

This is the **most complete ASCII diagram** for AWS SSO + Azure Entra available.

---

# 🟦 **FULL END-TO-END ASCII DIAGRAM

Azure Entra ID ↔ AWS IAM Identity Center (SSO) Architecture**

```
                          ┌────────────────────────────────────────────────────┐
                          │                   AZURE ENTRA ID                   │
                          │               (Identity Provider - IdP)             │
                          └────────────────────────────────────────────────────┘
                                            ▲                     ▲
                                            │ SAML SSO            │ SCIM Provisioning (Optional)
                                            │ Authentication       │ Users, Groups, Membership
                                            │                     │
                                            │                     │
                                            │                     │
                       ┌─────────────────────────────┐        ┌───────────────────────────────┐
                       │  Azure Enterprise App (SAML) │◄───────┤  Azure AD Users & Groups     │
                       │  "AWS IAM Identity Center"   │        │  Example:                    │
                       │      Non-Gallery App         │        │   - John Doe                 │
                       └──────────────┬───────────────┘        │   - SecOps-ReadOnly (Group) │
                                      │                        └───────────────────────────────┘
                                      │
                        Assign Users & Groups to App
                                      │
                                      ▼
                   ┌──────────────────────────────────────────┐
                   │  Azure Generates SAML Using AWS Metadata │
                   │  - ACS URL                               │
                   │  - Entity ID                             │
                   │  - Signing Cert                          │
                   └──────────────────────────────────────────┘


══════════════════════════════ PARALLEL FLOW (CONFIGURATION) ══════════════════════════════

        AWS METADATA (SP)                                            AZURE METADATA (IdP)
        SP XML → Uploaded to Azure                                   IdP XML → Uploaded to AWS


════════════════════════════════════ USER / GROUP SYNC ═════════════════════════════════════

                                     SCIM PUSH
              ┌──────────────────────────────────────────────────────────────────────────┐
              │                               SCIM to AWS                                │
              │ Users + Groups + Group Membership pushed to AWS Identity Center Directory│
              └──────────────────────────────────────────────────────────────────────────┘

Azure Group “SecOps-ReadOnly”
      │
      │  SCIM
      ▼
┌─────────────────────────────────────────────────────────────┐
│  AWS Identity Center - Group Created                         │
│  Name: SecOps-ReadOnly                                       │
│  External ID = (Azure AD Group Object ID)                    │
└─────────────────────────────────────────────────────────────┘

Azure User “john.doe@company.com”
      │
      ▼
┌─────────────────────────────────────────────────────────────┐
│  AWS Identity Center - User Created                          │
│  Username: john.doe@company.com                              │
│  Member of: SecOps-ReadOnly                                   │
└─────────────────────────────────────────────────────────────┘


══════════════════════════════════ AUTHORIZATION FLOW ══════════════════════════════════

AWS ADMIN assigns:
  Group → Permission Set → AWS Account(s)

            ┌────────────────────────────────────────────────────────────────────┐
            │                    AWS IAM Identity Center                          │
            │       Authorization (NOT Azure’s Responsibility)                    │
            └────────────────────────────────────────────────────────────────────┘

Azure Group  (SCIM)         Permission Set             AWS Account(s)
SecOps-ReadOnly   ─────────▶ ReadOnlyAccess ─────────▶  Prod / Dev
                                                │
                                                ▼
                              AWS Creates IAM Role in Each Account:
                              arn:aws:iam::<ACCOUNT-ID>:role/AWSReservedSSO_ReadOnlyAccess_xxxxx


════════════════════════════════════ SSO LOGIN FLOW ════════════════════════════════════════

                         ┌───────────────────────────────────────────┐
                         │         USER LOGIN EVENT                  │
                         │  User → “My Applications” (Azure/SSO)    │
                         └───────────────────────────────────────────┘
                                          │
                                          ▼
                         ┌───────────────────────────────────────────┐
                         │  Azure Login Page (UPN/Password/CAC)      │
                         └───────────────────────────────────────────┘
                                          │
                                      SAML Response
                                          │
                                          ▼
                   ┌──────────────────────────────────────────────────────────┐
                   │     AWS IAM Identity Center Receives SAML Assertion      │
                   │  - Validates Signature via IdP metadata                  │
                   │  - Extracts NameID (e.g., UPN)                           │
                   │  - Resolves User in AWS Identity Center Directory        │
                   │  - Finds Group Membership                                │
                   │  - Finds Assigned Permission Sets and AWS Accounts       │
                   └──────────────────────────────────────────────────────────┘

                                          │
                                          ▼
                   ┌──────────────────────────────────────────────────────────┐
                   │   AWS Injects Role SAML Attribute (Azure does NOT send) │
                   │   Example Injected Role Attribute:                       │
                   │   arn:aws:iam::<ACC-ID>:role/AWSReservedSSO_ReadOnly...  │
                   │   ,arn:aws:iam::<ACC-ID>:saml-provider/AzureAD           │
                   └──────────────────────────────────────────────────────────┘
                                          │
                                          ▼

════════════════════════════════════ FINAL AWS SESSION ══════════════════════════════════════

┌─────────────────────────────────────────────────────────────┐
│       AWS STS Issues Temporary Credentials                   │
│                                                             │
│  User sees:                                                 │
│   - AWS Account: Production                                 │
│   - Role: ReadOnlyAccess                                    │
│   - Session: 1–12 hours                                     │
└─────────────────────────────────────────────────────────────┘

```

---

# 🟩 **SUMMARY OF THE ENTIRE FLOW (ASCII Form)**

```
Azure Group → Assigned to Enterprise App → SCIM pushes to AWS → 
AWS IC Group → Permission Set → AWS Account → IAM Role Created → 
User Logs in → Azure Sends SAML → AWS Injects Role → STS Session
```

---
Nice, let’s zoom out to the “real” world: **multiple AWS accounts, multiple permission sets, same Entra tenant**.

Below is an ASCII diagram that shows:

* Multiple **Azure groups**
* Multiple **AWS accounts**
* Multiple **permission sets**
* How **one user** can end up with **several role options** across **many accounts**

---

## 🟦 High-Level Multi-Account / Multi-Permission-Set Architecture

### Scenario (concrete example)

* Azure Groups:

  * `AWS-SecOps-Admin`
  * `AWS-SecOps-ReadOnly`
  * `AWS-DevOps-Developer`
* AWS Accounts:

  * `Prod-Security` (111111111111)
  * `Prod-App` (222222222222)
  * `Dev-App` (333333333333)
* Permission Sets:

  * `AdminAccess`
  * `ReadOnlyAccess`
  * `PowerUserAccess`
  * `DeveloperAccess`

---

### 🔷 Big Picture Diagram

```text
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                 AZURE ENTRA ID (IdP)                                    │
│                                                                                         │
│   ┌───────────────────────────────────────────────────────────────────────┐              │
│   │                   Azure AD Users & Security Groups                    │              │
│   │                                                                       │              │
│   │   Users:                                                              │              │
│   │     - john.doe@company.com                                            │              │
│   │     - jane.ops@company.com                                            │              │
│   │                                                                       │              │
│   │   Groups (examples):                                                  │              │
│   │     - AWS-SecOps-Admin        (SecOps team admins)                    │              │
│   │     - AWS-SecOps-ReadOnly     (SecOps auditors)                       │              │
│   │     - AWS-DevOps-Developer    (App devs)                              │              │
│   └───────────────────────────────────────────────────────────────────────┘              │
│                                                                                         │
│       ▲                          ▲                                     ▲               │
│       │ SCIM: Users/Groups/Membership                                  │               │
│       │                          │                                     │               │
│       │                          │                                     │               │
│   ┌───┴──────────────────────────┴─────────────────────────────────────┴─────────────┐ │
│   │                     Azure Enterprise App (SAML + SCIM)                           │ │
│   │                    "AWS IAM Identity Center (SSO)"                               │ │
│   │   - SAML: Uses AWS SP metadata (ACS URL, EntityID, Cert)                         │ │
│   │   - SCIM: Push Users/Groups to AWS                                               │ │
│   │   - Assignments: Groups assigned for SSO                                         │ │
│   └──────────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                       SCIM Sync (Users, Groups, Membership)
                                      │
                                      ▼

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                            AWS IAM IDENTITY CENTER (SSO)                                │
│                            (Central Auth + Authorization)                               │
│                                                                                        │
│  ┌───────────────────────────┐      ┌───────────────────────────┐                       │
│  │ AWS Identity Center Users │      │ AWS Identity Center Groups│                       │
│  │  (synced from Azure)      │      │  (synced from Azure)      │                       │
│  │                           │      │                           │                       │
│  │  john.doe@company.com     │      │  AWS-SecOps-Admin         │                       │
│  │  jane.ops@company.com     │      │  AWS-SecOps-ReadOnly      │                       │
│  │                           │      │  AWS-DevOps-Developer     │                       │
│  └───────────────┬───────────┘      └───────────────┬───────────┘                       │
│                  │                                  │                                   │
│       Membership │                                  │ Membership                        │
│                  ▼                                  ▼                                   │
│        john.doe ∈ AWS-SecOps-Admin          john.doe ∈ AWS-DevOps-Developer             │
│        jane.ops ∈ AWS-SecOps-ReadOnly                                                   │
│                                                                                        │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │                   PERMISSION SETS (Global Templates in Identity Center)          │   │
│  │                                                                                  │   │
│  │   - AdminAccess        (similar to AdministratorAccess)                         │   │
│  │   - ReadOnlyAccess     (IAM + Org read-only, CloudTrail, etc.)                  │   │
│  │   - PowerUserAccess    (No IAM management)                                      │   │
│  │   - DeveloperAccess    (Dev tooling, but limited prod access)                   │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                        │
│                                      │ Assign to                                      │
│                                      ▼                                                │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │                 ACCOUNT + GROUP + PERMISSION SET ASSIGNMENTS                     │   │
│  │                                                                                  │   │
│  │  Example mappings:                                                               │   │
│  │                                                                                  │   │
│  │  Group: AWS-SecOps-Admin                                                         │   │
│  │    -> Permission Set: AdminAccess                                                │   │
│  │       Accounts:                                                                 │   │
│  │         - Prod-Security (111111111111)                                          │   │
│  │         - Prod-App      (222222222222)                                          │   │
│  │                                                                                  │   │
│  │  Group: AWS-SecOps-ReadOnly                                                      │   │
│  │    -> Permission Set: ReadOnlyAccess                                             │   │
│  │       Accounts:                                                                 │   │
│  │         - Prod-Security (111111111111)                                          │   │
│  │         - Prod-App      (222222222222)                                          │   │
│  │         - Dev-App       (333333333333)                                          │   │
│  │                                                                                  │   │
│  │  Group: AWS-DevOps-Developer                                                     │   │
│  │    -> Permission Set: DeveloperAccess                                            │   │
│  │       Accounts:                                                                 │   │
│  │         - Dev-App       (333333333333)                                          │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                        │
│                       For each Assignment (Group + PermSet + Account):                 │
│                       AWS creates IAM roles inside target accounts:                    │
│                                                                                        │
│    Prod-Security (111111111111):                                                       │
│        - role/AWSReservedSSO_AdminAccess_xxx          (for AWS-SecOps-Admin)           │
│        - role/AWSReservedSSO_ReadOnlyAccess_yyy       (for AWS-SecOps-ReadOnly)        │
│                                                                                        │
│    Prod-App (222222222222):                                                            │
│        - role/AWSReservedSSO_AdminAccess_zzz          (for AWS-SecOps-Admin)           │
│        - role/AWSReservedSSO_ReadOnlyAccess_aaa       (for AWS-SecOps-ReadOnly)        │
│                                                                                        │
│    Dev-App (333333333333):                                                             │
│        - role/AWSReservedSSO_ReadOnlyAccess_bbb       (for AWS-SecOps-ReadOnly)        │
│        - role/AWSReservedSSO_DeveloperAccess_ccc      (for AWS-DevOps-Developer)       │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🟥 SSO Login and Role Choice Across Multiple Accounts

Now, what happens when **john.doe** signs in?

* john.doe is a member of:

  * `AWS-SecOps-Admin`
  * `AWS-DevOps-Developer`

So, after login, he can see Admin roles in multiple accounts **and** a Developer role in Dev.

```text
                USER LOGIN FLOW WITH MULTIPLE ACCOUNTS / PERMISSION SETS

                        ┌───────────────────────────────────────┐
                        │   User: john.doe@company.com          │
                        │   Goes to AWS SSO Portal              │
                        └───────────────────────────────────────┘
                                          │
                                 Browser redirect (SAML)
                                          │
                                          ▼
                        ┌───────────────────────────────────────┐
                        │          Azure Entra Login            │
                        │ (UPN + password / CAC / MFA, etc.)    │
                        └───────────────────────────────────────┘
                                          │
                                SAML Assertion to AWS
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                   AWS IAM IDENTITY CENTER – SESSION RESOLUTION                          │
│                                                                                         │
│  1. Validate SAML signature from Azure IdP                                              │
│  2. Extract NameID = john.doe@company.com                                               │
│  3. Lookup AWS Identity Center user "john.doe@company.com"                              │
│  4. Find Identity Center Group memberships:                                             │
│       - AWS-SecOps-Admin                                                                │
│       - AWS-DevOps-Developer                                                            │
│  5. For each group, find Account + Permission Set assignments:                          │
│       - AWS-SecOps-Admin: AdminAccess on Prod-Security, Prod-App                        │
│       - AWS-DevOps-Developer: DeveloperAccess on Dev-App                                │
│  6. Build list of available roles (accounts + permission sets)                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
                         ┌───────────────────────────────────────┐
                         │    AWS SSO Application Portal         │
                         │   (What john.doe sees after login)    │
                         └───────────────────────────────────────┘

Applications/Accounts shown:

  [ Prod-Security - AdminAccess ]
  [ Prod-App      - AdminAccess ]
  [ Dev-App       - DeveloperAccess ]

(If you expose them as "AWS Account Tiles" with friendly names)

When john.doe clicks, e.g.:

  [ Prod-App - AdminAccess ]

AWS STS issues temporary credentials for:
  arn:aws:iam::222222222222:role/AWSReservedSSO_AdminAccess_zzz

john.doe now has AdminAccess in the Prod-App account for the session duration.
```

---

## 🟩 Conceptual Summary in 4 Lines

```text
Azure Group(s) → AWS Identity Center Group(s)
AWS IC Group(s) → Permission Set(s) + Account(s)
These produce IAM roles per account
User sees one "tile" per (Account + Permission Set) combination after login
```

---




