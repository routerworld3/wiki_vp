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
Here’s a detailed explanation of the **two CAC authentication scenarios** for **AWS WorkSpaces**:

---

# 🪪 Detailed Comparison: Pre-Session CAC vs. Azure Entra ID SAML CAC + In-Session CAC

---

## ✅ **Scenario 1: AWS Native Pre-Session CAC Authentication (Using AD Connector)**

### 🔐 Goal: Use CAC to log in **directly into WorkSpaces**, with full certificate validation via Active Directory.

---

### 🔁 Authentication Flow

1. **User launches the AWS WorkSpaces client** (Windows/macOS).
2. Client shows a **smart card login prompt** (pre-session).
3. User inserts **CAC**, enters **PIN**.
4. WorkSpaces establishes a **mutual TLS (mTLS)** connection with **AD Connector**.
5. AD Connector:
   - Validates the cert chain against **on-prem root CA**.
   - Uses **OCSP** for cert revocation checks.
   - Matches cert UPN with Active Directory `userPrincipalName`.
6. If cert is valid:
   - User is logged into the WorkSpace session.

---

### 📥 In-Session CAC Use

Once inside the session (Windows or Linux):

- Smart card redirection via **WSP** protocol allows:
  - Signing emails/documents
  - Website logins (DoD portals, VPN)
  - `sudo` auth on Linux
- Requires CAC reader and drivers on the local machine.
- Smart card redirection is seamless if enabled via GPO.

---

### 🧰 Technical Requirements

| Component | Requirement |
|----------|-------------|
| Directory | **AD Connector** (not AWS Managed AD) |
| CAC Certs | Must have UPN in SAN, Client Auth EKU, Smart Card Logon EKU |
| Revocation | **OCSP** required |
| Client | Windows/macOS WorkSpaces client (3.1.1+) |
| Protocol | **WSP** required for redirection (`443`, `4195`, `UDP 50002-50003`) |

---

## 🟦 **Scenario 2: Azure Entra ID SAML Federation with CAC + In-Session CAC**

### 🔐 Goal: Use **Azure Entra ID (SAML)** to handle CAC-based login; AWS WorkSpaces trusts Entra as IdP.

---

### 🔁 Authentication Flow (Pre-Session via SAML)

1. **User launches WorkSpaces client**.
2. WorkSpaces redirects user to **Azure Entra ID SAML login page** (browser-based).
3. Entra ID uses:
   - **Integrated CAC authentication**, via ADFS, PIV, or external IdP.
   - Certificate matching and revocation checking handled **by Entra ID / ADFS**.
4. Once authenticated:
   - Azure Entra returns a **SAML assertion** to AWS.
   - WorkSpaces grants session access.

> 📌 In this model, **AWS never touches the smart card directly** — Entra/ADFS handles cert validation and UPN mapping.

---

### 📥 In-Session CAC Use

- Same as native mode:
  - CAC redirection works for apps inside the WorkSpace.
  - Requires WSP protocol.
  - CAC reader + middleware needed on user device.
- Common uses:
  - Sign documents (Adobe, Word)
  - VPN login
  - PKI-auth websites (DTS, OWA, etc.)

---

### 🧰 Technical Requirements

| Component | Requirement |
|----------|-------------|
| Directory | AWS Managed AD or AD Connector (doesn’t do CAC) |
| IdP | **Azure Entra ID (w/ CAC-enabled auth)** |
| Protocol | SAML 2.0 |
| CAC Certs | Managed and validated by Entra ID / ADFS |
| Client | WorkSpaces client (Windows/macOS) |
| Smart Card Redirection | Via WSP protocol in-session |

---

## 🔍 Side-by-Side Summary

| Feature | AWS Pre-Session CAC | Azure Entra SAML CAC |
|--------|----------------------|----------------------|
| CAC Prompt | In WorkSpaces client | In browser (Entra login) |
| Who Validates Cert | AD Connector (mTLS) | Azure Entra ID / ADFS |
| OCSP Required | ✅ Yes | ✅/⚠️ Yes (via ADFS/Entra) |
| Smart Card Redirection | ✅ Yes | ✅ Yes |
| In-Session CAC Apps | ✅ Supported | ✅ Supported |
| Web Client Support | ❌ No | ❌ No |
| Protocol | mTLS + WSP | SAML + WSP |
| Directory Integration | AD Connector only | AWS Managed AD or AD Connector |
| Complexity | Medium | High (requires SAML + CAC setup in Entra) |
| Port Requirements | 443, 4195, 50002-50003 | Same (WSP required for in-session) |

---

## 💡 Choosing the Right Model

| Use Case | Recommended Model |
|----------|-------------------|
| You already use Azure Entra CAC authentication | ✅ Use **SAML federation + CAC** |
| You need DoD-compliant native CAC login via AWS | ✅ Use **AD Connector + mTLS CAC** |
| You need browser-based WorkSpaces login with CAC | ❌ Not supported yet |
| You only need in-session CAC (e.g., websites/apps) | ✅ Both models work |

---



