# Implementing Zero Trust in the Enterprise
## A Practical Guidance Document Synthesizing NIST SP 1800-35, NIST SP 800-207, and Modern Enterprise Identity Patterns

*Version 2.0 — Expanded Edition with Component Deep Dives, Deployment Approach Diagrams, and Example Products*

*Prepared from:*
- *NIST SP 1800-35, "Implementing a Zero Trust Architecture" (NCCoE, June 2025 — Final)*
- *NIST SP 1800-35 Full Document (web edition) at pages.nist.gov/zero-trust-architecture*
- *NIST SP 800-207, "Zero Trust Architecture" (foundational reference)*
- *Enterprise Identity Architecture: A Practitioner's Guide to Multi-Protocol Authentication and Authorization*
- https://pages.nist.gov/zero-trust-architecture/VolumeB/architecture.html#zta-in-operation
- https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.1800-35.pdf

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Foundational Concepts](#2-foundational-concepts-you-must-align-on-before-building)
3. [The Core ZTA Components — Deep Dive with Example Products](#3-the-core-zta-components--deep-dive-with-example-products)
4. [The Core Risk Model — Why Zero Trust Matters](#4-the-core-risk-model--why-zero-trust-matters)
5. [The Four Deployment Approaches — Detailed](#5-the-four-deployment-approaches--detailed)
6. [The Practical Seven-Step Journey](#6-the-practical-seven-step-journey-nist-aligned)
7. [The Multi-Protocol Reality](#7-the-multi-protocol-reality--not-every-app-speaks-modern-identity)
8. [The Authorization Journey](#8-the-authorization-journey--from-rbac-to-externalized-policy)
9. [Validation — Exercise Your ZTA](#9-validation--exercise-your-zta-against-these-use-cases)
10. [Governance and Lifecycle](#10-governance-and-lifecycle--the-often-missed-foundation)
11. [Reference Architecture — The Layered Fabric](#11-reference-architecture--the-layered-identity-fabric)
12. [Lessons from the Nineteen NIST Builds](#12-vendor-agnostic-lessons-from-the-nineteen-nist-builds)
13. [Three-Horizon Migration Roadmap](#13-a-three-horizon-migration-roadmap)
14. [Common Pitfalls](#14-common-pitfalls--and-how-to-avoid-them)
15. [Standards and Frameworks](#15-quick-reference--standards-and-frameworks-to-align-with)
16. [Closing](#16-closing--the-one-thing-to-remember)
- [Appendix A — NIST Builds & Policy Engines](#appendix-a--policy-engines-used-in-the-nist-sp-1800-35-builds)
- [Appendix B — Glossary](#appendix-b--glossary-of-key-acronyms)

---

## 1. Executive Summary

Zero Trust is not a product, a license, or a one-time project. It is an **enterprise cybersecurity strategy** grounded in a simple premise: **no user, device, application, or network location is implicitly trusted**. Every access request is verified, authorized, and continuously re-evaluated against policy — regardless of whether the request originates inside or outside the traditional network perimeter.

NIST SP 1800-35 operationalizes the concepts of NIST SP 800-207 through nineteen lab-validated example implementations ("builds") assembled by NCCoE with twenty-four technology collaborators. The key finding across all nineteen builds is consistent:

> **A zero trust architecture is achievable today using commercially available technology — but it is a journey, not a deployment. Most enterprises will evolve a ZTA incrementally from what they already own, beginning with identity, extending to endpoints and networks, and culminating in externalized policy-based access decisions and data-level controls.**

This guide translates the NIST findings into a step-by-step roadmap that an enterprise architect, CISO, or program manager can use to plan, justify, sequence, and execute a Zero Trust program.

---

## 2. Foundational Concepts You Must Align On Before Building

### 2.1 The Four Deployment Approaches at a Glance

NIST SP 1800-35 organizes its nineteen builds around four deployment approaches that can be combined. Each approach targets a different aspect of the access problem. They are **not mutually exclusive** — most mature architectures combine two or more.

1. **Enhanced Identity Governance (EIG)** — Identity-centric. Every access decision starts with *who* is requesting access and *what* their identity says about them.
2. **Software-Defined Perimeter (SDP)** — Network-centric. Resources are hidden until the user is authenticated and authorized; then a dynamic, secure tunnel is established.
3. **Microsegmentation** — Topology-centric. The network is sliced into many small, isolated segments, each protected individually.
4. **Secure Access Service Edge (SASE)** — Edge-centric. Security services (SWG, CASB, ZTNA, FWaaS, SD-WAN) are delivered from the cloud, close to the user.

Section 5 of this guide dives into each one with diagrams and example products.

### 2.2 Authentication vs. Authorization — Keep Them Separate

The single most common design error in enterprise identity is conflating AuthN and AuthZ:

| | Authentication (AuthN) | Authorization (AuthZ) |
|---|---|---|
| **Question** | Who are you? | What are you allowed to do? |
| **When** | At login or token issuance | At every resource access |
| **Typical output** | Token / session / assertion | Permit / Deny decision |
| **Changes** | Rare (per session) | Frequent (per request) |
| **Standards** | SAML, OIDC, WebAuthn, Kerberos | XACML, OPA/Rego, Cedar, Zanzibar |
| **Failure mode** | Login fails | 403 Forbidden |

**Architect's rule of thumb:** *If a change requires the user to log in again, it's AuthN. If a change takes effect on the next request, it's AuthZ.*

Zero Trust requires both, continuously — not just at the front door.

---

## 3. The Core ZTA Components — Deep Dive with Example Products

This section is the conceptual backbone of the guide. Every Zero Trust architecture, regardless of vendor or deployment approach, reduces to a small set of logical components working together. Understanding each one — what it does, how it talks to the others, and which commercial products play the role — is a prerequisite to reading any vendor architecture diagram.

### 3.1 The End-to-End Decision Flow

Here is what happens on every access request in a Zero Trust architecture:

```
                          ┌─────────────────────────────────────────────┐
                          │            POLICY INFORMATION POINTS (PIP)  │
                          │   ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌───┐ │
                          │   │ ICAM │ │ EDR/ │ │ UEM/ │ │ SIEM │ │DLP│ │
                          │   │      │ │ EPP  │ │ MDM  │ │ SOAR │ │   │ │
                          │   └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └─┬─┘ │
                          └──────┼────────┼────────┼────────┼───────┼───┘
                                 │  context / signals feeding decisions │
                                 ▼        ▼        ▼        ▼       ▼
                          ┌─────────────────────────────────────────────┐
                          │          POLICY DECISION POINT (PDP)        │
                          │       ┌─────────────┐   ┌──────────────┐    │
     (3) "Can Alice       │       │   Policy    │──▶│    Policy    │    │
       access X?"         │       │  Engine(PE) │   │ Admin. (PA)  │    │
           ──────────────▶│       │ evaluates   │   │ issues token/│    │
                          │       │  policy     │   │ session cmd  │    │
                          │       └─────────────┘   └──────┬───────┘    │
                          └───────────────────────────────┼─────────────┘
                                        ▲                 │
                                        │ (4) decision:   │ (5) establish /
                             (2) "need a│     permit /    │     terminate
                                  decision" deny / limit  │     session
                                        │                 ▼
 ┌──────────────┐        (1) access    ┌────────────────────────────────┐       (6) allowed
 │  SUBJECT     │────────request──────▶│   POLICY ENFORCEMENT POINT     │──────traffic──────▶ ┌──────────┐
 │ (user,svc,   │◀────(7) continuous──▶│          (PEP)                 │◀─────flows─────────│ RESOURCE │
 │  workload)   │      reverification  │  gateway / proxy / agent /     │                     │(app, API,│
 │  + endpoint  │                      │  firewall / broker             │                     │ data,    │
 └──────────────┘                      └────────────────────────────────┘                     │ VM, S3…) │
                                                                                              └──────────┘
```

The numbered steps:
1. A subject (user + endpoint, or a workload) requests access to a resource.
2. The PEP does **not** make the decision — it asks the PDP.
3. The PE queries all the PIPs for relevant context.
4. The PE evaluates policy against the context and renders a decision.
5. The PA tells the PEP to permit, deny, or limit, and issues any required session artefacts.
6. If permitted, traffic flows through (or via a tunnel established by) the PEP.
7. The session is **continuously re-evaluated**. If a signal changes (device falls out of compliance, risk score rises, user attempts an unauthorized action), access is revoked mid-session.

Now let's unpack each component.

### 3.2 Policy Enforcement Point (PEP) — "The Gatekeeper"

**Role.** The PEP sits directly in the data path between the subject and the resource. It intercepts access requests, asks the PDP for a decision, and enforces that decision by permitting, denying, rate-limiting, or terminating traffic. The PEP has no independent decision logic — it is a pure enforcer.

**Where it lives.** The PEP is not one thing. Depending on the resource being protected, a PEP can be:

| PEP type | What it is | Where it enforces |
|----------|-----------|-------------------|
| **Network gateway** | Firewall, router, or NAC appliance | Network perimeter or segment boundary |
| **Application gateway** | Reverse proxy, load balancer, API gateway | In front of a web app or API |
| **Host agent** | Software installed on the endpoint | On the endpoint itself (inbound and outbound) |
| **Cloud broker** | Cloud-delivered proxy (SASE / SSE / ZTNA) | Between the user and a SaaS or cloud app |
| **Identity-aware proxy** | Reverse proxy that understands OIDC/SAML | Between the user and a legacy web app |
| **Sidecar proxy** | Per-workload proxy in a service mesh | Between microservices |

**Example products (from NIST SP 1800-35 builds and the broader market):**
- **Network PEPs:** Palo Alto Networks NGFW, Cisco Secure Firewall, Fortinet FortiGate, F5 BIG-IP, Check Point NGFW
- **ZTNA / SDP PEPs:** Zscaler Private Access (ZPA) Connector, Appgate SDP Gateway, Cloudflare Access, Google BeyondCorp / IAP, Netskope Private Access, Palo Alto Prisma Access, Cisco Duo Network Gateway
- **Identity-Aware Proxy:** Azure App Proxy (Microsoft Entra Application Proxy), Cloudflare Access, Google IAP, F5 APM, NGINX Plus, Pomerium
- **Host-based / microsegmentation agents:** Illumio, Akamai Guardicore, VMware NSX-T, Cisco Secure Workload (Tetration), Microsoft Defender for Endpoint
- **API gateways:** Apigee, AWS API Gateway, Kong, Azure API Management
- **Service mesh sidecars:** Istio (Envoy), Linkerd, Consul Connect
- **SASE / SSE edge:** Zscaler Internet Access (ZIA), Netskope, Symantec (Broadcom) Cloud SWG, Cisco+ Secure Connect, Palo Alto Prisma Access, Cato Networks, Lookout SSE

**Key design point.** An enterprise ZTA **always has many PEPs**, not one. A single application may sit behind two or three PEPs simultaneously (e.g., a SASE edge + an identity-aware proxy + a host agent on the server).

### 3.3 Policy Decision Point (PDP) — "The Brain"

The PDP is the combination of the **Policy Engine (PE)** and the **Policy Administrator (PA)**. NIST SP 800-207 separates them logically; most commercial products combine them.

#### 3.3.1 Policy Engine (PE) — "The Judge"

**Role.** The PE receives access queries from PEPs, gathers context from PIPs, evaluates the applicable policy, and issues a decision: **permit, deny, or limit** (with conditions or obligations).

**Inputs the PE uses:**
- **Subject identity and attributes** — user, group memberships, role, clearance level, employment status
- **Endpoint posture** — managed/unmanaged, OS version, patch level, disk encryption, EDR status, jailbreak/root status
- **Resource metadata** — criticality, data classification, owner, location
- **Contextual signals** — time of day, geo-location, network (corporate / home / hostile country), device ID, session risk score
- **Behavioral signals** — deviation from normal patterns, recent failed logins, impossible travel
- **External threat intel** — is this IP/user/device flagged?
- **Policy** — the rules themselves (who may do what, when, under what conditions)

**Example products (PDPs / Policy Engines in the NIST builds):**
- Microsoft Entra ID Conditional Access (formerly Azure AD Conditional Access)
- Okta Identity Cloud + Okta Policy
- Ping Identity PingFederate / PingOne
- IBM Security Verify
- Zscaler ZPA Central Authority
- Cisco Identity Services Engine (ISE) + Secure Workload
- Appgate SDP Controller
- Ivanti Neurons for Zero Trust Access
- F5 BIG-IP Access Policy Manager (APM)
- Palo Alto Networks Cloud Identity Engine + Prisma
- AWS Verified Access + Amazon VPC Lattice
- Google Chrome Enterprise Premium — Access Context Manager
- VMware Workspace ONE Access
- Lookout SSE
- Symantec (Broadcom) Cloud SWG / ZTNA / CASB

**Dedicated authorization engines (emerging category):**
- AWS Verified Permissions / Cedar
- Open Policy Agent (OPA)
- OpenFGA
- SpiceDB / Authzed
- Permit.io
- Oso

#### 3.3.2 Policy Administrator (PA) — "The Bailiff"

**Role.** Once the PE renders a decision, the PA **executes** it by instructing the PEP to open, modify, or close the session. For a permit, the PA may issue a session token, generate a short-lived certificate, open a firewall rule, or establish a secure tunnel. For a deny, the PA ensures the PEP refuses or terminates the traffic.

In most commercial products, PE and PA are fused into a single engine. The distinction matters mostly for understanding what is happening under the hood and for troubleshooting.

### 3.4 Policy Information Points (PIPs) — "The Witnesses"

**Role.** PIPs feed the PE with the context it needs. Every PIP is a supporting system — a specialized security or identity tool — that the PE queries (or subscribes to) for real-time facts. **The quality of a ZTA's decisions is a direct function of the quality of its PIP integrations.** A PDP with rich PIP inputs makes smart, granular, contextual decisions. A PDP with poor inputs is just a glorified firewall rule.

#### 3.4.1 ICAM — Identity, Credential, and Access Management

**What it provides to the PE:** authenticated user identity, group/role membership, MFA method strength, session age, authentication assurance level, federated-identity attributes.

**Example products:**
- **Cloud IDPs:** Microsoft Entra ID, Okta Workforce Identity, Ping Identity PingOne, ForgeRock/Ping, IBM Security Verify, Google Cloud Identity, OneLogin, JumpCloud
- **On-prem / hybrid:** Microsoft Active Directory, Radiant Logic RadiantOne (virtual directory), 389 Directory Server
- **MFA / passwordless:** Okta Verify, Microsoft Authenticator, Cisco Duo, YubiKey (FIDO2), Windows Hello, Apple Passkeys
- **Identity governance (IGA):** SailPoint IdentityIQ, Saviynt, Omada, Oracle Identity Governance
- **Privileged Access Management (PAM):** CyberArk, BeyondTrust, Delinea (formerly Thycotic), HashiCorp Boundary, Teleport

#### 3.4.2 Endpoint Security — EDR / EPP / UEM / MDM

**What it provides to the PE:** device compliance state, OS patch level, encryption status, AV/EDR health, managed/unmanaged status, jailbreak/root detection, presence of DLP agent.

**Example products:**
- **EDR / EPP:** Microsoft Defender for Endpoint, CrowdStrike Falcon, SentinelOne, Palo Alto Cortex XDR, Trellix, Sophos Intercept X, PC Matic Pro, VMware Carbon Black
- **UEM / MDM:** Microsoft Intune, Omnissa (formerly VMware Workspace ONE) UEM, Ivanti Neurons for UEM, IBM MaaS360, Jamf (Apple), Google Endpoint Management
- **Mobile threat defense:** Lookout Mobile Endpoint Security, Zimperium, Check Point Harmony Mobile
- **Device posture / NAC:** Forescout eyeSight / eyeControl / eyeSegment, Cisco ISE, Aruba ClearPass

#### 3.4.3 Security Analytics — SIEM / SOAR / UEBA

**What it provides to the PE:** real-time risk scores, suspicious-behavior flags, correlation across many events (e.g., "same user just failed 50 logins elsewhere"), incident context.

**Example products:**
- **SIEM:** Microsoft Sentinel, IBM QRadar XDR, Splunk Enterprise Security, Elastic Security, Google Chronicle, Sumo Logic, LogRhythm, Exabeam
- **SOAR:** Splunk SOAR (Phantom), Palo Alto Cortex XSOAR, Google Chronicle SOAR (Siemplify), IBM QRadar SOAR, Swimlane
- **UEBA / analytics:** Exabeam, Varonis, Microsoft Defender for Identity, Splunk UBA
- **Breach & attack simulation:** Mandiant Security Validation (MSV), AttackIQ, SafeBreach, Cymulate — used in every NIST SP 1800-35 build to verify controls

#### 3.4.4 Data Security

**What it provides to the PE:** data classification, sensitivity labels, DLP policy decisions, rights-management state, data-in-motion inspection results.

**Example products:**
- **DLP:** Microsoft Purview DLP, Symantec (Broadcom) DLP, Forcepoint DLP, Digital Guardian, Trellix DLP
- **Information classification / rights management:** Microsoft Purview Information Protection, Virtru, Seclore, Fasoo
- **CASB:** Microsoft Defender for Cloud Apps, Netskope, Zscaler, Symantec CloudSOC, Palo Alto SaaS Security
- **Encryption / key management:** IBM Security Guardium, AWS KMS, Azure Key Vault, HashiCorp Vault, Thales CipherTrust

#### 3.4.5 Threat Intelligence & Certificate / PKI

**What it provides:** indicators of compromise, reputation scores, certificate validity, TLS inspection context.

**Example products:**
- **Threat intel:** Mandiant, Recorded Future, Anomali, CrowdStrike Intel, MISP (open-source)
- **PKI / certificates:** DigiCert CertCentral / ONE, Entrust, Let's Encrypt, AWS Certificate Manager, Venafi, HashiCorp Vault PKI — used by every NIST SP 1800-35 build

### 3.5 The Subject — Users, Workloads, and Devices

In Zero Trust, a **subject** is anything requesting access: a human user, a service account, a workload (container, function, VM), or a device acting autonomously. Every subject must be identifiable, authenticatable, and authorizable.

**For humans,** identity comes from the IDP + MFA.

**For workloads,** identity increasingly comes from **workload identity frameworks**:
- SPIFFE / SPIRE (open standard)
- AWS IAM Roles Anywhere
- Microsoft Entra Workload Identity
- HashiCorp Vault dynamic secrets
- Kubernetes Service Accounts + OIDC projection

Workload identity replaces long-lived API keys and passwords-in-config-files with short-lived, attestable credentials. It is the next frontier of Zero Trust.

### 3.6 The Resource — Applications, Data, APIs, Services

A **resource** is anything being accessed: a SaaS app, an API endpoint, a database, a file share, an S3 bucket, a Kubernetes pod, a VM, an IoT device. In Zero Trust, **every resource is protected individually**, not as a member of a trusted perimeter.

A mature ZTA also authenticates and verifies the health of the resource-side endpoint (the server or service hosting the resource) — not just the requester. NIST SP 1800-35 explicitly flags this as a common gap: most EIG Crawl builds only verified the requester, leaving the resource side effectively trusted.

---

## 4. The Core Risk Model — Why Zero Trust Matters

Traditional perimeter defense assumes that anything inside the network is trustworthy. Three modern realities have broken that assumption:

1. **Cloud.** Critical resources (databases, applications, servers) live outside the enterprise perimeter — in IaaS, SaaS, and multi-tenant platforms. The perimeter can no longer protect them.
2. **Hybrid workforce and third parties.** Employees, contractors, partners, and guests access resources from anywhere, on any device, often from networks the enterprise does not control.
3. **Lateral movement.** Once an attacker compromises any asset inside a flat network, they enjoy broad access — the principal cause of the largest breaches of the last decade.

ZTA directly addresses these risks by:
- **Protecting each resource individually** rather than a large perimeter.
- **Applying least privilege and separation of duties** to every subject-resource pair.
- **Continuously re-evaluating** every active session for changes in subject, endpoint, resource, or context — so that a compromise does not grant indefinite access.
- **Using behavioral analytics and device health** as inputs to access decisions, not just credentials.

**ZTA does not eliminate risk.** It reduces blast radius, compresses dwell time, limits the insider threat, and removes the attacker's assumption of lateral freedom.

---

## 5. The Four Deployment Approaches — Detailed

NIST SP 1800-35 validates four deployment approaches. Each approach makes different architectural trade-offs and fits different organizational starting points. Most real-world enterprises combine two or more.

Here is a quick compare-and-contrast before we dive into each:

| Approach | Primary lens | Best starting point for | Typical PEP | Example NIST build |
|----------|--------------|-------------------------|-------------|---------------------|
| **EIG** | Identity | Orgs with good IDP/MFA already | IDP + app federation | E1B1, E2B1, E3B1 (Crawl); E1B2, E3B2, E4B3 (Run) |
| **SDP** | Network path (hide & tunnel) | Orgs wanting to retire VPN | ZTNA broker / SDP gateway | E1B3 (Zscaler), E1B4 (Appgate), E3B4 (F5) |
| **Microsegmentation** | Network topology | Orgs with many east-west attack paths | Host agent / segment firewall | E2B3 (Cisco), E3B3 (MS+Forescout), E4B4 (VMware NSX-T) |
| **SASE** | Edge-as-a-service | Orgs with many branch offices / remote workers | Cloud-delivered security stack | E1B5 (PAN), E2B4 (Symantec), E2B5 (Lookout), E3B5 (Microsoft), E2B6 (Google) |

### 5.1 Enhanced Identity Governance (EIG)

**Core idea.** Every access decision starts with identity. A strong, governed identity — combined with device posture and policy — is sufficient to make most access decisions, without relying on network location.

**What "Enhanced" means.** Traditional IAM grants a user a role and permission, then gets out of the way. EIG continuously re-evaluates identity: is the user still employed? Is MFA still valid? Is the device still compliant? Has the user done something suspicious? Have entitlements been recertified? If any answer changes, access is revoked.

**EIG Crawl vs. EIG Run.** NIST splits EIG into two maturity phases:
- **EIG Crawl** — on-premises resources only; the ICAM system doubles as the PDP; no device discovery enforcement.
- **EIG Run** — adds protection for cloud-hosted resources, device discovery with enforcement, and a PDP that may be separate from the ICAM stack. Secure tunnels to private resources become possible.

#### 5.1.1 EIG Architecture Diagram

```
                          ┌─────────────────────────────────────┐
                          │        ENTERPRISE IDP (ICAM)        │
                          │   Directory · Groups · Attributes   │
                          │        MFA · Passkeys · Risk        │
                          │   Conditional Access (PE+PA = PDP)  │
                          └───────────┬─────────────────────────┘
                                      │
              (1) Authenticate        │       (2) Token + context
              via SAML/OIDC           │       + conditional access
                                      ▼
┌───────────┐                ┌─────────────────────┐                  ┌──────────────┐
│  User     │                │  Application's      │                  │  Protected   │
│  +        │──── (0) ──────▶│  federation endpoint│────(3) session──▶│  resource    │
│ Endpoint  │  access request│  (SAML SP / OIDC RP)│                  │ (on-prem or  │
│ + posture │                │  — also acts as PEP │                  │  cloud SaaS) │
└──────┬────┘                └─────────┬───────────┘                  └──────────────┘
       │                               │
       │                               │ (S(D)) periodic reauthentication
       │◀──────(S(A))── continuous ────│        + device-posture check
       │       re-evaluation triggers: │        + risk rescore
       │       session token refresh,  │        → if fail, access revoked
       │       step-up MFA, risk score │
       │       change, compliance drift│
       ▼
 ┌──────────────────────────────────────────────────────────────┐
 │                PIPs feeding the IDP's PE                     │
 │  • UEM/MDM (Intune, Omnissa, Ivanti, Jamf) — device posture  │
 │  • EDR (Defender, CrowdStrike, SentinelOne) — endpoint health│
 │  • SIEM/UEBA (Sentinel, QRadar, Splunk) — behavioral signals │
 │  • IGA (SailPoint, Saviynt) — entitlements, recertification  │
 │  • HRIS (Workday) — employment status via SCIM               │
 └──────────────────────────────────────────────────────────────┘
```

#### 5.1.2 When to Choose EIG
- You already have a mature cloud IDP (Entra ID, Okta, Ping) and want to get more out of it.
- Your resources are a mix of SaaS and cloud-hosted web apps — most of which support SAML or OIDC.
- You want to start the Zero Trust journey with high ROI and low network disruption.
- **EIG is almost always the right starting point** — even if your eventual target is SDP or SASE. It is the foundation on which the other approaches build.

#### 5.1.3 Example NIST Builds and Products

| Build | PE/PDP | Key supporting tech |
|-------|--------|--------------------|
| E1B1 (Crawl) | Okta Identity Cloud + Ivanti Access ZSO | Ivanti UEM, Zimperium MTD, SailPoint IdentityIQ, Tenable, IBM QRadar, Radiant Logic |
| E2B1 (Crawl) | Ping Identity PingFederate | Cisco Duo MFA, Palo Alto NGFW, SailPoint, Radiant Logic, IBM QRadar |
| E3B1 (Crawl) | Microsoft Entra Conditional Access | Microsoft Intune, Defender for Endpoint, Sentinel, Forescout eyeSight, F5 BIG-IP |
| E1B2 (Run) | Zscaler ZPA Central Authority | Okta, AWS IaaS, Ivanti UEM, SailPoint, IBM QRadar |
| E3B2 (Run) | Microsoft Entra + Intune + Forescout eyeControl/eyeExtend | Defender for Cloud Apps, Purview, Sentinel, PAN NGFW |
| E4B3 (Run) | IBM Security Verify | IBM MaaS360, IBM Guardium, PAN GlobalProtect, VMware |

---

### 5.2 Software-Defined Perimeter (SDP) / Zero Trust Network Access (ZTNA)

**Core idea.** Resources are **invisible** to the outside world. Before any network-layer connection is even attempted, the user and device must authenticate to a broker / controller. Only then is a dynamic, encrypted, identity-bound tunnel established directly to the specific resource the user is authorized to reach. Other resources remain unreachable — and even undiscoverable — from that session.

**Sometimes called:** ZTNA (Zero Trust Network Access), BeyondCorp-style access, identity-aware proxy for private apps. ZTNA is the productized, cloud-delivered form of SDP most vendors now sell.

**The "dark" principle.** In a correctly deployed SDP, port scans return nothing. An attacker with stolen credentials but no posture-compliant endpoint cannot even reach the resource's IP. This is dramatically different from traditional VPN, which drops the authenticated user onto a broad network segment.

#### 5.2.1 SDP Architecture Diagram

```
                      ┌────────────────────────────────────────────────┐
                      │          SDP CONTROLLER / BROKER (PDP)         │
                      │  - Authenticates user via IDP (OIDC/SAML)      │
                      │  - Evaluates device posture + identity +       │
                      │    policy → decides which resources are visible│
                      │  - Orchestrates tunnel between client and GW   │
                      └────────────┬─────────────────────┬─────────────┘
                                   │                     │
                   (1) authenticate│                     │ (3) push policy
                       + posture   │                     │     + tunnel auth
                                   │                     │
 ┌──────────────────┐              ▼                     ▼        ┌──────────────────┐
 │  User + Endpoint │                                              │  SDP GATEWAY /   │
 │                  │          (2) controller returns              │  CONNECTOR (PEP) │
 │  SDP Client /    │         list of AUTHORIZED resources         │                  │
 │  Connector agent │◀─────────────────────────────────────        │  Sits next to    │
 │  (Zscaler Client │                                              │  the private app;│
 │  Connector /     │          (4) direct, encrypted,              │  only accepts    │
 │  Appgate client /│           identity-bound tunnel ────────────▶│  tunnels from    │
 │  Okta/Ivanti)    │              (mTLS, QUIC, or TLS)            │  authorized      │
 │                  │                                              │  clients via     │
 └──────────────────┘                                              │  controller      │
                                                                   └────────┬─────────┘
                                                                            │
                                                                            ▼
                                                                  ┌─────────────────┐
                                                                  │ Private resource│
                                                                  │  (app/VM/DB)    │
                                                                  │  - has no public│
                                                                  │    IP           │
                                                                  │  - only reachable│
                                                                  │    via gateway  │
                                                                  └─────────────────┘

 Other resources the user is NOT authorized for: dark, unreachable, unscannable.
```

#### 5.2.2 How SDP Differs from VPN

| | Traditional VPN | SDP / ZTNA |
|---|-----------------|------------|
| Who is authenticated? | The user (and maybe device) | User + device + posture + context, re-evaluated continuously |
| What can the user see after auth? | An entire network segment | Only the specific resources they are authorized for |
| Can an unauthorized resource be reached? | Yes — lateral movement is possible | No — unauthorized resources are invisible |
| Where does the gateway sit? | At the corporate perimeter | Next to each private app; often cloud-brokered |
| Is traffic inspected per-session? | Rarely | Continuously, per policy |

#### 5.2.3 When to Choose SDP
- You are still relying on enterprise VPN for remote access to internal apps and want to retire it.
- Your private applications do not support modern federation (OIDC/SAML), so you need a tunnel-based wrapper.
- You want to give contractors and third parties granular, time-bound access to specific apps without exposing the network.
- You need to protect legacy on-prem apps and cloud-hosted apps with the same access model.

#### 5.2.4 Example NIST Builds and Products

| Build | PE/PDP | Notes |
|-------|--------|-------|
| E1B3 | Zscaler ZPA Central Authority | Cloud-delivered ZTNA; connector next to app in AWS IaaS |
| E1B4 | Appgate SDP Controller | Classic SDP model; Appgate Gateway in front of resources |
| E3B4 | F5 BIG-IP + NGINX Plus | On-prem SDP; Forescout for posture; Microsoft AD as IDP |
| E4B4 | VMware Workspace ONE Access + UAG + NSX-T | Combined SDP + microsegmentation |
| E1B6 | Ivanti Neurons for Zero Trust Access | Ivanti nZTA Gateway + Okta |
| E3B5 | Microsoft Entra Private Access (part of SSE) | Microsoft-native ZTNA with Global Secure Access Client |
| E4B5 | AWS Verified Access + Amazon VPC Lattice | AWS-native ZTNA + service-to-service microsegmentation |

**Other market-leading ZTNA/SDP products:** Cloudflare Access, Netskope Private Access, Google BeyondCorp Enterprise, Palo Alto Prisma Access, Cisco Duo Network Gateway, Twingate, Tailscale (WireGuard-based).

---

### 5.3 Microsegmentation

**Core idea.** Flat networks are the attacker's best friend. Microsegmentation slices the network — whether physical, virtual, or workload-level — into **small, individually policed segments**. East-west traffic between workloads, VMs, containers, and applications must explicitly be permitted; by default it is denied. An attacker who compromises one workload cannot pivot to the next.

**Two main flavors:**
1. **Network-based microsegmentation** — Enforcement lives in the network fabric: VLANs, VXLANs, SDN policies, or distributed firewalls. Examples: VMware NSX-T, Cisco ACI, AWS Security Groups + VPC Lattice.
2. **Host-based microsegmentation** — Enforcement lives on every workload via an agent or eBPF hook. The agent enforces firewall rules locally and reports policy compliance to a central controller. Examples: Illumio, Akamai Guardicore, Cisco Secure Workload.

#### 5.3.1 Microsegmentation Architecture Diagram

```
                                ┌─────────────────────────────────────┐
                                │   MICROSEGMENTATION CONTROLLER (PDP)│
                                │  • Discovers workloads, labels them │
                                │  • Maintains policy graph (what     │
                                │    may talk to what, on which ports)│
                                │  • Pushes policy to every PEP       │
                                └─────────┬────────────┬──────────────┘
                                          │            │
                     policy push          │            │ policy push
                           ┌──────────────┘            └──────────────┐
                           ▼                                          ▼
   ┌────────────────────────────────┐         ┌────────────────────────────────┐
   │   SEGMENT / TRUST ZONE A       │         │    SEGMENT / TRUST ZONE B      │
   │   ┌───────────┐  ┌──────────┐  │         │  ┌───────────┐  ┌───────────┐  │
   │   │  App VM   │  │  DB VM   │  │         │  │  Web VM   │  │ Mgmt VM   │  │
   │   │  + agent  │  │  + agent │  │   ❌    │  │  + agent  │  │  + agent  │  │
   │   │ (PEP)     │  │  (PEP)   │  │◀──────▶│  │  (PEP)    │  │  (PEP)    │  │
   │   └─────┬─────┘  └────┬─────┘  │ blocked │  └───────────┘  └───────────┘  │
   │         │             │        │ by      │                                 │
   │         └─allowed: 443┘        │ default │   Zone B is not allowed to     │
   │         & 5432 only            │         │   talk to Zone A; policy       │
   │   (explicit east-west rule)    │         │   controller has no such rule  │
   └────────────────────────────────┘         └────────────────────────────────┘

 Attacker who compromises Web VM in Zone B cannot reach App or DB in Zone A.
 Every attempt is logged, scored, and can feed the PDP's risk engine.
```

#### 5.3.2 When to Choose Microsegmentation
- Your data center or cloud has a flat, broad internal network and you have observed (or fear) lateral movement.
- You need to achieve compliance boundaries (PCI, HIPAA, GDPR enclaves) without rearchitecting applications.
- You are moving to cloud-native / container workloads and need identity-aware east-west controls.
- You want to complement an SDP deployment — SDP protects north-south; microsegmentation protects east-west.

#### 5.3.3 Example NIST Builds and Products

| Build | PE/PDP | Microsegmentation engine |
|-------|--------|--------------------------|
| E2B3 | Cisco ISE + Ping Identity + Cisco Secure Workload | Cisco Secure Workload (formerly Tetration) agents |
| E3B3 | Microsoft Entra + Forescout eyeSegment | Forescout eyeSegment + MS Intune + Azure App Proxy |
| E4B4 | VMware Workspace ONE + UAG + NSX-T | VMware NSX-T distributed firewall |
| E1B5 | Palo Alto Networks NGFW + Prisma Access | PAN-OS distributed policy + Prisma Access |
| E4B5 | AWS Verified Access + Amazon VPC Lattice | VPC Lattice for service-to-service |
| E1B6 | Ivanti Neurons for ZTA | Ivanti nZTA segment gateways |

**Other market leaders:** Illumio Core, Akamai (Guardicore) Segmentation, Zscaler Workload Communications, ColorTokens, TrueFort.

---

### 5.4 Secure Access Service Edge (SASE)

**Core idea.** Stop hauling all remote and branch-office traffic back to a central data center for inspection (the old "hub and spoke" model). Instead, deliver a full stack of security services — **firewall, SWG, CASB, DLP, ZTNA, SD-WAN** — from a globally distributed cloud edge close to the user. Every user, wherever they are, connects to the nearest SASE point of presence (POP), gets inspected and policy-enforced there, and is then routed directly to the destination (SaaS, cloud, or private app via ZTNA).

**SASE = SSE + SD-WAN.** Gartner's original formulation splits SASE into:
- **Security Service Edge (SSE)** — the security portion: SWG, CASB, ZTNA, FWaaS, DLP.
- **SD-WAN** — the networking portion: intelligent routing across MPLS / internet / LTE / 5G.

Most vendors now sell them as an integrated platform, though some specialize in just SSE or just SD-WAN.

#### 5.4.1 SASE Architecture Diagram

```
                                      ┌────────────────────────────────────┐
                                      │          SASE CONTROL PLANE        │
                                      │  - Policy authored once, applied   │
                                      │    globally across all POPs (PDP)  │
                                      │  - IDP integration (OIDC/SAML)     │
                                      │  - Posture + risk + threat intel   │
                                      └───────────────┬────────────────────┘
                                                      │ policy sync
           ┌──────────────────────────┬───────────────┼──────────────┬────────────────────┐
           ▼                          ▼               ▼              ▼                    ▼
   ┌───────────────┐         ┌───────────────┐   ┌────────────┐  ┌─────────────┐   ┌───────────────┐
   │  SASE POP     │         │  SASE POP     │   │ SASE POP   │  │ SASE POP    │   │  SASE POP     │
   │  (Americas)   │         │  (EMEA)       │   │ (APAC)     │  │ (LATAM)     │   │  (more...)    │
   │               │         │               │   │            │  │             │   │               │
   │  SWG • CASB   │  ...    │  SWG • CASB   │   │ all PEPs   │  │ all PEPs    │   │  all PEPs     │
   │  ZTNA • FWaaS │         │  ZTNA • FWaaS │   │ co-located │  │ co-located  │   │  co-located   │
   │  DLP • RBI    │         │  DLP • RBI    │   │            │  │             │   │               │
   │  SD-WAN edge  │         │  SD-WAN edge  │   │            │  │             │   │               │
   └──────┬────────┘         └──────┬────────┘   └──────┬─────┘  └──────┬──────┘   └──────┬────────┘
          │                         │                   │               │                 │
          ▼                         ▼                   ▼               ▼                 ▼
   ┌──────────────┐         ┌──────────────┐     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
   │ Remote user  │         │ Branch office│     │ Mobile user  │  │ Contractor   │  │ IoT / kiosk  │
   │ (laptop+agent│         │ (SD-WAN CPE) │     │ (phone/tablet│  │ (browser-only│  │ (agentless   │
   │  + ZTNA)     │         │              │     │  + agent)    │  │  via RBI)    │  │  via proxy)  │
   └──────────────┘         └──────────────┘     └──────────────┘  └──────────────┘  └──────────────┘
          │                         │                   │               │                 │
          └─────────┬───────────────┴─────────┬─────────┴───────────────┴─────────────────┘
                    ▼                         ▼
            ┌────────────────┐        ┌────────────────┐
            │  Public SaaS   │        │ Private apps   │
            │  (M365, SFDC,  │        │ (via ZTNA      │
            │   Slack…)      │        │  to on-prem or │
            │   CASB-checked │        │  IaaS)         │
            └────────────────┘        └────────────────┘

 Traffic is inspected at the nearest POP, not hauled back to HQ. Policy is one global set.
```

#### 5.4.2 The Five SASE/SSE Security Services

| Service | What it does | Example products |
|---------|--------------|------------------|
| **SWG (Secure Web Gateway)** | Filters internet traffic, blocks malicious URLs, enforces acceptable use | Zscaler ZIA, Netskope, Symantec Cloud SWG, Cisco Umbrella, Palo Alto Prisma Access |
| **CASB (Cloud Access Security Broker)** | Visibility + control over SaaS usage, shadow IT discovery, SaaS DLP | Microsoft Defender for Cloud Apps, Netskope, Symantec CloudSOC, Zscaler, Palo Alto SaaS Security |
| **ZTNA** | Private app access (see §5.2) | See SDP section |
| **FWaaS** | Cloud-delivered next-gen firewall | Zscaler, Palo Alto Prisma, Cato, Fortinet FortiSASE |
| **DLP** | Prevents exfiltration of sensitive data | Microsoft Purview, Symantec, Forcepoint, Netskope, Zscaler |

#### 5.4.3 When to Choose SASE
- Your workforce is largely remote or distributed across many branch offices.
- You want to retire MPLS and deliver security from the cloud rather than backhauling to a central data center.
- You have extensive SaaS usage and need CASB-level visibility and control.
- You want unified policy across internet, SaaS, and private app access.
- **SASE is ideal as an extension of EIG** — once identity is in place, SASE gives you the global enforcement edge.

#### 5.4.4 Example NIST Builds and Products

| Build | PE/PDP | SASE/SSE stack |
|-------|--------|----------------|
| E1B5 | Palo Alto NGFW + Prisma Access | PAN Prisma SASE (Prisma Access + Prisma SD-WAN) + CDSS |
| E2B4 | Symantec Cloud SWG + ZTNA + CASB | Full Symantec (Broadcom) stack + Omnissa Workspace ONE |
| E2B5 | Lookout SSE + Okta | Lookout Secure Private / Cloud / Internet Access |
| E3B5 | Microsoft Entra Conditional Access + Microsoft SSE | Microsoft Global Secure Access, Entra Private/Internet Access, M365 Access |
| E2B6 | Google Chrome Enterprise Premium — Access Context Manager | Google CEP + Application Connector + Workspace |

**Other market leaders:** Cato Networks (pioneer of converged SASE), Cisco+ Secure Connect, Fortinet FortiSASE, Versa Networks, Cloudflare One, HPE Aruba EdgeConnect + Axis Security, iboss.

---

### 5.5 How the Four Approaches Combine

Most production Zero Trust architectures combine approaches. Here is how they layer together:

```
                ┌──────────────────────────────────────────────────────────────┐
                │                   IDENTITY FOUNDATION                         │
                │                  (EIG — always first)                         │
                │   IDP + MFA + device posture + conditional access + SCIM      │
                └────────────────────────────┬─────────────────────────────────┘
                                             │ every decision starts here
         ┌───────────────────────────────────┼───────────────────────────────────┐
         │                                   │                                   │
         ▼                                   ▼                                   ▼
 ┌───────────────┐                  ┌──────────────────┐                 ┌──────────────────┐
 │ NORTH-SOUTH:  │                  │ EAST-WEST:       │                 │ EDGE:            │
 │ SDP / ZTNA    │                  │ MICROSEGMENTATION│                 │ SASE / SSE       │
 │               │                  │                  │                 │                  │
 │ Replaces VPN; │                  │ Contains lateral │                 │ Delivers         │
 │ hides private │                  │ movement; limits │                 │ SWG+CASB+ZTNA+   │
 │ apps          │                  │ blast radius     │                 │ DLP from cloud   │
 └───────────────┘                  └──────────────────┘                 └──────────────────┘
         │                                   │                                   │
         └───────────────────────────────────┼───────────────────────────────────┘
                                             ▼
                           ┌─────────────────────────────────┐
                           │  DATA-LEVEL SECURITY (cross-cut)│
                           │  Classification · DLP · IRM ·   │
                           │  Encryption · Rights mgmt       │
                           └─────────────────────────────────┘
```

**A typical mature enterprise target state** is: EIG + SDP + Microsegmentation + SASE, layered in that rough order of priority, with data-level security as a cross-cutting concern and externalized authorization (Cedar / OPA / Zanzibar-style) as the next horizon.

---

## 6. The Practical Seven-Step Journey (NIST-Aligned)

NIST SP 1800-35 Section 8 defines seven steps every organization should follow. Treat these as the outline of your program charter.

### Step 1 — Discover and Inventory the Existing Environment
You cannot protect what you cannot see. Build authoritative inventories of:
- All hardware, software, applications, data, and services
- All subjects (human users, service accounts, workloads, devices)
- All communication flows and access patterns
- All cloud resources (IaaS, PaaS, SaaS)
- All external identities (contractors, partners, federated users, guests)

**Run discovery continuously, not once.**

### Step 2 — Formulate Access Policy to Support the Mission
Define who should access what, under what conditions. Ground policy in **least privilege** and **separation of duties**, and factor in:
- User role, employment status, and location
- Device type, health, and compliance posture
- Resource criticality and data classification
- Contextual signals: time of day, geography, network, risk score
- Business process logic

Use observed access patterns from Step 1 as a baseline — then remove what shouldn't be permitted.

### Step 3 — Identify Existing Security Capabilities and Technology
Inventory what you already have: IAM, MFA, EDR/EPP, UEM/MDM, firewalls, IDS/IPS, SIEM, SOAR, DLP, CASB, PKI. Map each to the ZTA logical architecture. Decide what to keep, repurpose, or replace. **Reuse pays.**

### Step 4 — Eliminate Gaps Using a Risk-Based Approach
Design your access-protection topology. Ask:
- Which resources must be protected individually?
- Which can share a trust zone?
- Where do PEPs need to sit?
- What PIPs feed the PDP with context?

Apply enforcement at **application, host, and network** layers.

### Step 5 — Implement Incrementally
Do not attempt a big-bang migration. The NIST-recommended foundation is:
- **Strong ICAM with risk-based MFA** (passkeys or FIDO2 preferred)
- **An endpoint posture / compliance solution integrated with ICAM**

With those two foundations you already have a functional EIG Crawl-level ZTA. From there, add capabilities in priority order:
1. Cloud-resource protection (SCIM provisioning, app federation)
2. Secure tunnels to internal apps (ZTNA / SDP)
3. Microsegmentation for lateral-movement containment
4. Data-level security (classification, DLP, IRM)
5. Behavioral analytics and continuous evaluation
6. Externalized authorization (ReBAC / PBAC policy engine)

### Step 6 — Verify the Implementation Continuously
Monitor every access event in real time. Periodically test your ZTA against the use cases in §9. NCCoE used Mandiant Security Validation (MSV) throughout its labs — emulate this practice in production.

### Step 7 — Continuously Improve and Evolve
The threat landscape, your mission, your technology, and regulations all change. Zero Trust is a permanent operating model, not a project with an end date.

---

## 7. The Multi-Protocol Reality — Not Every App Speaks Modern Identity

Most enterprises operate a heterogeneous application portfolio. A mature Zero Trust identity fabric must accommodate a **spectrum** of authentication capabilities:

| Tier | Capability | Example Apps | Strategy |
|------|-----------|--------------|----------|
| 1 | Native OIDC / OAuth 2.0 / PKCE | Modern SaaS, mobile, SPAs | Direct OIDC federation |
| 2 | Native SAML 2.0 | Salesforce, Workday, ServiceNow | Direct SAML federation |
| 3 | Header-based / reverse-proxy | Older web apps, internal portals | Identity-Aware Proxy injects signed headers |
| 4 | Kerberos / IWA | On-prem Windows apps, SharePoint | IDP Kerberos support + constrained delegation |
| 5 | LDAP bind | Legacy Java/Unix, Jenkins | LDAP gateway fronted by the IDP |
| 6 | Form-based / no federation | Ancient web apps | Secure Web Authentication (SWA) with audit |
| 7 | API keys / basic auth / mTLS | Machine-to-machine | Workload identity: SPIFFE/SPIRE, dynamic secrets |

### Decision Flow for Onboarding Any Application

```
┌──────────────────────────┐
│ New app to onboard       │
└───────────┬──────────────┘
            ▼
   Does it support OIDC?  ──Yes──▶ Federate via OIDC (preferred)
            │ No
            ▼
   Does it support SAML?  ──Yes──▶ Federate via SAML
            │ No
            ▼
   Reverse-proxy-able?    ──Yes──▶ Identity-Aware Proxy with header injection
            │ No
            ▼
   Kerberos/LDAP only?    ──Yes──▶ LDAP gateway or Kerberos bridge
            │ No
            ▼
   Form-based web login?  ──Yes──▶ Secure Web Authentication (vaulting)
            │ No
            ▼
   Machine-to-machine?    ──Yes──▶ Workload identity (SPIFFE/mTLS)
            │ No
            ▼
        Escalate / redesign
```

---

## 8. The Authorization Journey — From RBAC to Externalized Policy

Just as authentication has externalized from applications to the IDP via SAML/OIDC, authorization is now undergoing the same shift.

| Model | Description | Strength | Weakness |
|-------|-------------|----------|----------|
| **ACL** | Resource-by-resource lists | Simple | Doesn't scale |
| **RBAC** | Roles grant permissions | Easy to audit | Role explosion |
| **ABAC** | Policies over attributes + context | Context-aware | Hard to debug |
| **ReBAC** | Permissions via relationships (Zanzibar model) | Ideal for sharing/hierarchy | Requires modeling discipline |
| **PBAC** | Central policy engine; runtime PDP | Centrally auditable | PDP latency/availability |

### The Pragmatic Target
Most enterprises converge on a hybrid:
- **RBAC for coarse app entitlement** (IDP-managed, enforced at federation time).
- **ReBAC or ABAC for fine-grained in-app decisions** (delegated to a central PDP: Cedar, OpenFGA, SpiceDB, OPA).

**Centralize the common case; delegate the long tail to specialized layers.**

---

## 9. Validation — Exercise Your ZTA Against These Use Cases

NIST SP 1800-35 defines eight functional use cases. Build a continuous validation suite covering:

| Use Case | Purpose |
|----------|---------|
| **A. Discovery and Identification** | Discover assets, authenticate them, observe flows |
| **B. Enterprise-ID Access** | Employees under various device/location/policy conditions, stolen credentials, BYOD, just-in-time, step-up |
| **C. Federated-ID Access** | Partners / trusted-community users |
| **D. Other-ID Access** | External identities registered-but-not-issued by the enterprise |
| **E. Guest / No-ID Access** | Unauthenticated users restricted to public internet |
| **F. Confidence Level** | Re-evaluation on auth failure, compliance drift, suspicious behavior |
| **G. Service-to-Service** | API calls: on-prem↔cloud, cloud↔cloud, container↔container |
| **H. Data-Level Security** | Differentiation by data classification; step-up MFA, download restrictions, at-endpoint encryption |

Exercising all of them against your live environment is the only way to know your ZTA delivers the protection it promised.

---

## 10. Governance and Lifecycle — The Often-Missed Foundation

Protocols are necessary but not sufficient. A mature Zero Trust architecture also requires:

- **Joiner / Mover / Leaver (JML) automation** from HRIS (Workday, SuccessFactors) with SCIM 2.0 propagation.
- **Access reviews and recertification** (NIST SP 800-53 AC-2, SOX, ISO 27001).
- **Segregation of Duties (SoD)** — cross-app policy preventing toxic combinations.
- **Privileged Access Management (PAM)** — just-in-time, session-recorded elevation.
- **Non-human identity governance** — service accounts, bots, workloads.
- **Unified audit** — every AuthN, AuthZ, and admin event in SIEM with consistent schema.

---

## 11. Reference Architecture — The Layered Identity Fabric

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 5 — POLICY & GOVERNANCE                                   │
│ Access reviews · SoD · JML · Unified audit · Recertification    │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 4 — AUTHORIZATION                                         │
│ PDP (Cedar / Zanzibar-style / OPA) · Entitlements · ReBAC       │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 3 — PROTOCOL TRANSLATION                                  │
│ SAML IdP · OIDC OP · Kerberos · LDAP gateway · SWA vault        │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 2 — PRIMARY AUTHENTICATION                                │
│ Passkeys · MFA · Risk engine · Session · Device trust           │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 1 — IDENTITY SOURCE OF TRUTH                              │
│ Directory · HRIS integration · Groups · Attributes              │
└─────────────────────────────────────────────────────────────────┘

Supporting PIPs feeding the PDP:
ICAM · EDR/EPP · UEM/MDM · SIEM/SOAR/UEBA · DLP/IRM · Threat Intel
```

Map each of your existing and planned tools to a layer. Gaps in any layer are programmatic risks.

---

## 12. Vendor-Agnostic Lessons from the Nineteen NIST Builds

### Lesson 1 — Out-of-the-box integration is not a given
Many ICAM, endpoint, and network components from different vendors **do not integrate with each other out of the box**. Map the integration matrix and prove it in a lab before commitment.

### Lesson 2 — EPP / endpoint posture must feed the PDP
Build E1B2 (Zscaler as PE) lacked an EPP integrated with Zscaler. The result: Zscaler could enforce its own compliance checks but could not compute confidence/trust scores. **End-to-end integration across EPP, MDM, EDR, and the PDP is required for rich decisions.**

### Lesson 3 — Multiple PDPs need to share context
Real ZTAs have multiple PDPs. Most do not share signals. **Plan explicitly for PDP-to-PDP context sharing**, or centralize where possible. Build E3B2 had only a one-way integration (Intune → Forescout) — a common real-world gap.

### Lesson 4 — SIEM / SOAR / Data Security / UEBA should feed the PDP in near-real-time
Treat PDP integration as a hard requirement when selecting these tools.

### Lesson 5 — Policy fragmentation is real
Because a ZTA typically has multiple PDPs, policy rules are distributed across endpoint, ICAM, network, and data-security components. **Maintain a single map of where every rule lives.** Policy-as-code in Git is the emerging answer.

### Lesson 6 — Resource-side authentication is frequently missing
Most EIG Crawl builds verified only the requester, not the endpoint hosting the resource. **Treat resource authentication as first-class.**

### Lesson 7 — Network admission control is often absent
NIST's EIG Crawl builds manually joined endpoints with no initial authentication gate. **Deploy NAC or equivalent posture-based admission control.**

### Lesson 8 — Automated remediation closes the loop
When an endpoint falls out of compliance, ZTA should deny access **and** trigger automated remediation via UEM/MDM and patch management.

---

## 13. A Three-Horizon Migration Roadmap

### Horizon 1 (0–12 months): Consolidate Authentication (EIG Crawl + start of Run)
- Complete application inventory and classify into the seven-tier matrix.
- Migrate all Tier 1–2 apps to federated SSO (OIDC/SAML).
- Enforce MFA universally; prefer passkeys and FIDO2.
- Stand up SCIM provisioning for the top 20 apps.
- Deploy / validate EDR/EPP and UEM/MDM integration with the IDP.
- Complete discovery (Step 1) and baseline policies (Step 2).

### Horizon 2 (12–24 months): Extend the Fabric (EIG Run + SDP + Microsegmentation + SASE)
- Deploy Identity-Aware Proxy for Tier 3 legacy web apps.
- Stand up LDAP gateway / Kerberos bridge for Tier 4–5.
- Introduce SWA for Tier 6 long-tail apps.
- Begin workload identity rollout for Tier 7 (SPIFFE/SPIRE, IAM Roles Anywhere).
- Replace standing admin privilege with PAM + JIT.
- Deploy ZTNA/SDP to retire VPN.
- Introduce microsegmentation for lateral-movement containment.
- Deploy SASE / SSE for branch offices and remote workers.
- Integrate SIEM / SOAR / UEBA signals into PDP decision inputs.

### Horizon 3 (24+ months): Externalize Authorization + Continuous Evaluation
- Select a PDP (Cedar, OpenFGA, SpiceDB, OPA) and adopt policy-as-code.
- Pilot externalized authorization on one or two greenfield apps.
- Define a migration playbook for existing apps.
- Adopt Continuous Access Evaluation (CAEP / Shared Signals Framework).
- Extend data-level security (classification, DLP, IRM, endpoint encryption).
- Institutionalize continuous validation (MSV-equivalent in production).

---

## 14. Common Pitfalls — And How to Avoid Them

| Pitfall | Mitigation |
|---------|-----------|
| Treating SCIM as optional | Without deprovisioning, federation just creates orphans faster. Gate every onboarding on SCIM. |
| Rich permissions in the ID token | Keep tokens lean. Put rich policy in the PDP. |
| One giant "employee" role | Model entitlements around job functions, not headcount. |
| Password vaulting without audit | SWA credentials must be audited and rotated. |
| Forgetting service accounts | Workload identity is not optional. |
| No break-glass plan | Document, test, rotate. |
| Conflating identity with entitlement | AuthN ≠ AuthZ. |
| Assuming perimeter still works for cloud | Cloud resources live outside it. Protect individually. |
| Big-bang deployment | Incremental rollout is explicitly NIST-recommended. |
| Ignoring user experience | A ZTA users hate will be circumvented. |

---

## 15. Quick Reference — Standards and Frameworks to Align With

- **NIST SP 800-207** — Zero Trust Architecture (foundational)
- **NIST SP 1800-35** — Implementing a Zero Trust Architecture (practice guide)
- **NIST Cybersecurity Framework 2.0**
- **NIST SP 800-53 Rev. 5** — Security and Privacy Controls
- **NIST SP 800-63-4** — Digital Identity Guidelines
- **NIST Critical Software Security Measures**
- **SAML 2.0 · OIDC Core 1.0 · OAuth 2.1 · FAPI 2.0**
- **SCIM 2.0** (provisioning)
- **WebAuthn L3 / FIDO2** (phishing-resistant MFA)
- **SPIFFE / SPIRE** (workload identity)
- **XACML 3.0 / OPA / Cedar / Zanzibar / OpenFGA** (policy engines)
- **CAEP / Shared Signals Framework** (continuous access evaluation)

---

## 16. Closing — The One Thing to Remember

Zero Trust is not about buying a single product or flipping to a new network topology. It is about **moving security decisions out of individual applications and into a centralized, context-aware, continuously-evaluated policy layer** — while retrofitting the long tail of legacy applications through translation gateways.

The NIST SP 1800-35 nineteen builds are proof this is achievable today using commercially available technology. The enterprise work is not the technology — it is the sequencing, the governance, the integration across existing investments, and the patience to execute incrementally over years.

> **Get the layers right, and every future protocol — continuous access evaluation, workload identity, post-quantum crypto — is just another plug-in.**
> **Get them wrong, and you will rebuild your identity stack every five years.**

---

## Appendix A — Policy Engines Used in the NIST SP 1800-35 Builds

| Phase | Build | Policy Engine(s) / PDP |
|-------|-------|------------------------|
| EIG Crawl | E1B1 | Okta Identity Cloud, Ivanti Access ZSO |
| EIG Crawl | E2B1 | Ping Identity PingFederate |
| EIG Crawl | E3B1 | Microsoft Azure AD Conditional Access (now Entra Conditional Access) |
| EIG Run | E1B2 | Zscaler ZPA Central Authority |
| EIG Run | E3B2 | Microsoft Entra Conditional Access, Intune, Forescout eyeControl/eyeExtend |
| EIG Run | E4B3 | IBM Security Verify |
| SDP | E1B3 | Zscaler ZPA Central Authority |
| Microsegmentation | E2B3 | Ping PingFederate, Cisco ISE, Cisco Secure Workload |
| SDP + Microseg | E3B3 | Microsoft Entra Conditional Access, Intune, Sentinel, Forescout |
| SDP | E1B4 | Appgate SDP Controller |
| SDP + SASE | E2B4 | Symantec Cloud SWG, Symantec ZTNA, Symantec CASB |
| SDP | E3B4 | F5 BIG-IP, F5 NGINX Plus, Forescout eyeControl/eyeExtend |
| SDP + Microseg + EIG | E4B4 | VMware Workspace ONE Access, VMware UAG, VMware NSX-T |
| SASE + Microseg | E1B5 | Palo Alto NGFW, Palo Alto Prisma Access |
| SDP + SASE | E2B5 | Lookout SSE, Okta Identity Cloud |
| SDP + SASE | E3B5 | Microsoft Entra Conditional Access, Microsoft Security Service Edge |
| SDP + Microseg | E4B5 | AWS Verified Access, Amazon VPC Lattice |
| SDP + Microseg | E1B6 | Ivanti Neurons for Zero Trust Access |
| SASE | E2B6 | Google Chrome Enterprise Premium — Access Context Manager |

**NIST does not endorse any vendor.** These are example builds; your selection should be driven by existing stack compatibility and operating model.

---

## Appendix B — Glossary of Key Acronyms

| Acronym | Meaning |
|---------|---------|
| ABAC | Attribute-Based Access Control |
| CAEP | Continuous Access Evaluation Profile |
| CASB | Cloud Access Security Broker |
| CSF | Cybersecurity Framework (NIST) |
| EDR | Endpoint Detection and Response |
| EIG | Enhanced Identity Governance |
| EPP | Endpoint Protection Platform |
| IAP | Identity-Aware Proxy |
| ICAM | Identity, Credential, and Access Management |
| IDP | Identity Provider |
| IGA | Identity Governance and Administration |
| JML | Joiner / Mover / Leaver |
| MDM | Mobile Device Management |
| MFA | Multi-Factor Authentication |
| NAC | Network Access Control |
| NGFW | Next-Generation Firewall |
| OIDC | OpenID Connect |
| OPA | Open Policy Agent |
| PA | Policy Administrator |
| PAM | Privileged Access Management |
| PBAC | Policy-Based Access Control |
| PDP | Policy Decision Point |
| PE | Policy Engine |
| PEP | Policy Enforcement Point |
| PIP | Policy Information Point |
| RBAC | Role-Based Access Control |
| RBI | Remote Browser Isolation |
| ReBAC | Relationship-Based Access Control |
| SASE | Secure Access Service Edge |
| SAML | Security Assertion Markup Language |
| SCIM | System for Cross-domain Identity Management |
| SDP | Software-Defined Perimeter |
| SD-WAN | Software-Defined Wide Area Network |
| SIEM | Security Information and Event Management |
| SOAR | Security Orchestration, Automation, and Response |
| SPIFFE | Secure Production Identity Framework for Everyone |
| SSE | Security Service Edge |
| SSO | Single Sign-On |
| SWA | Secure Web Authentication (password vaulting) |
| SWG | Secure Web Gateway |
| UEBA | User and Entity Behavior Analytics |
| UEM | Unified Endpoint Management |
| ZTA | Zero Trust Architecture |
| ZTNA | Zero Trust Network Access |

---

*End of document. Version 2.0 — expanded with component deep dives, example products, and deployment-approach diagrams.*
