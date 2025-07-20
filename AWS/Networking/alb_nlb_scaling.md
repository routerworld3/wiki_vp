 if you are allocating a **/26 subnet per AZ** (which gives you 64 IPs total, 59 usable after AWS reserves 5), we can give you a realistic estimate of how many **ALBs + NLBs** you can fit **per AZ**, based on their ENI/IP usage.

---

## 📦 IP Availability in `/26` Subnet

| Subnet Size | Total IPs | Reserved by AWS | Usable IPs    |
| ----------- | --------- | --------------- | ------------- |
| `/26`       | 64        | 5               | **59 usable** |

---

## 🧠 ENI/IP Usage per Load Balancer (per AZ)

| Load Balancer Type | ENIs/IPs Used (Min) | ENIs/IPs Used (Scaling) |
| ------------------ | ------------------- | ----------------------- |
| **ALB**            | 1                   | 10–30 (avg \~20)        |
| **NLB**            | 1                   | 1–2 (rarely scales)     |

---

## ✅ Scenario: Fitting ALBs + NLBs in 59 IPs (per AZ)

Let’s try different mixes:

---

### 🧮 Case 1: Conservative (ALBs can scale to 20 ENIs)

* Each ALB = \~20 IPs
* Each NLB = 1 IP

#### 💡 Max combinations:

| Count of ALBs | Max NLBs (remaining IPs) | Total IPs |
| ------------- | ------------------------ | --------- |
| 2 ALBs        | (59 - 40) = 19 NLBs      | 58        |
| 1 ALB         | 39 NLBs                  | 58        |
| 0 ALB         | 59 NLBs                  | 59        |

---

### 🧮 Case 2: Light Load (ALBs scale to 10 ENIs)

* Each ALB = \~10 IPs

| Count of ALBs | Max NLBs | Total IPs |
| ------------- | -------- | --------- |
| 4 ALBs        | 19 NLBs  | 59        |
| 5 ALBs        | 9 NLBs   | 59        |

---

### 🧮 Case 3: Static (ALBs never scale)

* Each ALB = 1 IP
* **Only valid for test or low-load scenarios**

| ALBs | NLBs | Total |
| ---- | ---- | ----- |
| 20   | 39   | 59    |
| 30   | 29   | 59    |
| 59   | 0    | 59    |

⚠️ **Not safe in production** — ALBs can scale unpredictably.

---

## ✅ Practical Safe Limits (per AZ `/26`)

| LB Type          | Max Safe Count                      |
| ---------------- | ----------------------------------- |
| **ALB (scaled)** | 2–3                                 |
| **NLB**          | 30–40                               |
| **Mix**          | 1 ALB + 39 NLBs<br>2 ALBs + 19 NLBs |

---

## 💡 Recommendation

* Plan **1–2 ALBs per AZ max**, assuming they may scale
* Use remaining capacity for NLBs, which are more IP-efficient
* Track ENI/IP usage via CloudWatch metrics and VPC subnet viewer

---

Would you like:

* Terraform subnet carving logic that reserves `/26` per AZ for ALB?
* IPAM-compatible pool planning for scalable SCCA deployment?
