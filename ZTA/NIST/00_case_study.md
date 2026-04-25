# Zero Trust Case Study — Enterprise-A with Contractor-Operated Cloud Enclave
## A Practical Walkthrough of Split-Control Zero Trust for a Contractor-Managed AWS Environment

*Companion case study to the Zero Trust Enterprise Implementation Guide.*
*Scenario is synthetic but represents a very common pattern in regulated industries, federal programs, and large-enterprise M&A environments.*

---

## 1. The Scenario

### 1.1 Enterprise-A Profile
- **Size:** 50,000 users
- **Footprint:** Multiple on-prem data centers, multiple cloud tenants, 8 departments (Dept-A through Dept-H)
- **Identity foundation:** Microsoft **Entra Tenant-A** is the authoritative identity source for all 50,000 users
- **Endpoints:** All employee laptops, desktops, and mobile devices are enrolled in Enterprise-A's UEM (Intune) and EDR (Defender for Endpoint)
- **Departments:** Each department owns its own applications, servers, and user base. Dept-A through Dept-G are mostly on-prem with some hybrid cloud.

### 1.2 Dept-H's Unique Situation
- Dept-H is migrating a subset of its applications and servers to **AWS**.
- Dept-H does **not** run this AWS environment itself. It has contracted the work to **Contractor-Y**.
- Contractor-Y provisions, operates, and maintains the AWS infrastructure (VPCs, EC2, RDS, Lambda, EKS, S3, etc.) and the applications running on top of it.
- Contractor-Y has its own **Entra Tenant-Y** that federates with the AWS-hosted applications via **SAML or OIDC**, so that Enterprise-A users can log in to the cloud apps.

### 1.3 The Split-Control Problem

This is where most Zero Trust conversations in this pattern break down:

| Control domain | Who owns it |
|----------------|-------------|
| **User identities** (50,000 users) | **Enterprise-A** (Entra Tenant-A) |
| **User devices** (laptops, phones, Intune/Defender posture) | **Enterprise-A** |
| **Network from user to cloud** (corporate network, VPN, SASE edge) | **Enterprise-A** |
| **AWS tenant, VPCs, workloads, databases, IAM roles** | **Contractor-Y** |
| **Application code and configuration in AWS** | **Contractor-Y** |
| **Federation tenant** (Entra Tenant-Y) that wraps the AWS apps | **Contractor-Y** |
| **Contractor-Y's own workforce** (engineers with admin access to the AWS estate) | **Contractor-Y** |

**Neither party controls the full access path.** Enterprise-A owns the user and the device; Contractor-Y owns the resource and the surrounding infrastructure. Somewhere in the middle sits a federation trust between two Entra tenants.

A naïve answer is: *"Contractor-Y signs in Enterprise-A users via SAML and that's Zero Trust enough."* It is not. SSO is the *starting* point, not Zero Trust.

This case study walks through the correct split of responsibilities, the federation pattern, the signals that must flow between the two parties, and a concrete implementation plan.

---

## 2. The Current-State Architecture (Before Zero Trust)

Here is what Dept-H's access typically looks like today:

```
┌──────────────────────────────────────────────┐      ┌──────────────────────────────────────────────┐
│              ENTERPRISE-A                    │      │              CONTRACTOR-Y                    │
│                                              │      │                                              │
│  ┌───────────────────┐                       │      │                       ┌──────────────────┐   │
│  │  Entra Tenant-A   │                       │      │                       │ Entra Tenant-Y   │   │
│  │  50,000 users     │                       │      │                       │ (wrapper tenant  │   │
│  │  Groups, MFA,     │                       │      │                       │  for AWS apps)   │   │
│  │  Conditional Acc. │                       │      │                       └────────┬─────────┘   │
│  └─────────┬─────────┘                       │      │                                │             │
│            │                                 │      │                                │ SAML/OIDC   │
│            │ Federation                      │      │                                ▼             │
│            │ trust ──────────────────────────┼──────┼──▶ (SAML/OIDC relay)          │              │
│            │                                 │      │                                │             │
│  ┌─────────▼─────────┐       ┌──────────┐    │      │      ┌──────────────────────────────────┐    │
│  │  User laptop      │       │  Dept-H  │    │      │      │         AWS Account Y            │    │
│  │  (Intune+Defender │──────▶   user   │────┼──────┼─────▶│  ┌────────┐  ┌────────┐ ┌─────┐ │    │
│  │   managed)        │       │          │    │      │      │  │App EC2 │  │  RDS   │  │ S3  │ │    │
│  └───────────────────┘       └──────────┘    │      │      │  └────────┘  └────────┘  └─────┘ │    │
│                                              │      │      │  Operated and administered       │    │
│                                              │      │      │  entirely by Contractor-Y        │    │
│                                              │      │      └──────────────────────────────────┘    │
└──────────────────────────────────────────────┘      └──────────────────────────────────────────────┘

Typical weaknesses in this state:
  ❌ Contractor-Y trusts the SAML assertion only — no device posture
  ❌ Enterprise-A has no visibility into what happens inside AWS after sign-in
  ❌ Contractor-Y admin accounts often have long-lived AWS IAM keys
  ❌ No microsegmentation inside Contractor-Y's AWS VPCs
  ❌ No continuous re-evaluation — a valid SAML token grants hours of access
  ❌ Offboarding is best-effort: when Enterprise-A disables a user, does it propagate?
  ❌ Audit logs sit in two places; nobody has a unified view
```

---

## 3. The Correct Split of Zero Trust Responsibilities

In a split-control model, each party must own its half of the Zero Trust architecture, and the two halves must communicate through well-defined trust boundaries. The following table is the architectural contract that Enterprise-A and Contractor-Y should agree on as the basis of their Zero Trust program.

### 3.1 The Responsibility Matrix

| Zero Trust Layer | Enterprise-A's responsibility | Contractor-Y's responsibility | Shared / Contract-defined |
|------------------|-------------------------------|-------------------------------|---------------------------|
| **L1 — Identity source of truth** | Maintain authoritative user records in Entra Tenant-A | — | — |
| **L1 — Group membership for Dept-H** | Maintain `Dept-H-Users`, `Dept-H-Admins`, role groups | — | Agreed group schema and naming |
| **L2 — Primary authentication** | Perform MFA, passkey, risk-based sign-in in Tenant-A | — | Minimum assurance level (e.g., FIDO2 for admins, TOTP/push for users) |
| **L2 — Device posture** | Verify Intune compliance, Defender status, OS patch level | — | Posture claims passed in SAML assertion or via CAE signals |
| **L3 — Federation protocol** | Issue SAML/OIDC tokens with required claims | Consume tokens; trust Tenant-A's IDP | **Contract: token lifetime, claim schema, signature algorithms** |
| **L3 — Tenant-Y's role** | — | Tenant-Y acts as a **federation broker / relying party**, not as a separate source of truth | Tenant-Y must NOT create shadow local accounts |
| **L4 — Authorization (coarse)** | Assign Dept-H group membership | Map Tenant-A groups to AWS IAM roles / app permissions | Agreed group-to-role mapping |
| **L4 — Authorization (fine-grained)** | — | Enforce per-resource, per-action policy inside AWS apps | — |
| **L5 — Network path** | Route user traffic via SASE / ZTNA edge to Contractor-Y's AWS | Publish apps behind an AWS-side PEP (ALB + WAF, AWS Verified Access, or a ZTNA connector) | **Mutual TLS or private connectivity (AWS PrivateLink) preferred** |
| **L5 — AWS-side microsegmentation** | — | Segment VPCs, enforce VPC Lattice / Security Groups, limit east-west | — |
| **L5 — AWS-side workload identity** | — | Use IAM Roles, IAM Roles Anywhere, or IRSA (IAM Roles for Service Accounts) — **no long-lived keys** | — |
| **L6 — Continuous evaluation** | Emit CAEP / Shared Signals on user or device risk change | Subscribe to CAEP signals; terminate session on revocation | **CAEP contract: event types, latency SLO** |
| **L7 — Data protection** | Classify data before it leaves Tenant-A (Purview labels) | Honor labels inside AWS (encryption, DLP, export restrictions) | **Data classification schema must be shared** |
| **L8 — Audit** | Log all sign-ins, MFA events, CAEP signals to Enterprise-A SIEM | Log all AWS CloudTrail, VPC Flow, app-level events to Contractor-Y SIEM | **Log-sharing contract: which events, what retention, what cadence** |
| **L9 — Offboarding** | Disable user in Tenant-A immediately on HR event | Auto-revoke within N minutes via CAEP + IAM Identity Center SCIM | **SLA: e.g., revocation within 5 minutes of disable** |
| **L10 — Contractor-Y's own admins** | — | Manage contractor admin identities with their own MFA, PAM, just-in-time AWS admin access | Enterprise-A has audit rights over admin access |

### 3.2 The One-Sentence Rule Per Party

- **Enterprise-A's rule:** *"We own who the user is and how healthy their device is. We emit strong, signed, continuously-verifiable claims about both."*
- **Contractor-Y's rule:** *"We own the resource, the infrastructure, and what happens inside AWS. We make every access decision contingent on Enterprise-A's claims plus our own resource-side policy, and we honor revocations in near-real-time."*

---

## 4. The Target-State Architecture

Here is the target architecture, showing where each Zero Trust component lives, who owns it, and how the two halves connect.

```
┌──────────────────────────────────────────────────────┐          ┌──────────────────────────────────────────────────────┐
│                 ENTERPRISE-A (owns)                  │          │                CONTRACTOR-Y (owns)                   │
│                                                      │          │                                                      │
│  ╔══════════════════════════════════════════════╗    │          │    ╔══════════════════════════════════════════════╗  │
│  ║  L1: Entra Tenant-A — Source of Truth        ║    │          │    ║  Entra Tenant-Y — Federation Broker ONLY     ║  │
│  ║  • 50k users, Dept-H groups                  ║    │          │    ║  • No shadow local accounts                  ║  │
│  ║  • HRIS sync (Workday → SCIM)                ║    │          │    ║  • Trusts Tenant-A as upstream IDP           ║  │
│  ╚══════════════╦═══════════════════════════════╝    │          │    ║  • Maps Tenant-A groups → AWS IAM roles      ║  │
│                 ║                                    │          │    ╚══════════════════════════╦═══════════════════╝  │
│  ╔══════════════▼═══════════════════════════════╗    │          │                               ║                      │
│  ║  L2: Primary Authentication                  ║    │          │    ╔═══════════════════════════▼═══════════════════╗  │
│  ║  • Passkey / FIDO2 / MFA                     ║    │          │    ║  AWS IAM Identity Center (formerly SSO)       ║  │
│  ║  • Conditional Access policies:              ║    │  SAML or │    ║  • Issues short-lived AWS credentials         ║  │
│  ║    - Require managed device                  ║╌╌╌╌┼╌OIDC w/ ╌┼╌╌▶ ║  • Receives SCIM from Tenant-Y (forwarded     ║  │
│  ║    - Require compliant posture               ║    │  device  │    ║    from Tenant-A)                             ║  │
│  ║    - Sign-in risk < Medium                   ║    │  claims  │    ║  • CAEP subscriber: revokes on signal         ║  │
│  ║    - Require re-auth every N hours           ║    │          │    ╚══════════════════════════╦═══════════════════╝  │
│  ║  • Emits signed device+user claims in token  ║    │          │                               ║                      │
│  ╚══════════════╦═══════════════════════════════╝    │          │    ╔══════════════════════════▼═══════════════════╗  │
│                 ║                                    │          │    ║  L5: AWS-side PEP                             ║  │
│  ╔══════════════▼═══════════════════════════════╗    │          │    ║  Option A: AWS Verified Access (ZTNA-native)  ║  │
│  ║  L2-PIP: Device Posture (Intune + Defender)  ║    │          │    ║  Option B: App Load Balancer + WAF + OIDC     ║  │
│  ║  • Compliance state                          ║    │          │    ║  Option C: 3rd-party ZTNA connector (Zscaler, ║  │
│  ║  • Patch level, encryption, EDR health       ║    │          │    ║            Appgate, Cloudflare, etc.)         ║  │
│  ║  • Signals exported to Tenant-A CA engine    ║    │          │    ╚══════════════════════════╦═══════════════════╝  │
│  ╚══════════════════════════════════════════════╝    │          │                               ║                      │
│                                                      │          │    ╔══════════════════════════▼═══════════════════╗  │
│  ╔══════════════════════════════════════════════╗    │          │    ║  L5: AWS Microsegmentation                    ║  │
│  ║  L5: User → Cloud Path                       ║    │          │    ║  • VPC Lattice for service-to-service         ║  │
│  ║  • SASE/SSE edge (optional but recommended): ║    │          │    ║  • Security groups + NACLs (least privilege)  ║  │
│  ║    Zscaler / Netskope / Defender for Cloud   ║    │          │    ║  • Private subnets for DB / backend tiers     ║  │
│  ║    Apps / Prisma Access                      ║    │          │    ║  • AWS PrivateLink from Enterprise-A's VPC    ║  │
│  ║  • Optional: AWS PrivateLink to Contractor-Y ║    │          │    ║    (if applicable) → no public internet path  ║  │
│  ╚══════════════════════════════════════════════╝    │          │    ╚══════════════════════════╦═══════════════════╝  │
│                                                      │          │                               ║                      │
│  ╔══════════════════════════════════════════════╗    │          │    ╔══════════════════════════▼═══════════════════╗  │
│  ║  L6: Continuous Evaluation (CAEP emitter)    ║    │          │    ║  L4: Fine-grained AuthZ inside app            ║  │
│  ║  • User disabled → revocation signal         ║╌╌╌╌┼╌╌CAEP ╌╌╌┼╌╌▶ ║  • Per-resource, per-action policy engine     ║  │
│  ║  • Device non-compliant → revocation         ║    │ Shared   │    ║    (Cedar / OPA / custom)                     ║  │
│  ║  • Risk escalation → step-up or revocation   ║    │ Signals  │    ║  • Feeds decision back to PEP                 ║  │
│  ╚══════════════════════════════════════════════╝    │ Framework│    ╚══════════════════════════╦═══════════════════╝  │
│                                                      │          │                               ║                      │
│  ╔══════════════════════════════════════════════╗    │          │    ╔══════════════════════════▼═══════════════════╗  │
│  ║  L7: Data Classification (Purview labels)    ║    │          │    ║  L5: AWS Workload Identity                    ║  │
│  ║  • Labels travel with the data               ║╌╌╌╌┼╌Purview╌╌┼╌╌▶ ║  • IAM Roles (no access keys)                 ║  │
│  ║                                              ║    │ SDK /    │    ║  • IAM Roles Anywhere for on-prem workloads   ║  │
│  ╚══════════════════════════════════════════════╝    │ label    │    ║    that need to reach AWS                     ║  │
│                                                      │ agent    │    ║  • IRSA for EKS pods                          ║  │
│  ╔══════════════════════════════════════════════╗    │          │    ║  • Secrets in AWS Secrets Manager / KMS       ║  │
│  ║  L8: SIEM (Microsoft Sentinel)               ║    │          │    ╚══════════════════════════╦═══════════════════╝  │
│  ║  • Entra sign-in logs                        ║    │          │                               ║                      │
│  ║  • Intune / Defender events                  ║    │          │    ╔══════════════════════════▼═══════════════════╗  │
│  ║  • Receives mirrored AWS security events     ║◀╌╌╌┼╌╌Log ╌╌╌╌┼╌╌  ║  L8: AWS-side Logging + SIEM                  ║  │
│  ╚══════════════════════════════════════════════╝    │ sharing  │    ║  • CloudTrail · VPC Flow · GuardDuty ·        ║  │
│                                                      │ (contract│    ║    Security Hub · WAF logs · App logs         ║  │
│                                                      │ defined) │    ║  • Mirrored/summarized events to Enterprise-A ║  │
│                                                      │          │    ╚═══════════════════════════════════════════════╝  │
└──────────────────────────────────────────────────────┘          └──────────────────────────────────────────────────────┘
                     OWNS THE USER + DEVICE                                          OWNS THE RESOURCE + PATH INSIDE AWS
```

---

## 5. The Federation Pattern — Done Right

The most technically interesting question in this scenario is: **how does the two-tenant federation work, and how do we avoid turning Entra Tenant-Y into a second source of truth?**

### 5.1 The Two Wrong Ways

1. **"Tenant-Y creates local copies of Enterprise-A users."** Shadow accounts drift, are not cleaned up on offboarding, and create audit nightmares. ❌
2. **"Just federate and trust the SAML assertion."** No device posture, no continuous evaluation, no revocation. This is the current broken state. ❌

### 5.2 The Right Way — Entra-to-Entra Cross-Tenant B2B Federation with Posture Claims

Microsoft Entra supports **Cross-Tenant Access Settings** and **Cross-Tenant Access Policies (XTAP)** that let Tenant-Y accept users from Tenant-A with specific inbound trust rules. The pattern looks like this:

```
 ┌─────────────────────┐                                ┌─────────────────────┐
 │  Entra Tenant-A     │                                │  Entra Tenant-Y     │
 │  (Home tenant)      │                                │  (Resource tenant)  │
 │                     │                                │                     │
 │  User authenticates │                                │  Configured to:     │
 │  with:              │                                │  • Trust MFA claims │
 │  • Passkey / MFA    │                                │    from Tenant-A    │
 │  • Managed device   │────── Cross-tenant ─────────▶  │  • Trust compliant- │
 │  • Compliant device │       B2B federation           │    device claims    │
 │  • Risk evaluated   │       with inbound trust        │    from Tenant-A    │
 │                     │       settings (XTAP)           │  • NOT require own  │
 │  Conditional Access │                                │    MFA re-prompt    │
 │  policy ensures all │                                │                     │
 │  of above BEFORE    │                                │  Tenant-Y applies   │
 │  token is issued    │                                │  its OWN CA policy: │
 │                     │                                │  • Block unmanaged  │
 │                     │                                │    devices even if  │
 │                     │                                │    Tenant-A says OK │
 │                     │                                │  • Session lifetime │
 │                     │                                │    cap              │
 │                     │                                │  • App-specific CA  │
 └─────────┬───────────┘                                └──────────┬──────────┘
           │                                                       │
           │   SAML or OIDC token issued to target AWS app         │
           │   with claims:                                        │
           │     - sub (user objectId)                             │
           │     - UPN / email                                     │
           │     - groups (Dept-H-*)                               │
           │     - authnContextClassRef (mfa / phishing-resistant) │
           │     - deviceId + compliant=true (if passed through)   │
           └────────────────────────┬──────────────────────────────┘
                                    ▼
                        ┌─────────────────────────┐
                        │   AWS-hosted Dept-H app │
                        │   validates token,      │
                        │   maps groups → roles,  │
                        │   enforces authz        │
                        └─────────────────────────┘
```

**Key configuration points:**
- Tenant-Y's **Cross-Tenant Access Settings** for Tenant-A: *"Trust MFA from Azure AD home tenant"* and *"Trust compliant device claims from Azure AD home tenant"* are enabled.
- Tenant-Y applies its **own** Conditional Access policies on top — belt and suspenders. Even if Tenant-A says the device is compliant, Tenant-Y can further restrict (e.g., require FIDO2 for admin apps, block countries, cap session lifetime).
- **No users are created in Tenant-Y.** Dept-H users appear in Tenant-Y as B2B guest objects that are pointers back to Tenant-A.
- Offboarding is automatic: if Enterprise-A disables the user in Tenant-A, the B2B guest in Tenant-Y becomes unusable on next token refresh — and within minutes if CAEP is enabled.

### 5.3 What the Token Must Carry

The SAML assertion (or OIDC ID token) from Tenant-A to Tenant-Y, and onward to the AWS app, must carry at minimum:

| Claim | Purpose | Example value |
|-------|---------|---------------|
| `sub` / `oid` | Immutable user identifier | `a1b2c3d4-...` (Entra objectId) |
| `upn` / `email` | Human-readable identity | `alice.smith@enterprise-a.com` |
| `groups` | Authorization coarse-grain | `Dept-H-Users`, `Dept-H-FinanceReaders` |
| `amr` or `authnContextClassRef` | Authentication methods used | `mfa`, `fido`, `phishing-resistant` |
| `acr` | Assurance level | `urn:mace:incommon:iap:silver` or FAL/IAL label |
| `deviceId` + `isCompliant` | Posture from Intune | `deviceId=...`, `isCompliant=true` |
| `tenantId` | Origin tenant | Tenant-A's tenant ID |
| `iat`, `exp`, `nbf` | Token lifetime | Short (< 1 hour recommended) |
| `aud` | Target audience | The AWS app's client ID |

**Keep the token lean.** Don't stuff hundreds of groups into it. If granular authorization is needed, let the AWS app query a PDP (Cedar / OPA) at runtime using the `sub` as the principal.

---

## 6. Component-by-Component Implementation Plan

### 6.1 What Enterprise-A Must Build or Harden

#### 6.1.1 Conditional Access for Dept-H Cloud Apps (L2)
Create a Conditional Access policy in Tenant-A targeted at the Tenant-Y applications:
- **Assignments:** Users & groups = `Dept-H-Users`; Cloud apps = Tenant-Y federation app + all AWS-hosted apps
- **Conditions:** Device platforms (Windows, macOS, iOS, Android); sign-in risk = Low only; client apps = Browser + Modern auth
- **Grant controls:**
  - Require MFA (passkey / FIDO2 preferred)
  - Require Hybrid Azure AD joined OR require device marked compliant (Intune)
  - Require approved client app (for mobile)
- **Session controls:**
  - Sign-in frequency = e.g., 8 hours for users, 1 hour for admins
  - Use app-enforced restrictions
  - Use Continuous Access Evaluation (enable if not already)

#### 6.1.2 Intune Compliance Policies (L2-PIP)
Policies must verify at minimum:
- OS version at or above N-1
- Disk encryption (BitLocker / FileVault)
- Defender for Endpoint healthy, not in passive mode
- Screen lock enabled
- Not jailbroken / rooted
- Threat level from MDE ≤ Medium

Non-compliant devices are blocked at the CA layer.

#### 6.1.3 Enable Continuous Access Evaluation (L6)
CAE is native to Entra. Turn it on and confirm the relying applications on the Tenant-Y side are CAE-aware. When CAE is enabled, tokens can be revoked within minutes instead of waiting for expiry.

#### 6.1.4 Data Classification (L7)
Roll out Microsoft Purview Information Protection labels that classify Dept-H data before it is uploaded to AWS. Labels are embedded in the file metadata; when the file reaches AWS, a Purview-aware DLP or CASB can honor them.

#### 6.1.5 User → Cloud Path Protection (L5)
If Enterprise-A already runs SASE/SSE (Zscaler, Netskope, Defender for Cloud Apps, Prisma Access, etc.), route user traffic to Tenant-Y's AWS apps through it so that:
- DLP inspects uploads/downloads
- CASB enforces session controls
- Unmanaged device access is blocked at the SASE layer even if CA somehow allows it

Optionally, stand up **AWS PrivateLink** from Enterprise-A's network into Contractor-Y's AWS account for critical apps so that user traffic never touches the public internet.

#### 6.1.6 SIEM Integration (L8)
Enterprise-A's Sentinel should ingest:
- All Tenant-A sign-in logs
- All CA policy evaluations
- Intune compliance change events
- Defender for Endpoint alerts
- **Mirrored AWS security events from Contractor-Y** (per contract, see §6.2.6)

### 6.2 What Contractor-Y Must Build or Harden

#### 6.2.1 Tenant-Y as Federation Broker Only (L1/L3)
- Configure Cross-Tenant Access Settings to inbound-trust Tenant-A for MFA and compliant-device claims.
- **Do not create local user accounts for Enterprise-A users.** Use B2B.
- Apply Tenant-Y's own Conditional Access on top for defense in depth (block unmanaged, cap session, require step-up for sensitive apps).

#### 6.2.2 AWS IAM Identity Center (formerly AWS SSO)
- Federate IAM Identity Center to Tenant-Y via SAML.
- Define **permission sets** that map Tenant-A group claims → AWS role assignments.
- Identity Center issues **short-lived** AWS credentials on every sign-in. **No long-lived IAM access keys for Enterprise-A users.**

#### 6.2.3 AWS-Side PEP (L5)
Pick **one** of these three patterns, driven by app type:

**Option A — AWS Verified Access (AWS-native ZTNA):**
- Use when the app is HTTPS and you want AWS-native policy evaluation with Cedar.
- Verified Access evaluates identity (from Tenant-Y/Entra) plus device-trust signals (Jamf, CrowdStrike, Jumpcloud) on every request.
- Corresponds to NIST SP 1800-35 build E4B5.

**Option B — ALB + WAF + OIDC:**
- Use when the app is off-the-shelf or stateful. The Application Load Balancer authenticates to Entra via OIDC before forwarding.
- Front it with AWS WAF for L7 protection.

**Option C — Third-party ZTNA connector:**
- Use when Enterprise-A already runs a ZTNA (Zscaler ZPA, Appgate, Netskope Private Access, Cloudflare Access). Contractor-Y deploys the connector next to the app in AWS, and Enterprise-A's users reach the app through the ZTNA broker.
- Gives Enterprise-A a single unified access experience across on-prem and Contractor-Y's cloud.
- Corresponds to NIST SP 1800-35 builds E1B3 (Zscaler), E1B4 (Appgate), E1B6 (Ivanti).

#### 6.2.4 AWS Microsegmentation (L5)
- **VPC Lattice** or strict **Security Groups / NACLs** between app tier, backend tier, and data tier.
- No direct internet path from the data tier. Private subnets only; egress via NAT gateway with strict rules.
- Database access only from the application's IAM role, never via shared creds.

#### 6.2.5 Workload Identity (L5)
- **No long-lived AWS access keys anywhere.**
- EC2 instances: **IAM instance roles**.
- EKS pods: **IRSA (IAM Roles for Service Accounts)**.
- External workloads that must reach AWS: **IAM Roles Anywhere** with X.509 certs from a trusted CA.
- Secrets: **AWS Secrets Manager** or **HashiCorp Vault**, with short TTL on dynamic secrets.
- Contractor-Y admins: **AWS IAM Identity Center + session-duration-capped** permission sets, backed by their own MFA + PAM (CyberArk, HashiCorp Boundary, Teleport).

#### 6.2.6 AWS-Side Observability (L8)
Always-on:
- CloudTrail (management + data events) to dedicated S3 with object lock
- VPC Flow Logs
- GuardDuty (threat detection)
- Security Hub (aggregation)
- Config (drift detection)
- WAF logs + ALB access logs
- Application-level audit logs

Per contract, a defined subset is mirrored to Enterprise-A's Sentinel — at minimum sign-in events, IAM Identity Center events, GuardDuty findings, and any event involving Enterprise-A user principals.

#### 6.2.7 Fine-Grained Authorization Inside the App (L4)
For apps that need per-record or per-action control (e.g., "Alice can read invoice #42 but not invoice #43"):
- Externalize policy to a PDP such as **AWS Verified Permissions (Cedar)**, **OpenFGA**, or **OPA** running inside the AWS account.
- App calls the PDP on every request; decision is logged.
- Policy is stored as code, versioned in Git, deployed via CI.

---

## 7. The Signals That Must Flow Between the Two Halves

Zero Trust in a split-control model lives or dies on the signals exchanged between the two parties. These are the four contracts you must sign:

### 7.1 Contract 1 — Token Claim Schema
Define exactly what claims Tenant-A will emit and Tenant-Y will consume. Version it. Any schema change is a change-controlled event.

### 7.2 Contract 2 — Provisioning (SCIM)
When a user joins `Dept-H-Users` in Tenant-A:
- Within N minutes, they appear as a B2B guest in Tenant-Y.
- Within N minutes, Tenant-Y's SCIM feed to AWS IAM Identity Center provisions their permission-set assignments.
- **Opposite direction on offboarding.** SLA must be defined (e.g., 5 minutes from disable to full revocation).

### 7.3 Contract 3 — Continuous Access Evaluation (CAEP / Shared Signals)
Events that trigger mid-session revocation:
- User disabled or deleted
- User's session risk elevated above threshold
- User's device marked non-compliant
- Admin-initiated password reset / token revocation
- Location / impossible-travel detection

CAEP events from Tenant-A flow to Tenant-Y, to AWS IAM Identity Center, and to the PEPs. Latency target: seconds, not hours.

### 7.4 Contract 4 — Log Sharing
Agree on:
- Which AWS events are shared back (CloudTrail, GuardDuty, IAM Identity Center, app logs)
- What format (typically JSON over a secure S3 bucket with cross-account access, or via a shared SIEM feed)
- Retention on both sides
- Privacy considerations (especially if Contractor-Y is in a different jurisdiction)

---

## 8. Mapping This Scenario to the Four NIST Deployment Approaches

| Approach | How it applies |
|----------|----------------|
| **EIG (Enhanced Identity Governance)** | Tenant-A + Intune + Defender + CA policies + CAE. This is the foundational layer. Corresponds to NIST build **E3B2** (EIG Run with Microsoft + Forescout). |
| **SDP / ZTNA** | The AWS-side PEP. Either **AWS Verified Access** (NIST build **E4B5**) or a third-party ZTNA connector (builds **E1B3**, **E1B4**, **E1B6**). |
| **Microsegmentation** | Inside Contractor-Y's AWS account: VPC Lattice + Security Groups + private subnets. Corresponds to builds **E4B5** and **E2B3**. |
| **SASE / SSE** | Enterprise-A's user-to-cloud inspection layer: Zscaler, Defender for Cloud Apps, Netskope, or equivalent. Corresponds to builds **E3B5** (Microsoft SSE), **E2B5** (Lookout + Okta). |

This scenario naturally ends up **combining three of the four approaches**: EIG + SDP + Microsegmentation, with SASE recommended on Enterprise-A's side.

---

## 9. Phased Rollout Plan (6 / 12 / 18 Months)

### Phase 1 — Foundation (0–6 months)
- [ ] Sign the **four-contract** framework (claims, SCIM, CAEP, logs) between Enterprise-A and Contractor-Y.
- [ ] Enterprise-A: Enforce Intune compliance + FIDO2 / passkey MFA for all Dept-H users via Conditional Access.
- [ ] Enterprise-A: Enable Continuous Access Evaluation in Tenant-A.
- [ ] Contractor-Y: Reconfigure Tenant-Y to use B2B cross-tenant access (eliminate shadow accounts).
- [ ] Contractor-Y: Enable CAE-awareness in Tenant-Y relying apps.
- [ ] Contractor-Y: Eliminate all long-lived IAM access keys for Enterprise-A users. Move to IAM Identity Center with short-lived creds.
- [ ] Contractor-Y: Deploy GuardDuty + Security Hub + Config. Mirror defined events to Enterprise-A's Sentinel.

### Phase 2 — PEP and Microsegmentation (6–12 months)
- [ ] Contractor-Y: Deploy AWS Verified Access (or chosen alternative) in front of all Dept-H apps.
- [ ] Contractor-Y: Implement VPC Lattice / SG segmentation for east-west traffic. No flat network inside the AWS account.
- [ ] Contractor-Y: Migrate workload identities to IAM roles / IRSA / IAM Roles Anywhere. Zero long-lived secrets.
- [ ] Enterprise-A: Route user traffic to Dept-H AWS apps via SASE/SSE edge for inspection and DLP.
- [ ] Enterprise-A: Deploy Purview classification to Dept-H data; align with Contractor-Y on how labels are honored in AWS.
- [ ] Joint: Run the NIST SP 1800-35 functional use cases (A through H) against this environment — especially Use Case C (Federated-ID Access) and Use Case F (Confidence Level / re-evaluation).

### Phase 3 — Fine-Grained AuthZ and Continuous Improvement (12–18 months)
- [ ] Contractor-Y: Externalize authorization inside Dept-H apps to Cedar / Verified Permissions / OpenFGA.
- [ ] Contractor-Y: Deploy a PAM solution for contractor admins (CyberArk, Teleport, HashiCorp Boundary).
- [ ] Joint: Establish quarterly access-recertification campaigns. SailPoint or Saviynt driven from Tenant-A, with attestation covering Dept-H AWS permissions.
- [ ] Joint: Quarterly red-team / breach-and-attack simulation against the AWS enclave (e.g., Mandiant Security Validation).
- [ ] Joint: Document a formal break-glass procedure for when Tenant-A is unavailable.

---

## 10. Key Risks and How This Architecture Mitigates Them

| Risk | Traditional approach | Zero Trust approach (this design) |
|------|----------------------|-----------------------------------|
| Enterprise-A user offboarded, still has AWS access for hours | SAML expiry only (hours) | CAEP revokes within minutes |
| Enterprise-A user on an unmanaged personal laptop accesses Dept-H data | Allowed (SAML succeeded) | Blocked: CA requires Intune-compliant device |
| Contractor-Y admin leaves Contractor-Y, still has AWS admin keys | Quiet until discovered | No long-lived keys; PAM session terminated; Identity Center assignment removed |
| Attacker steals Enterprise-A user's password | Could reach AWS app | Blocked: FIDO2 / passkey required; device posture required |
| Attacker compromises one app server in Contractor-Y's AWS | Pivots to database | Contained by microsegmentation + IAM role scoping |
| Long-lived SAML session allows attacker hours of use | Accept the risk | CAE + short token lifetime + AWS Verified Access re-eval per request |
| Enterprise-A has no visibility into what happens in AWS | Accept the risk | Log-sharing contract mirrors events to Sentinel |
| Contractor-Y has no visibility into user device health | Can't enforce | Device-posture claims carried in token; CA re-applied at Tenant-Y |
| Shadow SaaS / data exfiltration from Dept-H user's laptop | Invisible | SASE + Purview DLP on Enterprise-A side |

---

## 11. What Each Party Gains

**For Enterprise-A:**
- Retains authoritative control over its users and their access — even into contractor-operated environments.
- Gains visibility into Dept-H's AWS footprint via log sharing.
- Extends its existing Zero Trust investments (Intune, Defender, Sentinel, CA, Purview) into Contractor-Y's cloud.
- Instant offboarding reaches into AWS without a help-desk ticket.

**For Contractor-Y:**
- Offloads user authentication and device posture verification to Enterprise-A's mature stack.
- Focuses its security budget on what it uniquely controls: AWS infrastructure, app authorization, workload identity, microsegmentation.
- Gains a defensible posture that passes regulatory audits (FedRAMP, CMMC, SOC 2, ISO 27001).
- Reduces its insider-risk blast radius via PAM and workload identity.

**For Dept-H end users:**
- One sign-in (from their managed laptop with passkey) gets them into AWS-hosted apps.
- No separate credential to remember for Contractor-Y's environment.
- When they leave Enterprise-A, access ends immediately everywhere.

---

## 12. Closing — The Core Architectural Principle

Zero Trust in a split-control scenario works when each party **owns its half cleanly and exposes well-defined signals to the other half**. Enterprise-A owns "who and how" (identity + device). Contractor-Y owns "what and where" (resource + infrastructure). The federation isn't a trust shortcut — it is a signed, continuously-verified, revocable channel through which identity and posture claims flow, and through which revocations and audit signals flow back.

> **Get the contracts right, and the technology falls into place.**
> **Get the contracts wrong, and no amount of technology will save you.**

The four contracts — claim schema, SCIM, CAEP, log-sharing — are the architecture. Everything else is implementation detail.

---

*End of case study.*
