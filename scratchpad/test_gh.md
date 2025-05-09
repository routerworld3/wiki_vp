---

date: 2025-05-09
title: "Host GitHub Enterprise Server (GHES)  Instead of GitHub Cloud"
status: Proposed  # Accepted / Deprecated / Superseded once decided

---
## Context

We need our version‑control and CI/CD platform to handle **Controlled Unclassified Information (CUI)** at DoD IL‑4/5. GitHub Enterprise Cloud (github.com) is FedRAMP Moderate *LI‑SaaS* only and lacks IL‑5 authorization, so any CUI committed there constitutes a spill. We require an alternative that preserves familiar GitHub workflows without that risk.

## Decision

> **Deploy GitHub Enterprise Server (GHES) in Separate AWS GovCloud VPC/Account.**

## Consequences

### Positive

* Meets CUI-Requirements.
* Supports CAC/mTLS authentication and customer‑managed encryption keys.
* Enables isolated self‑hosted runners.

### Negative

**Operational**

* Requires a dedicated operations footprint for upgrades, backups, and DR tests.
* Backup/restore and cross‑region disaster‑recovery are customer‑owned; mis‑configuration can cause prolonged outage or data loss.
* Continuous monitoring, alerting, and capacity tuning (CloudWatch, Prometheus) must be built and maintained.
* **Uptime / SLA** – 99.9 %+ availability becomes our responsibility; requires HA design validation, and routine failover drills.

**Security**

* Limited ability to install host‑based security tooling (MDE, AWS SSM) on the hardened appliance—defence relies on perimeter controls.
* Security fixes reach GHES weeks after they roll out to GitHub Cloud; admins must track advisories and apply updates quickly.


## Alternatives Considered

| Option                              | Why Rejected / Deferred                               |
| ----------------------------------- | ----------------------------------------------------- |
| **Stay on GitHub Enterprise Cloud** | Fails CUI/IL‑5 requirement; high spill risk.          |
| **Navy Flank Speed GHES**           | Access limited to NMCI; excludes subcontractors.      |



