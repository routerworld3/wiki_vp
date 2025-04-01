---

## 🧠 What Are SAML Attributes?

In a SAML assertion, the **IdP sends user identity details** to the SP in the form of **attributes**.  
Examples:
- Email
- Username
- Group memberships
- Department

Each attribute has:
- A **Name** (or URI)
- A **Value** (e.g., `john.doe@example.com`)

---

## 🧩 How Are SAML Attribute Names Agreed?

### 🔑 Key Concept:
There is **no universal standard** for attribute names across all IdPs and SPs.

Instead:
- The **SP defines** what attributes it expects
- The **IdP must be configured** to send those exact attribute names

So, the agreement is **by convention** or **explicit documentation** between parties.

---

## 🎯 Attribute Name Formats You Might See

### 1. **Standardized URIs (SAML 2.0 Schema)**

These come from standards like [X.500](https://tools.ietf.org/html/rfc4519):

```xml
<Attribute Name="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress" />
```

Or:
```xml
<Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" />
```

These are **well-known namespaces**, and commonly used by:
- **Microsoft Entra ID (Azure AD)**
- **ADFS**
- **Shibboleth**

---

### 2. **Vendor-specific URIs**

Like:
- `http://schemas.microsoft.com/identity/claims/objectidentifier`
- `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name`

These are created/used by:
- Microsoft (Azure, ADFS)
- Google Workspace
- Okta (though more often uses simple attribute names)

---

### 3. **Short custom names**

Sometimes SPs expect:
- `email`
- `firstName`
- `lastName`
- `groups`

This happens in **non-ADFS**, **Okta**, **AWS IAM**, or custom SAML apps.

---

## 🛠️ How to Align SAML Attributes Between IdP and SP

### 1. **SP (App) publishes its required attributes**
Example from AWS IAM Identity Provider:
```json
{
  "email": "required",
  "role": "optional"
}
```

Or from a custom app:
```xml
<Attribute Name="email" />
```

### 2. **IdP must be configured to map its user data** to those exact attribute names

For example, in **Azure AD** or **Okta**, you configure:

| SAML Attribute Name                                  | Value Expression                     |
|------------------------------------------------------|--------------------------------------|
| `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` | `user.mail`                         |
| `role`                                               | `user.assignedroles` (custom claim)  |
| `email`                                              | `user.userprincipalname`             |

---

## ✅ Summary

| Question                        | Answer                                      |
|----------------------------------|---------------------------------------------|
| Who defines attribute names?     | The **SP (App)** defines what it expects    |
| Who matches them?                | The **IdP** must map values to those names |
| Are there standard names?        | Some (e.g., Microsoft schemas), but many are app-specific |
| Can I use custom names?          | Yes — but both IdP and SP must agree       |

---

## ✅ Tips for Troubleshooting

- Use **SAML Tracer** (browser plugin) to inspect the actual SAML assertion
- Compare the **attribute names** and values being sent
- Review the **SP metadata file** or docs for required attribute names

---
# Appstream Elastic Fleet and On-Demand/Always-On Fleet

This overview clarifies which Amazon AppStream 2.0 fleet type is suitable for your scenarios and what implications each has for managing and securing your applications.

---

## **Fleet Types Comparison**

| Feature                              | Elastic Fleets                                   | On-Demand Fleets                                | Always-On Fleets                             |
|--------------------------------------|-------------------------------------------------|---------------------------------------------------|-----------------------------------------------|
| **Capacity Management**              | Fully managed by AWS (no customer management required) | Customer-managed via scaling policies           | Customer-managed via scaling policies         |
| **Instance Lifecycle**               | Managed by AWS (ephemeral)                | Instances remain in standby (stopped) until user connects | Instances always running (standby or active) |
| **Active Directory Domain Join**     | Not supported                             |  Supported                                  |  Supported                                 |
| **Application Delivery Method**      | Portable applications (VHD uploaded to S3) | Custom image (installed apps)                | Custom image (installed apps)                |
| **Application Portability Required** |  Yes (must support portability)          |  Not required                               |  Not required                              |
| **Domain Join (Active Directory)**   |  No                                      |  Yes                                        |  Yes                                       |
| **Capacity Management**              | AWS managed entirely                      | Customer-managed via scaling policies        | Customer-managed via scaling policies        |
| **Maintenance Overhead**             | Lowest (no image management)              | Moderate (periodic image updates)            | Moderate (periodic image updates)            |

---

## **Key Points Explained**

### **Elastic Fleets**
- **Fully Managed by AWS:**  
  No need to manage scaling or predict capacity.
- **Application Delivery:**  
  Delivered via Virtual Hard Disks (VHDs) uploaded to Amazon S3.
  Applications must support portability (similar to apps running from USB drives).
- **Use Case Consideration:**  
  AppBlocks are ideal for applications that require local authentication only.
  AppBlocks do not support domain join or Active Directory, so CAC authentication cannot be used end-to-end.
  Ideal for standalone apps that do not require centralized identity management.

**Ideal for:**
- SaaSifying traditional applications without major rewrites.
- Temporary or short-lived use cases like demos, trials, or training.
- Lightweight apps with no AD dependencies.

### Example Applications:
- Lightweight desktop apps
- Browser-based tools
- Non-domain integrated applications
- Standalone or local-login-only applications

---

### **On-Demand Fleets**
- Users wait about 2 minutes to launch sessions (instances in standby mode).
- Managed via customer-defined auto-scaling policies.
- Suitable for regular usage patterns, balancing quick availability and cost-efficiency.
- Supports domain-joined scenarios.

### Example Applications:
- Regular productivity apps
- Line-of-business applications needing domain integration
- CAC-authenticated apps (via Active Directory)

---

### **Always-On Fleets:**
- Provides instant application launch.
- Ideal for frequent, critical use-cases where instant availability is key.
- Higher cost due to running instances continuously.
- Supports Active Directory and Group Policy integration.

### Example Applications:
- Mission-critical business applications
- Continuous daily applications for call centers, production environments, CAD/CAM, etc.
- Apps requiring end-to-end CAC authentication

---

## **Image Management Differences:**

- **Elastic Fleets:**  
  No traditional image management; applications packaged on a VHD file.
  Very low administrative overhead. Use AppBlocks to package and stream applications.

- **On-Demand & Always-On Fleets:**  
  Require custom images created via the AppStream image builder.
  Periodic updates needed (e.g., OS patches, application updates).

---

## **SAML Integration Note – Well-Known Attribute Name Namespaces**

SAML assertions include user attributes where the name format must exactly match what the service provider (AppStream or other apps) expects.

### ✅ Attribute Name Format
- SAML attribute names can be short (`email`) or full URIs (e.g., Microsoft/Azure/ADFS standard claims).
- There are **well-known namespaces** that define common attributes.

### 📚 Common Well-Known Attribute URIs:

#### Microsoft / ADFS / Azure
| Attribute             | URI                                                                 |
|-----------------------|----------------------------------------------------------------------|
| Email                 | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` |
| User Principal Name   | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn`          |
| Name                  | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name`         |
| Given Name            | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname`    |
| Surname               | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname`      |
| Object ID (Azure)     | `http://schemas.microsoft.com/identity/claims/objectidentifier`      |

#### OASIS / X.500 / LDAP-style URNs
| Attribute             | URI                                         |
|----------------------|----------------------------------------------|
| Common Name (CN)      | `urn:oid:2.5.4.3`                            |
| Email (RFC standard)  | `urn:oid:0.9.2342.19200300.100.1.3`          |
| UID                   | `urn:oid:0.9.2342.19200300.100.1.1`          |
| Organization Name     | `urn:oid:2.5.4.10`                           |

### 🧩 Important:
- If AppStream or your SP expects `email`, you must either:
  - Send `email` as-is
  - Or configure the SP to accept the URI format used by your IdP

Use tools like **SAML Tracer** to inspect what is actually sent in assertions.

---

## **How to Verify Fleet Type Configuration:**
- **AWS Console:**
  - Navigate to **Amazon AppStream 2.0** console.
  - Select the **Fleets** tab to clearly see the fleet type labeled (**Elastic**, **Always-On**, or **On-Demand**).

---



