Great — now we’re switching to **inbound traffic**, where a public URL is hosted on an EC2 instance in **Spoke VPC-A**, with traffic **entering from DXGW** and **inspected** in an **Inspection VPC** before reaching the workload.

This is the **SCCA-compliant path for inbound DoD traffic to a public-facing workload**, using **DoD-assigned public IPs**, **Transit Gateway**, and **AWS Network Firewall**.

---

## 🌐 Scenario Summary

| Component         | Details |
|------------------|---------|
| **Public IP**     | `190.18.0.100` (from `/20`, DoD-owned) — attached to ENI of EC2-B |
| **DXGW**          | Connected to TGW |
| **TGW**           | Connects DXGW, Inspection VPC, and Spoke VPC-A |
| **Inspection VPC**| Central inspection point using AWS Network Firewall |
| **Spoke VPC-A**   | Hosts EC2-B (public workload) in subnet with `190.18.0.0/20` |
| **No IGW**        | All traffic in/out via DXGW only |
| **EC2-B**         | EC2 instance with public IP `190.18.0.100` |

---

## 🛰 Flow: Inbound From DXGW to EC2-B (with Inspection)

**On-prem ➝ DXGW ➝ TGW ➝ Inspection VPC ➝ TGW ➝ Spoke VPC ➝ EC2-B**

---

## 🛣 Step-by-Step Routing

---

### 🔹 1. **DXGW → TGW (Ingress Association)**

- DXGW receives traffic for `190.18.0.100`
- DXGW is **associated with TGW**
- The route `190.18.0.0/20` is **allowed** in the **TGW–DXGW allowed prefixes**
- DXGW forwards traffic to **TGW** using **BGP-based route targeting**

---

### 🔹 2. **TGW Route Table (Pre-Inspection)**
**Associated with DXGW attachment**:

```text
Destination           Attachment
190.18.0.0/20         Inspection VPC
```

> All traffic destined for the DoD-owned public block is routed **first to the Inspection VPC**.

---

### 🔹 3. **Inspection VPC Subnet Route Tables**

#### A. **TGW Subnet Route Table (entry point)**

```text
190.18.0.0/20         AWS Network Firewall endpoint
```

#### B. **Firewall Subnet Route Table (after inspection)**

```text
190.18.0.0/20         tgw-id   # Send back to TGW
```

---

### 🔹 4. **TGW Route Table (Post-Inspection)**

**Associated with Inspection VPC attachment:**

```text
Destination           Attachment
190.18.0.0/20         Spoke VPC-A
```

> After inspection, TGW forwards traffic to the **Spoke VPC**.

---

### 🔹 5. **Spoke VPC-A Route Table**

**Attached to subnet `190.18.0.0/24` containing EC2-B (public workload):**

```text
190.18.0.0/20         local
10.1.0.0/16           local
```

> Since `EC2-B` has an **ENI IP in the `190.18.0.0/20` block**, the destination IP is **local to the VPC**.

➡ Traffic reaches **EC2-B directly**.

---

## ✅ Summary: How the Traffic Reaches EC2-B (Public Workload)

| Step | Source       | Destination         | Routed Via                   |
|------|--------------|---------------------|------------------------------|
| 1    | DoD Gateway  | `190.18.0.100`      | DXGW                         |
| 2    | DXGW         | TGW                 | DXGW association             |
| 3    | TGW          | Inspection VPC      | TGW route table              |
| 4    | Firewall     | TGW                 | Inspection subnet route table|
| 5    | TGW          | Spoke VPC-A         | TGW post-inspection route    |
| 6    | Spoke VPC-A  | EC2-B               | Local VPC route              |

---

## 🔐 Important Notes

- **No IGW needed**: All traffic uses **DXGW + Transit Gateway**
- EC2 has a **public IP from a DoD block** assigned to its ENI
- **TGW is central**, managing both **inspection flow and final delivery**
- **Network Firewall** can inspect all ingress traffic before reaching workloads

---

Would you like a visual flow diagram or Terraform/YAML manifest to build this routing path?

Ah — now that’s an **important distinction** that aligns perfectly with **DoD SCCA guidance**:

> ✅ **Mission Owner EC2s should NOT have direct public IPs.**  
> ✅ **Public IPs must terminate on centralized AWS-managed infrastructure (e.g., ALB/NLB in a Central Ingress VPC)**  
> ✅ **Traffic must then be routed internally via Transit Gateway to the workload in Spoke VPC.**

---

## ✅ YES — This Is Not Only Possible, It's **Best Practice**

Let me walk you through the updated architecture and flow:

---

## 🧭 Updated Inbound Flow: DXGW ➝ Central Ingress VPC ➝ Inspection ➝ Spoke VPC EC2

| Component             | Notes |
|----------------------|-------|
| **DXGW**              | Receives traffic from DoD gateway (on-prem) |
| **Transit Gateway**   | Connects Ingress VPC, Inspection VPC, Spoke VPC |
| **Ingress VPC**       | Hosts ALB/NLB with **DoD public IP** (`190.18.0.0/20`) |
| **AWS Network Firewall** | Hosted in Inspection VPC |
| **Spoke VPC-A**       | Private EC2 (EC2-B) receives internal-only traffic |
| **No EC2 has public IP** | ✅ Compliant with SCCA |

---

## 🔁 Step-by-Step Flow

---

### 🔹 1. **On-Prem ➝ DXGW**

- DoD user accesses `https://public.mission.gov` (`190.18.0.50`)
- DNS resolves to the **public IP** bound to **NLB or ALB in Ingress VPC**
- Traffic reaches **DXGW**, associated with **TGW**

---

### 🔹 2. **TGW Route Table (DXGW Attachment)**

```text
Destination           Attachment
190.18.0.0/20         Ingress VPC
```

> Traffic for public IPs in your `/20` DoD block is routed to **Ingress VPC**.

---

### 🔹 3. **Ingress VPC**

- ALB/NLB receives request to `190.18.0.50`
- Target group is configured to forward to **EC2-B (private IP)**

But! 🔐 Before it reaches EC2-B, it must be **inspected**.

---

### 🔹 4. **Target Type = IP (NOT Instance)**

- ALB/NLB target group contains **IP targets** (e.g., `10.1.1.100` in Spoke VPC-A)
- These IPs are **reachable over TGW** — not directly

---

### 🔹 5. **Traffic Forwarded via TGW to Inspection VPC**

**TGW Route Table (Ingress VPC Attachment):**

```text
Destination           Attachment
10.1.0.0/16           Inspection VPC
```

**Inspection VPC Subnet Routes:**

- TGW ➝ AWS Network Firewall ➝ TGW (back)
- Fully inspect the request

---

### 🔹 6. **TGW Route Table (Post-Inspection)**

```text
Destination           Attachment
10.1.0.0/16           Spoke VPC-A
```

➡ Forward allowed traffic to EC2-B

---

### 🔹 7. **Spoke VPC Route Table**

```text
10.1.0.0/16           local
```

➡ EC2-B receives traffic, **never exposed directly to the public**

---

## 🔒 Security & Compliance Wins

✅ **No EC2 has public IP**  
✅ **Public IP terminates on AWS ALB/NLB** (meets FIPS 140-2 boundary requirement)  
✅ **All traffic passes through AWS Network Firewall**  
✅ **Centralized Ingress simplifies logging, monitoring, TLS termination**  
✅ **Works with NIPRNet or public Internet over DXGW**

---

## ✅ Summary Flow

```
[User → DoD Gateway]
       ↓
[DXGW → TGW]
       ↓
[TGW → Ingress VPC (ALB/NLB) → 190.18.x.x]
       ↓
[Target Group → IP: 10.1.1.100 (EC2-B)]
       ↓
[TGW → Inspection VPC (Firewall)]
       ↓
[TGW → Spoke VPC]
       ↓
[EC2-B]
```

---

## 🧠 Pro Tip

For **ALB** or **NLB** to forward traffic across VPCs via TGW:

- Use **IP target type**
- Ensure **TGW peering/associations** allow for return traffic (symmetric flow)
- Enable **TGW Appliance Mode** on **Inspection VPC TGW attachment** for stateful inspection

---

Would you like this modeled in a full Terraform example or want a diagram of this centralized ingress architecture?
