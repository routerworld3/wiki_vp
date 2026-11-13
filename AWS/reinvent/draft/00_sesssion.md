
**Times below follow your workbook and are Las Vegas local time—PST.** Some dates differ from AWS’s published networking guide, so confirm the current portal before reserving. AWS also notes that schedules and venues can change. [Networking & Content Delivery](https://aws.amazon.com/blogs/networking-and-content-delivery/your-aws-networking-and-content-delivery-guide-to-reinvent-2026/?trk=article-ssr-frontend-pulse_little-text-block\&utm_source=chatgpt.com)

**Monday, November 30 — GovCloud connectivity and inspection architecture**

| Time | Recommended session | Venue | Why it matters for you |
|---|---|---|---|
| **8:30–9:30 AM** | **NET327 — Connectivity strategies across AWS Partitions** · Breakout | MGM Grand | Directly addresses commercial/GovCloud boundaries, VPN, Direct Connect, proxies, DNS, and isolation requirements. |
| 10–11 AM | **NET217-R — More than a heartbeat: Designing health checks that matter** · Chalk talk | MGM Grand | Useful for your NLB→ALB patterns, health-check endpoints, and failover troubleshooting. |
| Noon–1 PM | **COP305-R — Turn security logs into actionable intelligence** · Builders’ session | Wynn/Encore | Hands-on investigation across CloudTrail, S3 access logs, and VPC flow logs. Useful for evaluating your centralized logging approach; this session focuses on CloudWatch. |
| **1:30–2:30 PM** | **SEC431 — Network Firewall deployment models: pros, cons, best practices** · Chalk talk | Wynn/Encore | **Your most important Monday session.** Compare centralized, distributed, multi-endpoint, and proxy deployment models against your inspection VPC design. |
| 4:30–5:30 PM | **NET204-R — Centralize AWS PrivateLink endpoints at scale with Amazon VPC Lattice** · Builders’ session | MGM Grand | Explore endpoint consolidation for your shared-services architecture and 100–500 mission-owner accounts. Treat it as an option to evaluate for GovCloud applicability. |

**Monday alternative:** If load balancing and DX operations are more urgent, attend **NET326, 1–2 PM**, followed by **NET406, 2:30–3:30 PM**, both at Caesars Forum. They cover NLB source-IP preservation, inspection integration, and DX monitoring. This replaces the midday logging/firewall route above.

**Tuesday, December 1 — Hands-on network defense and IAM**

| Time | Recommended session | Venue | Why it matters for you |
|---|---|---|---|
| **Noon–2 PM** | **SEC315-R — Hands-on Network Defense with AWS Network Firewall and Route 53 DNS Firewall** · Workshop | Wynn/Encore | **Your best practical network-security workshop.** Covers traffic inspection, IDS/IPS, DNS defenses, and domain filtering in a VPC/TGW environment. |
| **2:30–3:30 PM** | **SEC424-R1 — A deep dive on IAM policy evaluation** · Chalk talk | Wynn/Encore | Strong fit for cross-account roles, GitHub OIDC, permission boundaries, and understanding why access is allowed or denied. |

These two sessions give you three hours of focused technical work with no hotel transfer.

**Tuesday alternative:** **NET301-R1 — See the routes change: Live BGP with AWS Direct Connect**, **11:30 AM–12:30 PM at Caesars Palace**, is especially relevant to your DXGW, Transit VIF, and BGP questions. **It overlaps the workshop**, so choose it instead if DX maintenance and failover are your immediate priority. You can still attend the afternoon IAM session.

**Wednesday, December 2 — VPC architecture, firewall placement, and federation**

| Time | Recommended session | Venue | Why it matters for you |
|---|---|---|---|
| **8:30–9:30 AM** | **NET304 — Advanced VPC design and new capabilities** · Breakout | MGM Grand | Evaluate newer networking capabilities against your current VPC, routing, and shared-services designs. |
| **10:30–11:30 AM** | **NET324-R1 — Network security architecture: Deployment patterns for firewalls** · Chalk talk | Caesars Forum | Direct fit for ingress/egress inspection and your comparison of AWS Network Firewall with third-party firewall architectures. |
| **2:30–3:30 PM** | **SEC399 — Maintain accountability when using IAM federation** · Chalk talk | MGM Grand | Directly discusses Entra/Okta federation and preserving individual accountability when users assume shared IAM roles. |

**Wednesday alternative:** **NET314 — Tenant isolation at scale**, **2:30–3:30 PM at MGM Grand**, conflicts with SEC399. Choose NET314 if mission-owner isolation is more urgent than identity auditing; it covers TGW, PrivateLink, Lattice, and cross-account boundaries.

**Thursday, December 3 — Your highest-priority day**

All five recommendations are at **Wynn/Encore**, with 30-minute gaps between sessions.

| Time | Recommended session | Why it matters for you |
|---|---|---|
| **10–11 AM** | **SEC3303 — Conquer Suricata: simplify rule writing on AWS Network Firewall** · Code talk | Directly relevant to your strict-order rule groups, TLS/SNI controls, and managing rule complexity. Bring specific rule examples. |
| **11:30 AM–12:30 PM** | **SEC309-R — Network firewall deployment without the guesswork: codify, deploy, done** · Builders’ session | Uses reusable Terraform modules for Network Firewall and DNS Firewall in a multi-VPC environment. Strong fit for your IaC deployment model. |
| **1–2 PM** | **COP339 — Logging strategy for agentic investigations** · Chalk talk | Despite the AI-oriented title, the abstract addresses your exact questions: centralized logging, ingest transformations, enrichment, and which logs deserve hot storage. |
| **2:30–3:30 PM** | **SEC313 — Hands-on with the AWS Network Firewall proxy for secure egress** · Builders’ session | Evaluate explicit-proxy egress, overlapping CIDRs, and TLS inspection against your current NAT/proxy architecture. |
| **4–5 PM** | **SEC376 — Orchestrate GuardDuty and Network Firewall to prevent exfiltration** · Chalk talk | Connects Network Firewall, DNS Firewall, endpoint policies, SCPs/RCPs, GuardDuty, and IAM Access Analyzer into a layered egress design. |

**My strongest Thursday picks are SEC3303, COP339, and SEC376.** They offer the clearest connection to problems you are actively solving.

**Friday, December 4 — Resilient access and security at scale**

| Time | Recommended session | Venue | Why it matters for you |
|---|---|---|---|
| **8:30–9:30 AM** | **SEC422 — Architect resilient, multi-region workforce access on AWS** · Breakout | Wynn/Encore | Relevant to Entra/Identity Center dependencies, regional STS, identity-provider outages, and break-glass access. |
| **10–11 AM** | **SEC383 — Network policy across hundreds of accounts with AWS Network Security Manager** · Breakout | Wynn/Encore | Strong architectural fit for centrally governing security across hundreds of mission-owner accounts. **The abstract describes Network Firewall support as forthcoming**, so ask what is actually available. |

**Friday alternative:** **SEC373 — AWS and Nu: Building scalable architecture using IAM Account access manager**, **10:30–11:30 AM**, overlaps SEC383. Choose it if cross-organization workforce access is your bigger problem.

**Bring these questions to the chalk talks**

- **Inspection:** “How would you enforce Internet/NIPR inspection while allowing our authorized east-west traffic to bypass inspection, with symmetric return paths?”
- **Suricata:** “How should we structure strict-order rules for TLS/SNI filtering, default-deny behavior, and exceptions?”
- **Ingress:** “Which NLB/ALB/TGW combinations preserve the client IP, and where must authorization rely on forwarded headers?”
- **Logging:** “Which logs should stay hot, which should go to S3/Security Lake, and how should we provide account-scoped access to an external cyber provider?”
- **GovCloud:** “Which demonstrated capabilities are available in `us-gov-west-1` and `us-gov-east-1`, and what is the supported alternative where they are unavailable?”

Many chalk talks and workshops show **zero remaining seats in your export**. Check current availability first; AWS permits walk-up attendance subject to space. [Networking & Content Delivery](https://aws.amazon.com/blogs/networking-and-content-delivery/your-aws-networking-and-content-delivery-guide-to-reinvent-2026/?trk=article-ssr-frontend-pulse_little-text-block\&utm_source=chatgpt.com)
