

## Cloud WAN in one sentence

**AWS Cloud WAN is like building a global enterprise WAN backbone inside AWS, using policy instead of manually managing many regional TGWs, peering links, and route tables.**

AWS describes Cloud WAN as policy-based global networking, while Transit Gateway is more of a regional hub; Cloud WAN is better when you want AWS to implement the global network from centralized policy. ([AWS Documentation][1])

---

## The design principle

Think in **segments**, not tunnels.

```text
Enterprise Cloud WAN Core Network
│
├── PROD segment
├── DEV segment
├── SHARED-SERVICES segment
├── SECURITY / INSPECTION segment
└── ON-PREM / BRANCH segment
```

A **segment** is like a cloud VRF/security zone. Attachments such as VPCs, VPNs, Direct Connect gateways, and TGW route tables are mapped into segments, commonly by tags and attachment policies. ([AWS Documentation][2])

---

## Real enterprise example

Company has:

```text
US-East Region
  - Prod VPC
  - Dev VPC
  - Shared DNS VPC
  - Inspection VPC

US-West Region
  - Prod VPC
  - Dev VPC

Europe Region
  - Prod VPC
  - Branch VPNs

On-prem Data Centers
  - Direct Connect / VPN
```

Without Cloud WAN, they may build:

```text
TGW-East ─── TGW-West ─── TGW-Europe
   │             │             │
  VPCs          VPCs          VPCs
```

Then they manually manage:

* TGW peering
* route tables
* propagation
* segmentation
* regional consistency
* inspection routing

With Cloud WAN, they define a **core network policy**:

```text
prod attachments      → PROD segment
dev attachments       → DEV segment
shared services       → SHARED segment
firewall VPCs         → SECURITY segment
on-prem / branches    → ON-PREM segment
```

Cloud WAN policy then controls how routes are shared between those segments. AWS Cloud WAN supports segment actions for route sharing/control, and attachment policies to map resources to the right segment. ([AWS Documentation][3])

---

## How the “click” happens

### Traditional VPN / TGW mindset

```text
How do I connect Site A to Site B?
How do I peer TGW-East to TGW-West?
Which route table gets propagated?
```

### Cloud WAN mindset

```text
What business zone is this workload in?
Who is allowed to talk to whom?
Which traffic must pass inspection?
```

That is the real shift.

---

## Example traffic flows

### 1. Prod VPC in Virginia to Prod VPC in Oregon

Allowed directly inside PROD segment:

```text
Prod VPC East → Cloud WAN PROD Segment → Prod VPC West
```

Feels like same enterprise WAN.

---

### 2. Dev VPC to Prod VPC

Blocked or tightly controlled:

```text
Dev Segment ❌ Prod Segment
```

Or only allowed through inspection:

```text
Dev → Security Inspection → Prod
```

---

### 3. Branch office to cloud app

```text
Branch VPN / DX → Cloud WAN ON-PREM Segment → PROD Segment → App VPC
```

The branch does not need one VPN per VPC or region.

---

## Where enterprises use Cloud WAN

Use Cloud WAN when you have:

* multiple AWS Regions
* many AWS accounts/VPCs
* on-prem data centers
* branch offices
* SD-WAN integration
* need for consistent segmentation
* central network team managing policy

Do **not** rush to Cloud WAN if you only have one or two regions and a small number of VPCs. A Transit Gateway may be simpler; AWS notes TGW is regional and suitable when customers operate in a few Regions or want to manage routing themselves. ([AWS Documentation][1])

---

## Mental model

```text
Transit Gateway = regional cloud router

Cloud WAN = global enterprise network fabric

Segments = VRFs / security zones

Attachment policies = automatic onboarding rules

Segment actions = who can route to whom
```

## Final designer takeaway

Cloud WAN is not “just another VPN.”
It is AWS saying:

> Stop building hundreds of tunnels and route-table relationships. Define the enterprise network policy once, attach VPCs/sites by tags, and let AWS build the global routing fabric.

[1]: https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-cloud-wan.html?utm_source=chatgpt.com "AWS Cloud WAN"
[2]: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html?utm_source=chatgpt.com "Core network policy version parameters in AWS Cloud WAN"
[3]: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-network-actions-routes.html?utm_source=chatgpt.com "Add segment actions in an AWS Cloud WAN core network ..."
