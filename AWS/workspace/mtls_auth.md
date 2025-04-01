Sure — let’s walk through the **mTLS CAC Authentication** process in **AWS WorkSpaces**, step-by-step, focusing on:

- What **mTLS (mutual TLS)** really means in this context
- How AWS uses it with **AD Connector** to authenticate a user using a **CAC (Common Access Card)**
- What infrastructure and certificate components are involved
- Where revocation, mapping, and GPOs fit in

---

## 🔐 What is mTLS CAC Authentication?

**mTLS (Mutual TLS)** is a **certificate-based authentication protocol** where both the **client and the server** present certificates to each other to establish **mutual trust**.

In AWS WorkSpaces, **mTLS CAC Authentication** means:
> The **WorkSpaces client** uses the **certificate on the CAC smart card** to authenticate to the **AD Connector**, which in turn authenticates the user to **Active Directory (AD)** using **Kerberos Constrained Delegation (KCD)**.

---

## 📶 mTLS CAC Authentication Flow in AWS WorkSpaces

### 🔁 End-to-End Flow

```
User → WorkSpaces Client → mTLS to AD Connector → AD Authentication → Start Session
```

---

### 🔄 Step-by-Step Breakdown

#### ✅ 1. User Launches the WorkSpaces Client

- They are prompted to insert their **CAC smart card** and enter a **PIN**.
- The smart card provides a **client certificate** stored on the card.

#### ✅ 2. mTLS Handshake Begins (Client ↔ AD Connector)

- The **WorkSpaces client** attempts a **mutual TLS connection** to the **AD Connector**.
- During the handshake:
  - The **client presents the smart card certificate**.
  - The **AD Connector presents its server certificate**.
  - Both parties verify each other's cert chains.

#### ✅ 3. AD Connector Validates Client Certificate

- Validates the **certificate trust chain**:
  - The smart card’s issuing CA must be in AD Connector’s **trusted root store**.
- Checks for required **EKU (Extended Key Usage)**:
  - `Client Authentication (1.3.6.1.5.5.7.3.2)`
  - `Smart Card Logon (1.3.6.1.4.1.311.20.2.2)`
- Verifies **revocation status** via **OCSP** (Online Certificate Status Protocol).
- Extracts the `userPrincipalName` (UPN) from the `subjectAltName` field in the certificate.

#### ✅ 4. UPN Mapping to Active Directory

- The **UPN** from the cert must match an actual user in the on-premises **Active Directory**.
- If matched, AD Connector uses **Kerberos Constrained Delegation (KCD)** to request a **Kerberos Ticket Granting Ticket (TGT)** for the user.

#### ✅ 5. WorkSpaces Session is Granted

- Once AD Connector confirms successful Kerberos auth, WorkSpaces launches the user session.
- Optional: Group Policy settings may disconnect the session when the Windows lock screen is triggered (to re-enforce CAC login).

---

## 🧰 Infrastructure Requirements

### 🔗 AD Connector

- Must be configured for **mTLS CAC**.
- Supports **certificate-based login** using smart cards.
- Integrated with on-prem **Active Directory** (joined domain).

### 🛂 Certificates & CA

| Component | Required Attributes |
|----------|----------------------|
| **User Certificate (CAC)** | UPN in `subjectAltName`, EKUs: `Client Auth`, `Smart Card Logon` |
| **AD Connector Trusted CA** | Must trust the issuing root CA |
| **On-Prem Domain Controllers** | Must use **KDC Authentication** certificate templates (not “Domain Controller Authentication”) |

---

## 📝 Configuration Details

### 🔐 Certificate Requirements

- **Client Certificate (on CAC)**:
  - UPN: `subjectAltName`
  - EKUs: `1.3.6.1.5.5.7.3.2`, `1.3.6.1.4.1.311.20.2.2`
- **AD Connector**:
  - Upload CA root certificate chain
  - Enable mTLS via Directory Service settings
- **Smart Card Middleware**:
  - Install ActivClient (Windows) or OpenSC (macOS)
  - Make sure OS recognizes the smart card reader and cert

---

## 🔐 Kerberos Constrained Delegation (KCD)

- **Why it's needed**:
  - AD Connector itself doesn't authenticate users directly — it **delegates authentication** to the domain controller.
- **KCD Requirement**:
  - The AD Connector service account’s `sAMAccountName` must match the username.
  - It must be configured to allow constrained delegation to Kerberos services.

---

## 🌐 Port & Protocol Requirements

| Port | Protocol | Use |
|------|----------|-----|
| `443` | HTTPS | mTLS handshake (smart card-based login) |
| `53`, `88`, `389`, `636`, `464` | TCP/UDP | DNS, Kerberos, LDAP (between AD Connector and AD) |
| `4195` (TCP), `50002–50003` (UDP) | WSP | Session streaming and smart card redirection |

---

## ⚠️ Gotchas / Common Pitfalls

- ❌ **Multiple certificates** on CAC can confuse mapping.
- ❌ **No UPN** in SAN → mapping will fail.
- ❌ **Wrong EKU or missing OCSP** → cert fails validation.
- ❌ Domain controllers must use the **KDC Authentication** template — not generic domain controller certs.

---

## ✅ Summary

| Element | Description |
|--------|-------------|
| Authentication Type | **Mutual TLS (mTLS)** |
| Smart Card Use | **Pre-session** (login) |
| Redirection Required | Yes, for in-session use |
| Directory Type | **AD Connector** (not AWS Managed AD) |
| Revocation Checking | **OCSP required** |
| Identity Mapping | Cert UPN → AD `userPrincipalName` |
| Protocols Used | HTTPS, Kerberos, WSP |

---

