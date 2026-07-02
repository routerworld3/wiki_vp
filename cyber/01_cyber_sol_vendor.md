# Cybersecurity Solutions — Vendor Landscape Addendum

*Who leads each category, according to Gartner*

> Compiled July 2026 · Sources: current Gartner Magic Quadrant and Market Guide reports

This addendum extends the main guide with the **top vendors Gartner recognizes** in each category. One caveat worth internalizing before reading: not every category is ranked the same way. **Magic Quadrants** name a discrete set of "Leaders" (a defensible "top" list). **Market Guides** — used for newer or fast-moving categories like CNAPP and DSPM — list "Representative Vendors" with **no ranking at all**. Where that is the case, this document says so plainly rather than inventing a top 5.

> **Golden rule** (from the main guide) still applies: map tools to problems, not to logos. A "Leader" is a strong shortlist candidate, not an automatic buy. Gartner itself states it does not endorse any vendor and advises against picking solely by rating.

---

## 15. Top Vendors by Category (Gartner)

### Cloud Security — CNAPP

**Report type:** Market Guide (2025) — Representative Vendors, **not ranked.**

Gartner deliberately does not publish a CNAPP Magic Quadrant; the 2025 Market Guide notes that although many providers exist, only a handful offer the breadth and depth of a full platform. The names below appear consistently across the guide and Gartner Peer Insights as the most cited comprehensive platforms.

| Vendor | Product | What buyers cite it for |
|---|---|---|
| **Wiz** | Wiz CNAPP | Agentless-first, unified security graph correlating code→cloud→runtime; strong attack-path analysis |
| **Palo Alto Networks** | Prisma Cloud / Cortex Cloud | Broadest capability coverage; deep CSPM/CWPP/CIEM with IaC and pipeline integration |
| **Microsoft** | Defender for Cloud | Native to Azure, strong multicloud posture; tight SIEM/XDR integration via Defender |
| **CrowdStrike** | Falcon Cloud Security | Runtime protection strength carried over from EDR heritage; single-agent story |
| **Orca / Sysdig / Aqua** | (peer set) | Orca: agentless breadth; Sysdig: runtime + eBPF depth; Aqua: container/Kubernetes lineage |

> Because CNAPP is unranked, treat this as "the platforms that keep showing up," not a strict 1–5. Wiz, Palo Alto, and Microsoft are the near-universal shortlist trio in enterprise deals.

### Endpoint & Workload — EDR / EPP

**Report type:** Magic Quadrant for Endpoint Protection Platforms (July 2025) — **Leaders (ranked quadrant).**

| # | Vendor | Product | Position highlight |
|---|---|---|---|
| 1 | **CrowdStrike** | Falcon | Furthest in Completeness of Vision & highest Ability to Execute; Leader 6th consecutive time |
| 2 | **Microsoft** | Defender for Endpoint | Leader for the sixth time; strong cross-signal integration |
| 3 | **SentinelOne** | Singularity | Leader 5 years running; autonomous response emphasis |
| 4 | **Palo Alto Networks** | Cortex XDR | Leader 3 years running; strong MITRE ATT&CK results |
| 5 | **Sophos** | Intercept X | Leader 16 consecutive reports; MDR/EDR bundle strength |

> Bitdefender was the sole Visionary in 2025 — a strong tool, just placed outside the Leaders box. The 2026 MQ (published mid-2026) again named CrowdStrike a Leader; positions are stable year to year.

### Network — Firewall (NGFW / Hybrid Mesh Firewall)

**Report type:** Magic Quadrant for Hybrid Mesh Firewall (Aug 2025, inaugural) — **Leaders (ranked).**

Gartner retired the standalone "Network Firewall" MQ and replaced it with Hybrid Mesh Firewall, reflecting convergence across hardware, virtual, cloud, and SASE form factors. Only four vendors made the Leaders quadrant.

| # | Vendor | Product family | Position highlight |
|---|---|---|---|
| 1 | **Palo Alto Networks** | Strata / PA-Series | Furthest in Completeness of Vision; AI-driven runtime security |
| 2 | **Fortinet** | FortiGate / FortiOS | Highest in Ability to Execute; ASIC performance, quantum-ready VPN |
| 3 | **Check Point** | Quantum / CloudGuard | Leader; transparent pricing, flexible licensing |
| — | Cisco / HPE (Juniper) | — | Cisco = Visionary; HPE Juniper = Challenger (not Leaders) |

> For a public web app you still want a WAF, not an NGFW (see below). The firewall MQ covers network-edge and data-center enforcement, not L7 web-app attacks.

### Network — Web App Protection (WAF / WAAP)

**Report type:** Magic Quadrant for (Cloud) Web Application & API Protection — **Leaders (ranked).**

Gartner has since shifted this category toward a Market Guide/Critical Capabilities model, but the consistently recognized Leaders across recent WAAP cycles are:

| Vendor | Product | What buyers cite it for |
|---|---|---|
| **Cloudflare** | WAAP portfolio | Massive edge network; one-click WAF + DDoS + bot + API shield |
| **Akamai** | App & API Protector | Web-scale, diverse app portfolios; strong adaptive engine |
| **Imperva** | Cloud WAF / App Security | Multi-form-factor (appliance→SaaS→cloud-native); RASP + DB security adjacency |
| **F5** | Distributed Cloud WAAP | Hybrid deployments; deep application-delivery heritage |
| **AWS / Fastly** | AWS WAF / Fastly | Cloud-native fit (AWS WAF for AWS-centric estates); Fastly high customer satisfaction |

> **For SCS-C03:** AWS WAF is the in-scope AWS-native answer for edge/L7 protection (OWASP Top 10, rate limiting, bot control), typically fronted by CloudFront. The third-party leaders above are the enterprise alternatives Gartner ranks highest.

### User Access — SSE (Security Service Edge)

**Report type:** Magic Quadrant for Security Service Edge (May 2025) — **Leaders (ranked).**

| Vendor | Product | Position highlight |
|---|---|---|
| **Zscaler** | Zero Trust Exchange | Highest in Ability to Execute; Leader 4th consecutive year |
| **Palo Alto Networks** | Prisma Access | Leader 3 years running; top-ranked Advanced SSE critical capabilities |
| **Netskope** | Netskope One | Perennial Leader; strong CASB/DLP data-centric heritage |
| Others | Cisco, Broadcom, Skyhigh, iboss | Round out the 9 evaluated vendors across the quadrants |

> SSE is the security half of SASE. If a vendor also sells SD-WAN as one converged platform, that's the separate SASE Platforms MQ (Fortinet, Palo Alto, and others are Leaders there).

### SOC Operations — SIEM

**Report type:** Magic Quadrant for SIEM (Oct 2025) — **Leaders (ranked).**

| Vendor | Product | Position highlight |
|---|---|---|
| **Microsoft** | Sentinel | Leader; cloud-native, unified SecOps with XDR + Copilot |
| **Google** | Google Security Operations (Chronicle) | Leader; furthest Completeness of Vision, Gemini-driven |
| **Splunk (Cisco)** | Enterprise Security | Long-standing Leader; deep data platform + TDIR |
| **Securonix** | Unified Defense SIEM | Leader 6th consecutive time; UEBA + SOAR built in |
| **Exabeam / Gurucul** | (peer Leaders) | Exabeam: 6-time Leader, UEBA focus; Gurucul: next-gen analytics Leader |

> On AWS specifically, Security Lake + Athena/OpenSearch is the in-scope native "log lake + analysis" pattern; the SIEM leaders above are what enterprises layer on top or feed from it.

---

## 16. One-Page Vendor Map

Quick reference: category → Gartner report type → top names to shortlist.

| Category | Report | Top names (shortlist) |
|---|---|---|
| **CNAPP** | Market Guide (unranked) | Wiz, Palo Alto (Prisma/Cortex), Microsoft Defender for Cloud, CrowdStrike, Orca |
| **EDR / EPP** | MQ Leaders | CrowdStrike, Microsoft, SentinelOne, Palo Alto (Cortex), Sophos |
| **Firewall (HMF/NGFW)** | MQ Leaders | Palo Alto, Fortinet, Check Point |
| **WAF / WAAP** | MQ Leaders | Cloudflare, Akamai, Imperva, F5 (AWS WAF native) |
| **SSE** | MQ Leaders | Zscaler, Palo Alto (Prisma Access), Netskope |
| **SIEM** | MQ Leaders | Microsoft, Google, Splunk, Securonix, Exabeam |
| **DSPM** | Market Guide (unranked) | Wiz, Microsoft Purview, BigID, Cyera, Varonis |

> DSPM, like CNAPP, has no Magic Quadrant — the names shown are frequently cited Market Guide / Peer Insights vendors, not a ranked list.

---

## 17. How to Read These Rankings

- **Quadrant ≠ ranking.** Leaders are one quadrant, not a scoreboard. Within "Leaders," axis position (execution vs. vision) matters, and a Visionary or Niche Player can be the right fit for a specific need or budget.
- **Market Guides don't rank.** A Market Guide lists Representative Vendors with no ordering. Any "top 5" drawn from one is editorial, not Gartner's verdict.
- **Names drift.** Categories converge and get renamed — "Network Firewall" became "Hybrid Mesh Firewall"; WAF became WAAP; several point tools now roll into CNAPP and SASE. Match the problem, then find the current report name.
- **Gartner's own disclaimer.** Gartner explicitly does not endorse vendors and advises against selecting solely by rating. Use these lists to build a shortlist, then test against your own requirements.

---

*Vendor positions reflect the most recent Gartner reports available as of July 2026 and change with each cycle. Verify against the current report before making procurement decisions.*
