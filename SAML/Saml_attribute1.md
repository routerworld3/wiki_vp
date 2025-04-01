
- An intro to **SAML namespaces** and **schemas**
- Clear explanations of all three common Microsoft SAML/claim namespaces:
  - `xmlsoap.org`
  - `microsoft.com/ws/...`
  - `schemas.microsoft.com/identity/...`
- Real-world examples
- Use-case alignment (SAML vs. JWT, Azure vs. ADFS)

---

# 📘 Understanding SAML Namespaces and Microsoft Claim Schemas

---

## 🔹 What is a **Namespace** in SAML?

In **SAML**, a **namespace** is an XML construct that uniquely defines the **context and origin of claim (attribute) names** in a SAML assertion.

Namespaces are used to:
- Prevent naming conflicts
- Provide clarity on what the attribute means and where it comes from
- Tell identity-aware applications how to **parse and interpret** claims

> 🔧 Technically, a namespace is expressed as a **URI**, but it **doesn't need to resolve to a website**.

---

## 🔸 What is a **Schema**?

A **schema** is the **collection of attributes/claims and their structure** that a namespace refers to. It defines:
- Which claims exist (e.g., `email`, `groups`, `tenantid`)
- How they should be formatted (e.g., string, URI, SID)
- Their intended use in SAML, OAuth, or OpenID Connect tokens

---

# 🧩 Common Microsoft Namespaces in Claims-Based Identity

Microsoft uses **multiple schemas (namespaces)** across different technologies like **SAML**, **WS-Fed**, **JWT**, and **OpenID Connect**. Here are the most common ones:

---

## ✅ 1. `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/`

### 📌 Source:
- Part of **WS-Federation** and SAML 2.0 standards.
- Common in **ADFS**, **Azure AD**, and other identity providers.

### 🎯 Purpose:
Contains **core identity claims** such as names, UPN, roles, and email.

### 🔑 Common Claims:

| Claim | Full URI | Description |
|-------|----------|-------------|
| UPN | `.../upn` | UserPrincipalName (e.g., jdoe@domain.com) |
| Name | `.../name` | Display name |
| Email | `.../emailaddress` | Email address |
| Given Name | `.../givenname` | First name |
| Surname | `.../surname` | Last name |
| Role | `.../role` | User role or group |

---

## ✅ 2. `http://schemas.microsoft.com/ws/2008/06/identity/claims/`

### 📌 Source:
- Microsoft extension to add more detailed claims, especially for **on-prem AD environments** and **advanced group-based access**.

### 🎯 Purpose:
Provides support for **security identifiers (SIDs)**, group claims, and policy enforcement.

### 🔑 Common Claims:

| Claim | Full URI | Description |
|-------|----------|-------------|
| Groups | `.../groups` | Group SIDs assigned to user |
| Deny-Only SID | `.../denyonlysid` | SID claims used for deny-only access |
| Auth Method | `.../authenticationmethod` | Type of login used (e.g., pwd, smartcard) |

---

## ✅ 3. `https://schemas.microsoft.com/identity/claims/`

### 📌 Source:
- Used primarily by **Azure Entra ID (Azure AD)** for modern **JWT tokens**, **OpenID Connect**, and **SAML assertions** in cloud-native scenarios.

### 🎯 Purpose:
Conveys **Azure-specific metadata** like tenant ID, user object ID, and authentication context.

### 🔑 Common Claims:

| Claim | Full URI | Description |
|-------|----------|-------------|
| Object ID | `.../objectidentifier` | Unique user GUID in Azure AD |
| Tenant ID | `.../tenantid` | Azure tenant GUID |
| IDP | `.../idp` | Identity provider that authenticated the user |
| Auth Methods | `.../authnmethodsreferences` | MFA, pwd, smartcard, etc. |
| Scope | `.../scope` | OAuth scopes granted (in tokens) |

---

## 🧪 SAML Example: Mixed Schema Assertion

```xml
<saml:Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn">
  <saml:AttributeValue>jdoe@domain.com</saml:AttributeValue>
</saml:Attribute>

<saml:Attribute Name="http://schemas.microsoft.com/ws/2008/06/identity/claims/groups">
  <saml:AttributeValue>S-1-5-21-...</saml:AttributeValue>
</saml:Attribute>

<saml:Attribute Name="https://schemas.microsoft.com/identity/claims/objectidentifier">
  <saml:AttributeValue>41a2bde3-1111-4a54-bbbb-22c15f1f7e1a</saml:AttributeValue>
</saml:Attribute>
```

---

## 📊 Summary Table

| Namespace | Use Case | Common Token Type | Where Used |
|-----------|----------|-------------------|------------|
| `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/` | Core identity claims (email, UPN, name) | SAML | Azure Entra ID, ADFS |
| `http://schemas.microsoft.com/ws/2008/06/identity/claims/` | Advanced claims (SIDs, groups, auth method) | SAML, JWT | ADFS, hybrid AD apps |
| `https://schemas.microsoft.com/identity/claims/` | Cloud-native claims (tenantId, objectId, scopes) | JWT, SAML | Azure AD / Entra ID |

---

## ✅ When Should You Use Which?

| Use Case | Namespace(s) Likely Used |
|----------|--------------------------|
| AWS WorkSpaces with Entra SAML | `xmlsoap.org`, `identity/claims/` |
| ADFS-based SAML login | `xmlsoap.org`, `microsoft.com/ws/...` |
| Azure AD OIDC / JWT | `identity/claims/` |
| Access Control by Group SID | `microsoft.com/ws/...` |
| Attribute mapping for Entra federation | All three depending on config |

---


