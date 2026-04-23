# Enterprise Identity Architecture: A Practitioner's Guide to Multi-Protocol Authentication and Authorization

*A reference pattern for Enterprise IDP architects navigating the shift from app-embedded auth to centralized, standards-based identity.*

---

## Executive Summary

Modern enterprises are converging on a clear identity pattern: **SAML for legacy enterprise SaaS**, **OIDC/OAuth 2.0 for new and mobile-first applications**, and **externalized policy-based authorization** (Google Zanzibar, AWS Cedar/Verified Permissions, OpenFGA) for fine-grained access control. This standardization moves authentication and authorization logic *out* of individual applications and *into* the Identity Provider (IDP) and policy decision layer.

The problem: **not every application supports modern protocols.** Legacy apps may only speak LDAP, Kerberos, header-based auth, or form-based login. Some custom apps only support basic auth or API keys. An enterprise pattern must therefore accommodate a *spectrum* of authentication capabilities while still delivering single sign-on (SSO), consistent session management, MFA enforcement, and unified audit.

This document articulates that pattern.

---

## Part 1: Clearing Up the Confusion — AuthN vs. AuthZ

Before architecture, terminology. The confusion between authentication and authorization is the single biggest source of design errors in enterprise identity.

### Authentication (AuthN) — "Who are you?"

Authentication is the process of **proving identity**. It answers: *Is this user really Alice?* It produces an **authenticated subject** (a user, service, or device) typically represented as a token or session.

Inputs to AuthN:
- Something you know (password, PIN)
- Something you have (hardware token, phone, passkey)
- Something you are (biometric)
- Somewhere you are (network, geo-location — contextual)

Outputs of AuthN:
- A **token** (SAML assertion, ID token, access token) or **session cookie**
- Identity claims: `sub`, `email`, `groups`, `amr` (authentication methods), `acr` (assurance level)

### Authorization (AuthZ) — "What are you allowed to do?"

Authorization is the process of **deciding whether an authenticated subject may perform an action on a resource**. It answers: *Can Alice read document #42?* It is evaluated *after* authentication.

Inputs to AuthZ:
- The authenticated subject and its attributes/roles
- The resource being accessed
- The action being attempted
- Context (time, location, device posture, risk score)
- Policies (who is allowed to do what under which conditions)

Outputs of AuthZ:
- A **decision**: permit, deny, or indeterminate (sometimes with obligations)

### Side-by-Side Contrast

| Dimension | Authentication | Authorization |
|-----------|---------------|---------------|
| Question answered | Who is the user? | What can the user do? |
| When it runs | At login / token issuance | At every resource access |
| Standard protocols | SAML, OIDC, WebAuthn, Kerberos, LDAP bind | XACML, OPA/Rego, Cedar, Zanzibar (ReBAC) |
| Typical output | Token / session / assertion | Permit / Deny decision |
| Failure mode | Login fails | 403 Forbidden |
| Changes frequency | Rare (per session) | Frequent (per request) |
| Owned by | IDP | Application or Policy Decision Point (PDP) |

### Why People Confuse Them

1. **Tokens carry both.** An OIDC ID token authenticates; a scoped OAuth access token *looks* authorization-like but only conveys *delegated* permissions — the resource server still evaluates policy.
2. **"Roles" blur the line.** Group membership is an AuthN claim; role-to-permission mapping is AuthZ. When the IDP pushes roles into the token, it feels like authorization is happening at login — but the decision is deferred to the application.
3. **The same team often owns both.** IAM teams manage directories, groups, *and* policies, so the two concerns bleed together operationally.

**Rule of thumb for architects:** If a change requires the user to log in again, it's AuthN. If a change takes effect on the next request, it's AuthZ.

---

## Part 2: The Industry Trend — Externalization

### The Old World: Auth Logic Inside the App

Traditionally every application implemented its own:
- User store (local DB with hashed passwords)
- Login form and session manager
- Role table and permission-check code (`if (user.role == "admin") ...`)
- Password reset, MFA enrollment, account lockout

Consequences: inconsistent MFA, password sprawl, orphaned accounts, inconsistent audit, and painful offboarding.

### The New World: Externalized AuthN and AuthZ

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENTERPRISE IDP (AuthN)                        │
│  Directory · MFA · Passkeys · Risk · Session · Federation        │
└───────────────┬─────────────────────────────┬───────────────────┘
                │ SAML / OIDC                 │ SCIM provisioning
                ▼                             ▼
        ┌──────────────┐              ┌──────────────┐
        │ Application  │──query──────▶│  Policy      │
        │  (PEP)       │◀──decision───│  Decision    │
        └──────────────┘              │  Point (PDP) │
                                      │  Zanzibar/   │
                                      │  Cedar/OPA   │
                                      └──────────────┘
                                      AuthZ
```

**Authentication externalization** (SAML/OIDC to IDP) is now mature and near-universal for new SaaS.

**Authorization externalization** is earlier in the curve but accelerating:
- **Google Zanzibar** — relationship-based access control (ReBAC) at planet scale; the model behind Google Docs sharing.
- **AWS Cedar / Verified Permissions** — a purpose-built policy language combining RBAC and ABAC.
- **OpenFGA / SpiceDB / Authzed / Permit.io / Oso** — open-source/commercial Zanzibar-inspired systems.
- **Open Policy Agent (OPA)** with Rego — general-purpose policy engine, widely used for infra AuthZ (Kubernetes, service mesh).

The goal in both cases is identical: **lift cross-cutting identity concerns out of every app, standardize them, and manage them centrally.**

---

## Part 3: The Reality — Not All Apps Support Modern Protocols

Enterprise IDP architects must support a **protocol capability matrix** across the app portfolio:

| Tier | Capability | Example Apps | IDP Strategy |
|------|-----------|--------------|--------------|
| 1 | Native OIDC / OAuth 2.0 / PKCE | Modern SaaS, mobile apps, SPAs | Direct OIDC federation |
| 2 | Native SAML 2.0 | Salesforce, Workday, ServiceNow, legacy SaaS | Direct SAML federation |
| 3 | Header-based / reverse-proxy auth | Older web apps, internal portals | IDP-aware reverse proxy (IAP) injects headers |
| 4 | Kerberos / IWA | On-prem Windows apps, SharePoint, file shares | Kerberos + AD; IDP via Kerberos constrained delegation |
| 5 | LDAP bind | Legacy Java/Unix apps, Jenkins, older appliances | LDAP proxy / virtual directory fronted by IDP |
| 6 | Form-based / no federation | Ancient web apps with local login | Secure Web Authentication (password vaulting + form-fill) |
| 7 | API keys / basic auth / mTLS | Machine-to-machine, legacy APIs | Secrets broker + workload identity (SPIFFE/SPIRE) |

A mature enterprise identity architecture must cover **all seven tiers** through a **single pane of glass** — one IDP, one MFA policy, one audit trail, one offboarding action.

---

## Part 4: The Enterprise Pattern — Multi-Protocol Authentication Hub

### Core Architectural Principles

1. **Single Source of Truth for Identity.** One authoritative directory (typically Entra ID, Okta Universal Directory, Ping, or ForgeRock) holds the canonical user record. Everything else is a projection.
2. **One Primary Authentication Event.** The user authenticates *once* to the IDP with strong MFA. All downstream app access is derived from that event.
3. **Protocol Translation at the Edge.** The IDP (or an identity-aware proxy) translates the canonical session into whatever protocol the target app speaks.
4. **Lifecycle via SCIM.** User create/update/disable flows from the IDP outward via SCIM 2.0 wherever possible; via directory sync or custom connectors otherwise.
5. **Policy Decisions Externalized.** Coarse-grained entitlements (who gets access to the app at all) live in the IDP; fine-grained permissions (who can do what inside the app) are increasingly delegated to a PDP.
6. **Zero Trust Context.** Every authentication and authorization decision considers device posture, network, risk score, and time — not just "did the password match?"

### The Pattern: Layered Identity Fabric

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 5 — POLICY & GOVERNANCE                                   │
│ Access reviews · Segregation of duties · JML workflows · Audit  │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 4 — AUTHORIZATION                                         │
│ PDP (Cedar/Zanzibar/OPA) · Entitlements · Fine-grained policies │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 3 — PROTOCOL TRANSLATION                                  │
│ SAML IdP · OIDC OP · Kerberos KDC · LDAP front · Password vault │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 2 — PRIMARY AUTHENTICATION                                │
│ Passkeys · MFA · Risk engine · Session · Device trust           │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 1 — IDENTITY SOURCE OF TRUTH                              │
│ Directory · HRIS integration · Groups · Attributes              │
└─────────────────────────────────────────────────────────────────┘
```

### How Each App Tier Integrates

**Tier 1 & 2 (OIDC / SAML native):** Straightforward federation. IDP issues ID token (OIDC) or SAML assertion. Groups/roles are pushed as claims or attributes. SCIM provisioning keeps app user list in sync.

**Tier 3 (Header-based):** Deploy an identity-aware reverse proxy (e.g., Azure App Proxy, Cloudflare Access, Google IAP, F5 APM, NGINX+, Pomerium). The proxy authenticates the user via OIDC/SAML to the IDP, then injects signed HTTP headers (`X-Remote-User`, `X-Remote-Groups`) into the upstream request. The legacy app trusts only the proxy.

**Tier 4 (Kerberos/IWA):** Use the IDP's Kerberos support (e.g., Entra ID Kerberos, Okta IWA agent) or a federation proxy that performs S4U2Self/S4U2Proxy on behalf of the federated user. Suitable for on-prem Windows resources.

**Tier 5 (LDAP):** Deploy an LDAP gateway (e.g., Okta LDAP Interface, Entra Domain Services, JumpCloud LDAP) that speaks LDAP to the app but backs onto the cloud IDP. The app thinks it's talking to AD; it's really talking to the IDP.

**Tier 6 (Form-based, no federation):** Use **Secure Web Authentication (SWA)** — sometimes called "password vaulting" or "form-fill SSO." The IDP stores an encrypted per-user credential for the app; when the user clicks the app tile, a browser extension or IDP-hosted login flow injects the credentials into the login form. Not true federation, but centralizes access control, audit, and offboarding.

**Tier 7 (Machine identity):** Replace long-lived secrets with short-lived workload credentials: SPIFFE/SPIRE, AWS IAM Roles Anywhere, Entra Workload Identity, HashiCorp Vault dynamic secrets. mTLS with workload certs is the gold standard.

### Decision Flow for New App Onboarding

```
          ┌──────────────────────────┐
          │ New app to onboard       │
          └───────────┬──────────────┘
                      ▼
         Does it support OIDC?───────Yes──▶ Federate via OIDC (preferred)
                      │
                      No
                      ▼
         Does it support SAML?───────Yes──▶ Federate via SAML
                      │
                      No
                      ▼
         Can it run behind a
         reverse proxy with headers?─Yes──▶ IAP with header injection
                      │
                      No
                      ▼
         Kerberos / LDAP only?───────Yes──▶ LDAP gateway or Kerberos bridge
                      │
                      No
                      ▼
         Form-based web login?───────Yes──▶ Secure Web Authentication (vaulting)
                      │
                      No
                      ▼
         Machine-to-machine?─────────Yes──▶ Workload identity (SPIFFE/mTLS)
                      │
                      No
                      ▼
              Escalate / redesign
```

---

## Part 5: Authorization Pattern — From RBAC to ReBAC/ABAC

Authorization has its own maturity curve that parallels authentication.

| Model | Description | Strength | Weakness |
|-------|-------------|----------|----------|
| **ACL** | Resource-by-resource lists | Simple | Doesn't scale, no inheritance |
| **RBAC** | Roles grant permissions; users get roles | Easy to audit, fits HR structure | Role explosion, no per-resource context |
| **ABAC** | Policies over user/resource/context attributes | Very flexible, context-aware | Hard to reason about, complex debugging |
| **ReBAC** | Permissions via relationships between users and resources (Zanzibar) | Ideal for collaborative apps (sharing, hierarchy) | Requires modeling discipline |
| **PBAC** | Central policy engine; apps ask PDP at runtime | Auditable, centrally managed | Latency, availability of PDP |

### The Pragmatic Enterprise Target

Most enterprises converge on a **hybrid**:
- **RBAC for coarse app entitlement** — "Members of `finance-analysts` group get access to the Finance app." Managed in the IDP, enforced at federation time.
- **ReBAC or ABAC for fine-grained in-app decisions** — "User can edit this document if they own it, or the folder is shared with their team, and they're on a managed device." Managed in the PDP, enforced at runtime.

This mirrors the AuthN pattern: **centralize the 80% case, delegate the long tail to specialized layers.**

---

## Part 6: Governance and Lifecycle — The Often-Missed Piece

Protocols are necessary but not sufficient. A mature identity architecture also requires:

- **Joiner / Mover / Leaver (JML)** automation driven by the HRIS (Workday, SAP SuccessFactors) as the authoritative trigger, with SCIM propagation to all downstream apps.
- **Access reviews and recertification** (NIST 800-53 AC-2, SOX, ISO 27001) — periodic attestation that each user's access is still warranted.
- **Segregation of Duties (SoD)** — cross-app policy preventing toxic combinations (e.g., cannot both approve and submit the same PO).
- **Privileged Access Management (PAM)** — just-in-time, session-recorded elevation for admin access, distinct from standing privileged accounts.
- **Non-human identity governance** — service accounts, bot identities, and workload identities are now the majority of identities in most enterprises and need the same lifecycle rigor.
- **Unified audit** — every AuthN event, AuthZ decision, and admin action funneled to a SIEM with consistent schema.

---

## Part 7: Recommended Reference Architecture

A target-state enterprise identity stack for a mid-to-large organization typically looks like:

**Identity plane**
- HRIS (Workday, etc.) as authoritative source for employees
- Cloud IDP (Entra ID / Okta / Ping) as the identity fabric
- Passkey-first MFA, with fallback to FIDO2 hardware keys
- Risk-based adaptive authentication
- SCIM 2.0 provisioning to all Tier 1–2 apps

**Access plane**
- Identity-aware proxy for Tier 3 apps
- LDAP/Kerberos gateway for Tier 4–5 apps
- SWA for Tier 6 apps
- SPIFFE/workload identity for Tier 7

**Policy plane**
- Centralized PDP (Cedar, OpenFGA, or OPA) for apps adopting externalized AuthZ
- Policy-as-code stored in Git, tested in CI, deployed via GitOps
- Decision logs shipped to SIEM

**Governance plane**
- IGA platform (SailPoint, Saviynt, Omada) for access reviews and SoD
- PAM for admin access (CyberArk, BeyondTrust, Teleport)
- Unified audit in SIEM + UEBA for anomaly detection

---

## Part 8: Migration Strategy — Getting from Here to There

Most enterprises cannot flip a switch. A realistic three-horizon approach:

**Horizon 1 (0–12 months): Consolidate AuthN.**
- Inventory all apps and classify into the 7-tier matrix.
- Migrate all Tier 1–2 apps to federated SSO (OIDC/SAML).
- Enforce MFA (passkeys where possible) universally.
- Stand up SCIM provisioning for top-20 apps.

**Horizon 2 (12–24 months): Extend the Fabric.**
- Deploy identity-aware proxy for Tier 3 apps.
- Stand up LDAP gateway / Kerberos bridge for Tier 4–5.
- Introduce SWA for Tier 6 long-tail apps.
- Begin workload identity rollout (Tier 7).
- Replace standing admin privilege with PAM + JIT.

**Horizon 3 (24+ months): Externalize AuthZ.**
- Select a PDP (Cedar, OpenFGA, OPA) and define policy-as-code standards.
- Pilot externalized AuthZ on 1–2 greenfield apps.
- Define migration playbook for existing apps to move permission logic to the PDP.
- Integrate PDP decisions into unified audit.
- Move to continuous access evaluation (CAEP) so that authZ revocation can propagate within seconds.

---

## Part 9: Common Pitfalls to Avoid

1. **Treating SCIM as optional.** Without automated deprovisioning, federation just creates orphaned accounts faster.
2. **Roles in the ID token become the permission model.** Tempting, but you end up with hundreds of roles and no real policy. Keep tokens lean; put rich policy in the PDP.
3. **One giant role for "employee."** Defeats least privilege. Model entitlements around job functions, not headcount.
4. **Password vaulting without strict audit.** SWA is pragmatic but must be audited and rotated; otherwise it's a shadow credential store.
5. **Forgetting service accounts.** Humans get MFA and JML; service accounts often get 10-year-old passwords in a config file. Workload identity is not optional.
6. **No break-glass plan.** If the IDP is down, how does anyone log into anything? Document, test, rotate.
7. **Conflating identity with entitlement.** Being *Alice* (AuthN) is not the same as being *authorized to approve $1M POs* (AuthZ). Keep the layers clean.

---

## Closing Thought

The strategic direction is unmistakable: **identity logic leaves the application**. Authentication has largely completed this journey via SAML and OIDC. Authorization is mid-journey, with Zanzibar-style ReBAC and policy-as-code engines leading the way. Machine identity is the next frontier.

An Enterprise IDP architect's job is no longer to "set up SSO." It is to design a **layered identity fabric** that (a) accommodates every tier of application capability, (b) delivers a consistent user and security experience across all of them, and (c) positions the enterprise to adopt each new wave of externalization — authorization, workload identity, continuous evaluation — without re-architecting from scratch.

Get the layers right, and every future protocol is just another plug-in. Get them wrong, and you will rebuild your identity stack every five years.

---

*Reference standards: SAML 2.0 · OIDC Core 1.0 · OAuth 2.1 · FAPI 2.0 · SCIM 2.0 · WebAuthn L3 · FIDO2 · SPIFFE · XACML 3.0 · CAEP · Shared Signals Framework · NIST SP 800-63-4 · NIST SP 800-207 (Zero Trust)*
