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

Let me know if you'd like this exported as PDF or in Markdown format for internal documentation or Confluence!
