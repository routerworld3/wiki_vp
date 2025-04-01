Great question — this is often one of the most confusing parts of SAML!

Let’s break down **how SAML attribute names work** and how they’re agreed upon between the **Identity Provider (IdP)** and **Service Provider (SP)** or **App**.

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


