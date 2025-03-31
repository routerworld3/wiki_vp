 **AWS WorkSpaces supports CAC (Common Access Card) authentication**,

- Pre-session vs in-session CAC auth
- Requirements
- Supported clients
- Ports and protocols (WSP/PCoIP)
- Region and directory limitations

---

# 🪪 AWS WorkSpaces: CAC Authentication (Pre-Session & In-Session)

## 📘 Overview

AWS WorkSpaces supports **Common Access Card (CAC)** and **PIV smart card authentication** for both:

- ✅ **Pre-session authentication** (when logging into the WorkSpace)
- ✅ **In-session authentication** (after login, for accessing applications or running commands)

This is especially useful for government or regulated environments that rely on PKI and smart card infrastructure.

---

## 🧩 CAC Authentication Modes

### ✅ 1. Pre-Session Authentication
- Occurs **before** the WorkSpace session starts.
- Uses **mutual TLS (mTLS)** with **AD Connector** and smart card certs.
- Authenticates against your **on-premises Active Directory**.

### ✅ 2. In-Session Authentication
- Occurs **within** the WorkSpace session.
- Enables use of CAC/PIV for secure login to apps (websites, VPNs, sudo, etc.).
- Requires **smart card redirection** to pass reader input into the session.

---

## 💻 Client Support

| Client | Pre-Session CAC | In-Session CAC (Smart Card Redirection) |
|--------|------------------|------------------------------------------|
| **Windows WorkSpaces Client (v3.1.1+)** | ✅ Supported | ✅ Supported |
| **macOS WorkSpaces Client (v3.1.5+)** | ✅ Supported | ✅ Supported |
| **Web Browser Client** | ❌ Not supported | ❌ Not supported |
| **Linux Client** | ❌ Not supported | ❌ Not supported |

> ✅ **Only the Windows/macOS native clients support CAC features.**

---

## 🌍 Region Availability

| Mode | Regions |
|------|---------|
| **Pre-Session CAC** | Supported in:  
US East (N. Virginia),  
US West (Oregon),  
GovCloud (US-East & West),  
Europe (Ireland),  
Asia Pacific (Tokyo, Sydney) |
| **In-Session CAC** | Available in **all Regions where DCV protocol is supported** |

---

## 📜 Requirements

### 🔗 Directory

- **AD Connector** (Required for Pre-session CAC)
  - Must support **mutual TLS**
  - Requires **Kerberos Constrained Delegation (KCD)**
- On-prem Active Directory must issue certs with:
  - `UPN` in **subjectAltName**
  - EKUs: `Client Authentication` and `Smart Card Logon`
  - OCSP enabled for revocation checking

> ❗ You cannot enable both pre-session CAC and password sign-in on the same AD Connector.

---

## 🛠 Configuration Overview

### For Pre-Session CAC:
- AD Connector must be configured with **mTLS**
- WorkSpaces must be domain-joined to that AD
- WorkSpaces GPO must enable smart card login & redirection
- Windows Lock Screen Detection should be enabled (to trigger re-auth)

### For In-Session CAC:
- Ensure **smart card redirection** is enabled via GPO
- CAC reader and middleware (like ActivClient) installed on user endpoint
- Optional: Configure Firefox to use PKCS#11 module (OpenSC)

---

## 🔐 Ports and Protocols for CAC

### ✅ Core Protocol Support

| Protocol | Ports | Used For |
|----------|-------|----------|
| **WSP (WorkSpaces Streaming Protocol)** | `TCP 4195`, `UDP 50002-50003` | ✔ Required for smart card redirection (in-session CAC) |
| **PCoIP (older protocol)** | `TCP/UDP 4172` | ❌ Not recommended for CAC — limited support |
| **HTTPS** | `TCP 443` | Used for login, control channel, mTLS auth with AD |

> ✅ **Use WSP for full CAC support** — both for pre-session and in-session use.

---

## 🔍 Summary of Protocol Needs

| CAC Type | Protocol | Required Ports |
|----------|----------|----------------|
| Pre-Session CAC | **HTTPS + mTLS** | `TCP 443` (auth via AD Connector) |
| In-Session CAC | **WSP + Smart Card Redirection** | `TCP 4195`, `UDP 50002-50003`, plus `TCP 443` |

---

## ⚠️ Limitations

- Only **one smart card** per session is supported.
- **Web clients are not supported** for CAC.
- **Ubuntu WorkSpaces** do not support smart cards.
- Only **CAC and PIV** cards are officially supported.
- **In-session CAC** doesn't strictly require OCSP, but it's recommended.

---

## 🧪 Testing & Troubleshooting Tips

- Use `pklogin_finder` (Linux) to map certs → users
- Enable debug logs for `pam_pkcs11` and `pam_krb5`
- On Windows, use `certutil` to verify mTLS cert trust chains
- In Firefox, load PKCS#11 module manually or via GPO (`policies.json`)
- Watch out for multiple matching certificates on CAC

---

## ✅ Recommendations

| Task | Recommendation |
|------|----------------|
| Choose Protocol | ✅ Use **WSP** |
| Client Platform | ✅ Use **Windows/macOS clients only** |
| Directory | ✅ Use **AD Connector with mTLS + OCSP** |
| Certificate Mapping | ✅ Ensure UPN in SAN and correct EKUs |
| Ports | ✅ Allow `443`, `4195`, `50002-50003` |
| GPO Settings | ✅ Enable smart card login + redirection |

---

Great question — when you introduce **Azure Entra ID (formerly Azure AD)** with **SAML federation** into the **AWS WorkSpaces + CAC** authentication flow, the roles and mechanisms of **Pre-Session** and **In-Session CAC authentication** change **significantly**, especially in how identity is federated and where the CAC interaction happens.

Let’s break it all down:

---

## 🧩 Key Definitions

| Term | Meaning |
|------|--------|
| **Pre-Session CAC Auth** | Smart card used at WorkSpaces login screen to authenticate user before session starts. |
| **In-Session CAC Auth** | Smart card is used *within* the desktop session (e.g., signing into internal apps, websites, or running privileged commands). |
| **Azure Entra SAML Federation** | Users authenticate via **Azure Entra ID**, typically with SAML, and are **redirected from WorkSpaces** to authenticate in Entra ID (with or without CAC). |

---

## ✅ Standard AWS WorkSpaces CAC Flow (AD Connector)

### 🔐 Pre-Session CAC Auth
- Happens **at the WorkSpaces client login screen**.
- WorkSpaces prompts for CAC + PIN (via mTLS).
- Authenticates via **AD Connector** → On-prem AD + OCSP.
- Result: User is logged into WorkSpace after certificate validation.

### 🧾 In-Session CAC Auth
- CAC redirection happens via WSP protocol.
- User can use smart card for:
  - Logging into websites
  - Signing documents
  - Sudo/sudo -i (Linux)
- Requires client support + redirection + PKI middleware.

---

## 🟦 When You Use **Azure Entra ID SAML Federation** with CAC

### 🔁 What changes:

| Area | Behavior |
|------|----------|
| **Pre-Session Auth** | 🔄 *No longer handled by WorkSpaces natively*. Entra ID handles authentication via SAML. |
| **Who prompts for CAC?** | Azure Entra ID (via web-based login) prompts for CAC — WorkSpaces doesn’t interact with the smart card. |
| **Directory Type** | Usually **AWS Managed Microsoft AD** or **AD Connector**, federated via SAML to Entra ID. |
| **WorkSpaces Login Experience** | User launches WorkSpace → redirected to Entra ID login page (web) → authenticates using CAC (via ADFS/Entra). |
| **mTLS / RADIUS** | Not required in AWS anymore — Entra ID handles the CAC logic and cert validation. |

---

## ✅ How In-Session CAC Still Works

In-session smart card use **does NOT depend on SAML federation** — it still works normally:

- WSP protocol enables smart card redirection.
- User’s client device must have:
  - CAC reader
  - Supported AWS WorkSpaces client (Windows/macOS)
  - Middleware (e.g., ActivClient, OpenSC)

> ✅ The user can still use the smart card for in-session apps: VPN, DoD portals, digital signatures, etc.

---

## 🔐 Summary of Key Differences

| Feature | AD Connector w/ AWS CAC | Entra ID + SAML + CAC |
|--------|--------------------------|------------------------|
| Pre-session CAC | Handled by AWS WorkSpaces (via mTLS) | Handled by Entra ID via SAML |
| In-session CAC | Supported | Supported |
| Who validates CAC cert? | AD Connector + OCSP | Azure Entra / ADFS |
| Client login experience | WorkSpaces client shows cert prompt | WorkSpaces client redirects to SAML login (browser-based) |
| Additional infra needed | RADIUS, OCSP, mTLS | Azure AD, ADFS, CAC-enabled IdP |
| CAC use in-session (e.g., websites, sudo) | ✅ Supported | ✅ Supported |

---

## 🧠 Important Notes

- If you already use **CAC with Entra ID**, you don’t need to double-up with WorkSpaces’ pre-session CAC — you're already handling CAC at the **federated identity layer**.
- In this model, **WorkSpaces becomes a service provider (SP)** that trusts **Entra ID as the identity provider (IdP)**.

---

## 🧾 Recommendation

If you're federating WorkSpaces with **Azure Entra ID + CAC**:

- Use **Entra ID** for CAC-based SAML login (**skip WorkSpaces native CAC**).
- Keep **smart card redirection enabled** for in-session use.
- Use **WSP protocol** for full redirection support (ports: `443`, `4195`, `UDP 50002-50003`).
- Ensure client is Windows/macOS WorkSpaces client v3.1.1+.

---

