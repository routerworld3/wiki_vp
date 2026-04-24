# Zero Trust Implementation — Executive Checklist
## A Companion Quick-Reference to the Full Implementation Guide

*Use this as a program-review tool, RFP input, or steering-committee artifact. Each item maps back to NIST SP 1800-35 and/or NIST SP 800-207 requirements.*

---

## Before You Start

- [ ] **Executive sponsor named** at CISO or CIO level with a multi-year mandate.
- [ ] **Program charter** approved, scoped over three horizons (0–12, 12–24, 24+ months).
- [ ] **Authoritative HRIS** identified as the source of truth for joiners, movers, and leavers.
- [ ] **Agreement that Zero Trust is a strategy, not a product** — budget structured accordingly.
- [ ] **Break-glass plan** drafted (what happens if the IDP is unavailable).
- [ ] **Shared vocabulary** established across IAM, network, endpoint, data-security, and application teams (AuthN vs. AuthZ, PE/PA/PEP, etc.).

---

## Discovery and Baseline (NIST SP 1800-35 Step 1)

- [ ] Inventory of all applications classified into the seven-tier authentication capability matrix.
- [ ] Inventory of all subjects: human users, contractors, partners, service accounts, workloads, devices.
- [ ] Inventory of all resources across on-premises, IaaS, PaaS, and SaaS.
- [ ] Discovery tools deployed to monitor and audit communication flows continuously.
- [ ] Authoritative data flow map for the top-20 most critical resources.

---

## Identity Foundation (Horizon 1)

- [ ] Single cloud IDP selected (Entra ID / Okta / Ping / ForgeRock / equivalent).
- [ ] Directory sync from HRIS established; manual account creation eliminated.
- [ ] Phishing-resistant MFA enforced universally (passkeys / FIDO2 preferred).
- [ ] All Tier 1–2 applications federated via OIDC or SAML.
- [ ] SCIM 2.0 provisioning live for the top-20 applications.
- [ ] Risk-based / adaptive authentication policies configured.
- [ ] Admin accounts moved off standing privilege to PAM + just-in-time.
- [ ] Service-account inventory completed; remediation plan for long-lived secrets.

---

## Policy Design (NIST SP 1800-35 Step 2)

- [ ] Access policies documented for each critical resource.
- [ ] Least privilege and separation of duties explicitly designed in.
- [ ] Contextual signals defined: device posture, location, time, risk score, data sensitivity.
- [ ] Policy inventory — map of **where every rule is configured** (which PDP / which product).
- [ ] Access reviews and recertification cadence defined (quarterly / annually by risk tier).
- [ ] Segregation-of-Duties rules defined across apps (e.g., approver ≠ requester for financial transactions).

---

## Endpoint and Device Posture

- [ ] EDR/EPP deployed on all managed endpoints.
- [ ] UEM/MDM deployed for all mobile and BYOD.
- [ ] Device posture signals integrated into IDP conditional access.
- [ ] BYOD policy documented — what is permitted, what is restricted.
- [ ] Automated remediation for non-compliant endpoints (patch management integration).
- [ ] Network Admission Control (NAC) or equivalent posture-based gate at network join.

---

## Legacy Application Integration (Horizon 2)

- [ ] Identity-Aware Proxy deployed for Tier 3 header-based web apps.
- [ ] LDAP gateway / virtual directory fronted by IDP for Tier 5 apps.
- [ ] Kerberos bridge configured for Tier 4 on-prem Windows apps.
- [ ] Secure Web Authentication (SWA) — with audit and rotation — deployed for Tier 6 long-tail apps.
- [ ] Workload identity rollout begun for Tier 7 (SPIFFE/SPIRE, IAM Roles Anywhere, dynamic secrets).

---

## Network and Access (ZTNA / SDP / Microsegmentation / SASE)

- [ ] ZTNA / SDP in place for remote access to internal applications — VPN retirement planned.
- [ ] Private applications not directly discoverable from the public internet.
- [ ] Microsegmentation in place for lateral-movement containment in critical zones.
- [ ] SASE solution deployed for branch offices and remote workers (as applicable).
- [ ] Cloud-resource protection does not hairpin through the on-prem network.

---

## Data-Level Security

- [ ] Data classification scheme defined and operational.
- [ ] DLP deployed for in-motion and at-rest enforcement.
- [ ] Information Rights Management (IRM) for high-classification content.
- [ ] Encryption-at-endpoint policies for downloaded sensitive data.
- [ ] Step-up authentication triggered on access to high-classification data.

---

## Continuous Evaluation and Monitoring

- [ ] SIEM ingesting all AuthN, AuthZ, and admin events with consistent schema.
- [ ] SOAR and UEBA signals feeding PDP decisions in near-real-time.
- [ ] Behavioral analytics deployed to detect anomalous access patterns.
- [ ] Session re-evaluation triggers defined (compliance drift, risk-score change, policy violation).
- [ ] CAEP / Shared Signals Framework roadmap to shorten revocation latency.

---

## Externalized Authorization (Horizon 3)

- [ ] Policy Decision Point product selected (Cedar, OpenFGA, SpiceDB, OPA, etc.).
- [ ] Policy-as-code stored in Git, tested in CI, deployed via GitOps.
- [ ] Pilot app migrated to externalized authorization.
- [ ] Migration playbook published for subsequent apps.
- [ ] PDP decision logs streamed to SIEM for audit.

---

## Validation and Testing (NIST SP 1800-35 Step 6)

- [ ] Test suite covering NIST SP 1800-35 Use Cases A through H.
- [ ] Red-team or breach-and-attack-simulation tool (e.g., MSV equivalent) deployed in production.
- [ ] Tabletop exercises run at least annually against ZTA failure scenarios.
- [ ] Continuous control-effectiveness reporting to executive steering committee.

---

## Governance and Lifecycle

- [ ] JML automation driven by HRIS with SCIM propagation to all downstream apps.
- [ ] Recertification campaigns running on defined cadence.
- [ ] Non-human identity governance in scope (service accounts, bots, workloads).
- [ ] SoD enforcement automated where possible.
- [ ] Unified audit schema across AuthN, AuthZ, admin actions, and data access events.
- [ ] Annual policy and architecture review scheduled.

---

## Vendor and Integration Due Diligence

- [ ] Integration matrix proven in lab before any production commitment.
- [ ] EDR / UEM → IDP integration validated end-to-end.
- [ ] Multi-PDP signal-sharing architecture documented where multiple PDPs exist.
- [ ] SIEM / SOAR / data-security tools have documented PDP integration paths.
- [ ] Resource-side authentication (not just requester-side) addressed.

---

## Red Flags to Watch For

| If you see this… | …it probably means |
|------------------|-------------------|
| One giant "employee" role grants access to everything | No least privilege modeling has been done |
| Passwords in config files, ten years old | No workload identity strategy |
| SCIM listed as "phase 2" | You will have orphaned accounts from day one |
| Policy rules scattered across five products with no map | Policy drift is guaranteed |
| "We trust the network" appears in any design document | Zero Trust has not been internalized |
| Big-bang cutover plan | Execution risk is too high; phase it |
| No break-glass procedure | First IDP outage will be a crisis |

---

## The Three Questions to Ask at Every Steering Review

1. **Coverage** — What percentage of our applications, identities, and data are now protected by the Zero Trust fabric, by tier?
2. **Policy integrity** — Can we produce a single authoritative view of *what policies are enforced where*? If not, what is the plan to get there?
3. **Continuous validation** — When did we last test a realistic attack scenario against the ZTA, and what did we find?

---

*End of checklist.*
