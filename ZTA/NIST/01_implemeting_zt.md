# Implementing Zero Trust in the Enterprise
## A Practical Guidance Document Synthesizing NIST SP 1800-35, NIST SP 800-207, and Modern Enterprise Identity Patterns

*Version 1.0 · Prepared from:*
- *NIST SP 1800-35, "Implementing a Zero Trust Architecture" (NCCoE, June 2025 — Final)*
- *NIST SP 1800-35 Full Document (web edition) at pages.nist.gov/zero-trust-architecture*
- *NIST SP 800-207, "Zero Trust Architecture" (foundational reference)*
- *Enterprise Identity Architecture: A Practitioner's Guide to Multi-Protocol Authentication and Authorization*
- https://pages.nist.gov/zero-trust-architecture/VolumeB/architecture.html#zta-in-operation
- https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.1800-35.pdf

---

## 1. Executive Summary

Zero Trust is not a product, a license, or a one-time project. It is an **enterprise cybersecurity strategy** grounded in a simple premise: **no user, device, application, or network location is implicitly trusted**. Every access request is verified, authorized, and continuously re-evaluated against policy — regardless of whether the request originates inside or outside the traditional network perimeter.

NIST SP 1800-35 operationalizes the concepts of NIST SP 800-207 through nineteen lab-validated example implementations ("builds") assembled by NCCoE with twenty-four technology collaborators. The key finding across all nineteen builds is consistent:

> **A zero trust architecture is achievable today using commercially available technology — but it is a journey, not a deployment. Most enterprises will evolve a ZTA incrementally from what they already own, beginning with identity, extending to endpoints and networks, and culminating in externalized policy-based access decisions and data-level controls.**

This guide translates the NIST findings into a step-by-step roadmap that an enterprise architect, CISO, or program manager can use to plan, justify, sequence, and execute a Zero Trust program.

---

## 2. Foundational Concepts You Must Align On Before Building

### 2.1 The Three Core ZTA Components (from NIST SP 800-207)

Every Zero Trust Architecture, regardless of vendor, reduces to three logical components working together:

| Component | Role | Plain-English Analogy |
|-----------|------|-----------------------|
| **Policy Engine (PE)** | Makes the access decision (permit / deny / limit) based on policy and context | The judge |
| **Policy Administrator (PA)** | Establishes or terminates the session once the PE renders a decision | The bailiff who executes the ruling |
| **Policy Enforcement Point (PEP)** | Sits in the data path, blocks or allows the traffic, and continuously monitors the session | The guard at the door |

The PE and PA together are often referred to as the **Policy Decision Point (PDP)**. These components are fed by **Policy Information Points (PIPs)** — supporting systems such as identity/credential/access management (ICAM), endpoint security (EDR/EPP, UEM/MDM), security analytics (SIEM, SOAR, UEBA), data security (DLP, IRM), and threat intelligence.

### 2.2 Authentication vs. Authorization — Keep Them Separate

The single most common design error in enterprise identity is conflating AuthN and AuthZ:

| | Authentication (AuthN) | Authorization (AuthZ) |
|---|---|---|
| **Question** | Who are you? | What are you allowed to do? |
| **When** | At login or token issuance | At every resource access |
| **Typical output** | Token / session / assertion | Permit / Deny decision |
| **Changes** | Rare (per session) | Frequent (per request) |
| **Standards** | SAML, OIDC, WebAuthn, Kerberos, LDAP bind | XACML, OPA/Rego, Cedar, Zanzibar (ReBAC) |
| **Failure mode** | Login fails | 403 Forbidden |

**Architect's rule of thumb:** *If a change requires the user to log in again, it's AuthN. If a change takes effect on the next request, it's AuthZ.*

Zero Trust requires both, continuously — not just at the front door.

### 2.3 The Four NIST Deployment Approaches

NIST SP 1800-35 organizes its nineteen builds around four deployment approaches that can be combined:

1. **Enhanced Identity Governance (EIG)** — identity-centric access control; the foundational layer on which most enterprises start. NCCoE divided EIG into two maturity phases:
   - **EIG Crawl** — on-premises resources only; ICAM components double as the PDP.
   - **EIG Run** — adds cloud-hosted resources, device discovery, and separate PDPs distinct from the ICAM stack.
2. **Software-Defined Perimeter (SDP)** — dynamically reconfigures network paths based on access decisions; resources are hidden until the PDP authorizes access, then a secure tunnel is established.
3. **Microsegmentation** — resources are placed in isolated network segments protected by gateway security components, or host-based agents/firewalls enforce segmentation at the endpoint.
4. **Secure Access Service Edge (SASE)** — cloud-delivered convergence of SD-WAN, Secure Web Gateway (SWG), Cloud Access Security Broker (CASB), Next-Generation Firewall (NGFW), and Zero Trust Network Access (ZTNA); used especially for branch offices and remote workers.

Most mature builds in SP 1800-35 combine two or more approaches (e.g., SDP + Microsegmentation, or SDP + SASE).

---

## 3. The Core Risk Model — Why Zero Trust Matters

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

## 4. The Practical Seven-Step Journey (NIST-Aligned)

NIST SP 1800-35 Section 8 defines seven steps that every organization should follow. Treat these as the outline of your program charter.

### Step 1 — Discover and Inventory the Existing Environment
You cannot protect what you cannot see. Before you design anything, deploy or use existing discovery and asset management tools to build authoritative inventories of:
- All hardware, software, applications, data, and services
- All subjects (human users, service accounts, workloads, devices)
- All communication flows and access patterns
- All cloud resources (IaaS, PaaS, SaaS) — most organizations underestimate this
- All external identities (contractors, partners, federated users, guests)

**Practical tip:** Run discovery continuously, not once. The inventory informs not only the initial design but ongoing policy validation and drift detection.

### Step 2 — Formulate Access Policy to Support the Mission
Once you know what you have, define who should access what, under what conditions. Policy should be driven by **least privilege** and **separation of duties**, and should take into account:
- User role, employment status, and location
- Device type (managed vs. BYOD), device health, and compliance posture
- Resource criticality and data classification
- Contextual signals: time of day, geography, network, risk score
- Business process logic (is this access warranted for what the user is doing?)

**Practical tip:** Use observed access patterns from Step 1 as a baseline — then remove what shouldn't be permitted. This avoids over-restrictive policy that breaks operations on day one.

### Step 3 — Identify Existing Security Capabilities and Technology
Most enterprises are not greenfield. Inventory what you already have:
- IAM, directory services, MFA solutions
- EDR/EPP, UEM/MDM
- Network firewalls, IDS/IPS, NAC
- SIEM, SOAR, vulnerability management, log management
- DLP, CASB, data classification tools
- PKI/certificate authorities

Map each capability to the ZTA logical architecture. Decide what to keep, repurpose, or replace. **Reuse pays — the NIST builds consistently show that ZTA is built on top of existing security infrastructure, not alongside it.**

### Step 4 — Eliminate Gaps Using a Risk-Based Approach
Design your access-protection topology. Ask:
- Which resources must be protected individually (highest criticality)?
- Which can share a trust zone?
- Where do PEPs need to sit? (Network edge, application gateway, host agent, API gateway?)
- What supporting technologies feed the PDP with context? (Device posture, user risk, threat intel, data classification?)

Apply enforcement at multiple layers: **application, host, and network**.

### Step 5 — Implement Incrementally, Leveraging What You Already Deployed
Do not attempt a big-bang migration. The NIST-recommended starting foundation is:
- **Strong ICAM with risk-based MFA** (passkeys or FIDO2 preferred)
- **An endpoint posture / compliance solution integrated with ICAM**

With those two foundations, you already have a functional EIG Crawl-level ZTA. From there, add capabilities in priority order:
1. Cloud-resource protection (SCIM provisioning, app federation)
2. Secure tunnels to internal apps (ZTNA / SDP)
3. Microsegmentation for lateral-movement containment
4. Data-level security (classification, DLP, IRM)
5. Behavioral analytics and continuous evaluation
6. Externalized authorization (ReBAC / PBAC policy engine)

### Step 6 — Verify the Implementation Continuously
Monitor every access event in real time. Periodically test your ZTA against the realistic use-case scenarios enumerated in Section 6 of SP 1800-35 (see §7 of this document). NCCoE used Mandiant Security Validation (MSV) throughout its labs to emulate attackers and verify that controls behaved as intended — emulate this practice in production.

### Step 7 — Continuously Improve and Evolve
The threat landscape, your mission, your technology, and regulations all change. Zero Trust is a permanent operating model, not a project with an end date. Build a cadence of:
- Policy recertification
- Control-effectiveness testing
- Technology refresh aligned with vendor roadmaps
- Threat-informed signature and behavioral-rule updates

---

## 5. The Multi-Protocol Reality — Not Every App Speaks Modern Identity

NIST SP 800-207 and SP 1800-35 describe the target state. But in practice, most enterprises operate a heterogeneous application portfolio, and a mature Zero Trust identity fabric must accommodate a **spectrum** of authentication capabilities:

| Tier | Capability | Example Apps | Enterprise Strategy |
|------|-----------|--------------|---------------------|
| 1 | Native OIDC / OAuth 2.0 / PKCE | Modern SaaS, mobile apps, SPAs | Direct OIDC federation |
| 2 | Native SAML 2.0 | Salesforce, Workday, ServiceNow | Direct SAML federation |
| 3 | Header-based / reverse-proxy auth | Older web apps, internal portals | Identity-Aware Proxy (e.g., Azure App Proxy, Cloudflare Access, Google IAP) injects signed headers |
| 4 | Kerberos / IWA | On-prem Windows apps, SharePoint, file shares | IDP Kerberos support + constrained delegation |
| 5 | LDAP bind | Legacy Java/Unix apps, Jenkins, older appliances | LDAP gateway fronted by the IDP |
| 6 | Form-based / no federation | Ancient web apps with local login | Secure Web Authentication (SWA) / password vaulting with audit |
| 7 | API keys / basic auth / mTLS | Machine-to-machine, legacy APIs | Workload identity: SPIFFE/SPIRE, dynamic secrets, short-lived certs |

**A mature Zero Trust identity architecture must cover all seven tiers through a single pane of glass** — one IDP, one MFA policy, one audit trail, one offboarding action. The NIST builds demonstrate Tiers 1–5 extensively; machine/workload identity (Tier 7) is the next frontier.

### Decision Flow for Onboarding Any Application

```
┌──────────────────────────┐
│ New app to onboard       │
└───────────┬──────────────┘
            │
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

## 6. The Authorization Journey — From RBAC to Externalized Policy

Just as authentication has externalized from applications to the IDP via SAML/OIDC, authorization is now undergoing the same shift. NIST SP 1800-35 touches on this in its PDP/PE design; the enterprise pattern is accelerating.

| Model | Description | Strength | Weakness |
|-------|-------------|----------|----------|
| **ACL** | Resource-by-resource lists | Simple | Doesn't scale |
| **RBAC** | Roles grant permissions; users get roles | Easy to audit | Role explosion |
| **ABAC** | Policies over user / resource / context attributes | Context-aware | Hard to debug |
| **ReBAC** | Permissions via relationships (Google Zanzibar model) | Ideal for sharing / hierarchy | Requires modeling discipline |
| **PBAC** | Central policy engine; apps ask PDP at runtime | Centrally auditable | PDP latency and availability |

### The Pragmatic Target

Most enterprises converge on a hybrid:
- **RBAC for coarse app entitlement** — "members of `finance-analysts` group may access the Finance app." Managed in the IDP, enforced at federation time.
- **ReBAC or ABAC for fine-grained in-app decisions** — "User can edit this document if they own it, the folder is shared with their team, and they're on a managed device." Delegated to a central PDP (Cedar, OpenFGA, SpiceDB, OPA, etc.).

This mirrors the AuthN pattern: **centralize the common case; delegate the long tail to specialized layers.**

---

## 7. Validation — Exercise Your ZTA Against These Use Cases

NIST SP 1800-35 defines eight functional use cases your ZTA implementation should be tested against. Build a continuous validation suite covering:

| Use Case | Purpose |
|----------|---------|
| **A. Discovery and Identification** | Verify you can discover assets, authenticate them, and observe transaction flows |
| **B. Enterprise-ID Access** | Employees accessing resources under various device/location/policy conditions, including stolen credentials, BYOD, just-in-time access, and step-up authentication |
| **C. Federated-ID Access** | Partners / trusted-community users accessing resources |
| **D. Other-ID Access** | External identities registered in but not issued by the enterprise |
| **E. Guest / No-ID Access** | Unauthenticated users restricted to public internet only |
| **F. Confidence Level** | Re-evaluation of active sessions on user, endpoint, or resource authentication failure; compliance drift; suspicious behavior; policy violation |
| **G. Service-to-Service Interactions** | Non-person API calls including on-prem-to-cloud, cloud-to-cloud, container-to-container, service-to-endpoint |
| **H. Data-Level Security** | Access differentiation by data classification, including step-up MFA, download restrictions, encryption of data-at-rest on endpoints |

Each use case has multiple scenarios. Exercising all of them against your live environment is the only way to know your ZTA delivers the protection it promised.

---

## 8. Governance and Lifecycle — The Often-Missed Foundation

Protocols are necessary but not sufficient. A mature Zero Trust identity architecture also requires:

- **Joiner / Mover / Leaver (JML) automation** driven by the HRIS (Workday, SAP SuccessFactors) as the authoritative trigger, with SCIM 2.0 propagation to downstream apps.
- **Access reviews and recertification** (NIST SP 800-53 AC-2, SOX, ISO 27001) — periodic attestation that each user's access is still warranted.
- **Segregation of Duties (SoD)** — cross-app policy preventing toxic combinations.
- **Privileged Access Management (PAM)** — just-in-time, session-recorded elevation for admin access; distinct from standing privileged accounts.
- **Non-human identity governance** — service accounts, bots, and workloads now outnumber humans in most enterprises. They need the same rigor.
- **Unified audit** — every AuthN event, AuthZ decision, and admin action funneled to a SIEM with consistent schema for UEBA and incident response.

---

## 9. Reference Architecture — The Layered Identity Fabric

An enterprise-grade Zero Trust architecture looks like this in layers:

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 5 — POLICY & GOVERNANCE                                   │
│ Access reviews · Segregation of duties · JML · Unified audit    │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 4 — AUTHORIZATION                                         │
│ PDP (Cedar/Zanzibar-style/OPA) · Entitlements · Fine-grained    │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 3 — PROTOCOL TRANSLATION                                  │
│ SAML IdP · OIDC OP · Kerberos · LDAP gateway · Password vault   │
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

## 10. Vendor-Agnostic Lessons from the Nineteen NIST Builds

NIST SP 1800-35 documented nineteen builds using commercially available products. Across those builds, several vendor-agnostic lessons emerged — these should shape any RFP, PoC, or architecture decision.

### Lesson 1 — Out-of-the-box integration is not a given
In the EIG Crawl phase, NIST discovered that many ICAM, endpoint, and network components from different vendors **do not integrate with each other out of the box** in ways required to make ICAM solutions function as PDPs. Network-level PEPs (switches, routers, firewalls) rarely integrate directly with ICAM. **Before selecting components, map the integration matrix and prove it in a lab.**

### Lesson 2 — EPP / endpoint posture must feed the PDP
Build E1B2 (Zscaler as PE) did not have an EPP that integrated with Zscaler in the NCCoE lab. The result: Zscaler could enforce its own compliance checks but could not consume rich endpoint-health signals or calculate confidence/trust scores. **Confidence-level scoring requires end-to-end integration across EPP, MDM, EDR, and the PDP.**

### Lesson 3 — Multiple PDPs need to share context
Real ZTAs have multiple PDPs. Most do not integrate with each other. One PDP may know an endpoint is non-compliant while another PDP is unaware. **Plan explicitly for PDP-to-PDP signal sharing**, or centralize decisions where possible. NCCoE build E3B2 documented a one-way integration (Intune → Forescout) but not the reverse — a real-world gap most enterprises also face.

### Lesson 4 — SIEM / SOAR / Data Security / UEBA should feed the PDP in near-real-time
These systems hold rich context the PDP needs to make good decisions. **Treat PDP integration as a hard requirement when selecting SIEM and data-security tools.**

### Lesson 5 — Policy fragmentation is real — plan for it
Because a ZTA typically has multiple PDPs, policy rules are distributed across endpoint, ICAM, network, and data-security components. **Maintain a single map of where every rule lives.** Policy-as-code stored in Git is the emerging answer.

### Lesson 6 — Resource-side authentication is frequently missing
Most EIG Crawl builds could not authenticate or verify the health of the endpoint *hosting* the resource — only the requesting endpoint. This is a common gap. **Treat resource authentication as a first-class requirement, not an afterthought.**

### Lesson 7 — Network enforcement of "which endpoints may join the network at all" is often absent
NIST's EIG Crawl builds manually joined endpoints to the network with no initial authentication gate. **Deploy NAC or equivalent posture-based admission control as a foundational capability.**

### Lesson 8 — Automated remediation closes the loop
When an endpoint falls out of compliance, ZTA should deny access. But ZTA should also **trigger automated remediation** via the UEM/MDM and patch management systems — otherwise the user is blocked indefinitely with no path back.

---

## 11. A Three-Horizon Migration Roadmap

Most enterprises cannot flip a switch. A realistic phased approach:

### Horizon 1 (0–12 months): Consolidate Authentication
- Complete the application inventory and classify into the seven-tier matrix.
- Migrate all Tier 1–2 apps to federated SSO (OIDC/SAML).
- Enforce MFA universally; prefer passkeys and FIDO2 hardware keys.
- Stand up SCIM provisioning for the top 20 apps.
- Deploy or validate EDR/EPP and UEM/MDM integration with the IDP.
- Complete discovery of the existing environment (Step 1).
- Baseline policies (Step 2).

### Horizon 2 (12–24 months): Extend the Fabric
- Deploy an Identity-Aware Proxy for Tier 3 legacy web apps.
- Stand up LDAP gateway / Kerberos bridge for Tier 4–5.
- Introduce Secure Web Authentication (SWA) for Tier 6 long-tail apps.
- Begin workload identity rollout for Tier 7 (SPIFFE/SPIRE, IAM Roles Anywhere, dynamic secrets).
- Replace standing admin privilege with PAM + just-in-time.
- Deploy ZTNA / SDP and/or Microsegmentation for lateral-movement containment.
- Integrate SIEM / SOAR / UEBA signals into PDP decision inputs.

### Horizon 3 (24+ months): Externalize Authorization and Mature Continuously
- Select a PDP (Cedar, OpenFGA, SpiceDB, OPA) and adopt policy-as-code.
- Pilot externalized authorization on one or two greenfield apps.
- Define a migration playbook for existing apps to move permission logic into the PDP.
- Adopt Continuous Access Evaluation (CAEP / Shared Signals Framework) so that revocation propagates within seconds, not hours.
- Extend data-level security (classification, DLP, IRM, encryption-at-endpoint).
- Institutionalize continuous validation — use a tool like Mandiant Security Validation or an equivalent to emulate attacks in production and verify controls.

---

## 12. Common Pitfalls — And How to Avoid Them

| Pitfall | Mitigation |
|---------|-----------|
| Treating SCIM as optional | Without automated deprovisioning, federation just creates orphans faster. Make SCIM a gate for every onboarding. |
| Putting rich permissions in the ID token | Keep tokens lean. Put rich policy in the PDP. |
| One giant "employee" role | Defeats least privilege. Model entitlements around job functions, not headcount. |
| Password vaulting without audit | SWA is pragmatic, but credentials must be audited and rotated — otherwise it's a shadow credential store. |
| Forgetting service accounts | Service accounts often get ten-year-old passwords in a config file. Workload identity is not optional. |
| No break-glass plan | If the IDP is down, how does anyone log in? Document, test, and rotate. |
| Conflating identity with entitlement | Being *Alice* (AuthN) is not the same as being authorized to approve $1M purchase orders (AuthZ). |
| Assuming the perimeter still works for cloud | Cloud resources live outside it. Protect them individually. |
| Big-bang deployment | NIST explicitly recommends incremental rollout. Start with ICAM + EPP, then grow. |
| Ignoring user experience | A ZTA users hate will be circumvented. Bake UX into every policy decision. |

---

## 13. Quick Reference — Standards and Frameworks to Align With

Align your ZTA program documentation and controls with the following. NIST SP 1800-35 maps controls to the first three explicitly.

- **NIST SP 800-207** — Zero Trust Architecture (foundational principles)
- **NIST SP 1800-35** — Implementing a Zero Trust Architecture (practice guide, nineteen example builds)
- **NIST Cybersecurity Framework 2.0** (CSF 2.0)
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

## 14. Closing — The One Thing to Remember

Zero Trust is not about buying a single product or flipping to a new network topology. It is about **moving security decisions out of individual applications and into a centralized, context-aware, continuously-evaluated policy layer** — while retrofitting the long tail of legacy applications through translation gateways.

The NIST SP 1800-35 nineteen builds are proof that this is achievable today using commercially available technology. The enterprise work is not the technology — it is the sequencing, the governance, the integration across existing investments, and the patience to execute incrementally over years.

> **Get the layers right, and every future protocol — continuous access evaluation, workload identity, post-quantum crypto — is just another plug-in.**
> **Get them wrong, and you will rebuild your identity stack every five years.**

---

## Appendix A — Policy Engines Used in the NIST SP 1800-35 Builds

For reference when comparing against vendor proposals:

| Phase | Build | Policy Engine(s) / PDP |
|-------|-------|------------------------|
| EIG Crawl | E1B1 | Okta Identity Cloud, Ivanti Access ZSO |
| EIG Crawl | E2B1 | Ping Identity PingFederate |
| EIG Crawl | E3B1 | Microsoft Azure AD Conditional Access (now Entra Conditional Access) |
| EIG Run | E1B2 | Zscaler ZPA Central Authority |
| EIG Run | E3B2 | Microsoft Azure AD Conditional Access, Microsoft Intune, Forescout eyeControl, Forescout eyeExtend |
| EIG Run | E4B3 | IBM Security Verify |
| SDP | E1B3 | Zscaler ZPA Central Authority |
| Microsegmentation | E2B3 | Ping Identity PingFederate, Cisco ISE, Cisco Secure Workload |
| SDP + Microsegmentation | E3B3 | Microsoft Azure AD Conditional Access, Intune, Sentinel, Forescout eyeControl, Forescout eyeExtend |
| SDP | E1B4 | Appgate SDP Controller |
| SDP + SASE | E2B4 | Symantec Cloud SWG, Symantec ZTNA, Symantec CASB |
| SDP | E3B4 | F5 BIG-IP, F5 NGINX Plus, Forescout eyeControl, Forescout eyeExtend |
| SDP + Microsegmentation + EIG | E4B4 | VMware Workspace ONE Access, VMware UAG, VMware NSX-T |
| SASE + Microsegmentation | E1B5 | Palo Alto Networks NGFW, Palo Alto Networks Prisma Access |
| SDP + SASE | E2B5 | Lookout SSE, Okta Identity Cloud |
| SDP + SASE | E3B5 | Microsoft Entra Conditional Access, Microsoft Security Service Edge |
| SDP + Microsegmentation | E4B5 | AWS Verified Access, Amazon VPC Lattice |
| SDP + Microsegmentation | E1B6 | Ivanti Neurons for Zero Trust Access |
| SASE | E2B6 | Google Chrome Enterprise Premium — Access Context Manager |

**Note:** NIST does not endorse any vendor. These are example builds. Your selection should be driven by your existing stack, integration compatibility, and operating model.

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

*End of document.*
