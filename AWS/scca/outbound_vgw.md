P**complete AWS SCCA-compliant path for outbound internet-bound traffic** from a **Spoke VPC EC2 instance**, through centralized **AWS Network Firewall inspection**, to **NAT Gateway in Egress VPC**, and finally out through **VGW/DXGW** using a **DoD-owned public IP block** (e.g., `190.18.0.0/20`).

We’ll include:

- VPC CIDRs  
- Route tables at **every hop**
- No dual inspection (only in Inspection VPC)

---

## 🧱 Assumptions

| Component         | Description                              | CIDR                 |
|------------------|------------------------------------------|----------------------|
| **Spoke VPC-A**  | Workload VPC w/ EC2 instance (EC2-A)     | `10.1.0.0/16`        |
| **Inspection VPC**| Centralized firewall (AWS Network Firewall) | `100.64.0.0/24`   |
| **Egress VPC**   | NAT GW, VGW attachment, DoD public IPs   | `190.18.0.0/20`      |
| **DXGW**         | Connects to DoD router                    | —                    |

---

## 🛰 Flow Overview

**EC2-A (Spoke VPC-A)** ➝ **TGW** ➝ **Inspection VPC (Network Firewall)** ➝ **TGW** ➝ **Egress VPC (NAT + VGW)** ➝ **DXGW** ➝ **DoD gateway** ➝ Internet

---

## 🔄 Route Tables by Hop

---

### 🔹 1. **Spoke VPC-A Route Table**

Attached to workload subnet (e.g. `10.1.1.0/24`):

```text
Destination        Target
10.1.0.0/16        local
0.0.0.0/0          tgw-xxxxxxx
```

---

### 🔹 2. **Transit Gateway Route Table (Spoke VPC Attachment)**

Attached to Spoke VPC-A TGW attachment:

```text
Destination        Attachment
0.0.0.0/0          Inspection VPC
```

---

### 🔹 3. **Inspection VPC Route Tables**

#### A. **TGW Subnet Route Table**

Traffic entering from TGW:

```text
Destination        Target
100.64.0.0/24      local
0.0.0.0/0          AWS Network Firewall endpoint
```

#### B. **Firewall Subnet Route Table**

After inspection is done:

```text
Destination        Target
100.64.0.0/24      local
0.0.0.0/0          tgw-xxxxxxx (TGW back to Egress VPC)
```

---

### 🔹 4. **Transit Gateway Route Table (Inspection VPC Attachment)**

Attached to Inspection VPC TGW attachment:

```text
Destination        Attachment
0.0.0.0/0          Egress VPC
```

---

### 🔹 5. **Egress VPC Route Tables**

#### A. **TGW Subnet Route Table**

Traffic arriving from TGW:

```text
Destination        Target
190.18.0.0/20      local
0.0.0.0/0          natgw-id
```

#### B. **NAT Subnet Route Table**

NAT Gateway subnet with public CIDR:

```text
Destination        Target
190.18.0.0/20      local
0.0.0.0/0          vgw-id
```

---

### 🔹 6. **VGW → DXGW**

- VGW automatically advertises `190.18.0.0/20` to DXGW via **BGP**
- DXGW advertises it to the **DoD gateway**

---

## 🌐 Summary Route Path for 8.8.8.8

| Step | Source       | Destination      | Next Hop                        |
|------|--------------|------------------|----------------------------------|
| 1    | EC2-A        | 8.8.8.8          | TGW                             |
| 2    | TGW          | Inspection VPC   | Firewall endpoint                |
| 3    | Firewall     | TGW              | TGW (post-inspection route)     |
| 4    | TGW          | Egress VPC       | NAT Gateway                     |
| 5    | NAT Gateway  | 8.8.8.8          | VGW                             |
| 6    | VGW          | 8.8.8.8          | DXGW ➝ DoD router ➝ Internet    |

---

✅ **Result**:  

- Traffic is **inspected** by AWS Network Firewall  
- **NATed to a DoD public IP**  
- Routed to Internet via **DXGW**, with **no IGW involved**

---

Would you like a Terraform or YAML manifest that builds this route flow? Or a diagram visual?
