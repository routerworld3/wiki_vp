# Inbound Pattern 

---

## ✅ Simplified Ingress Patterns (All with Static IP via NLB)

| # | **Pattern**                                      | **Use Case**                                                                                  | **TLS Termination** | **Source IP Preserved** | **Static IP** | **IP-Based Filtering**          |
| - | ------------------------------------------------ | --------------------------------------------------------------------------------------------- | ------------------- | ----------------------- | ------------- | ------------------------------- |
| 1 | **NLB TLS Passthrough – IDP / CAC / mTLS**       | When MO workload (e.g., IDP) must validate **client certificates** (CAC/mTLS) directly        | At MO Workload      | ✅ Yes (via NLB)         | ✅ Yes (EIP)   | ✅ NLB SG                        |
| 2 | **NLB TLS Passthrough – Non-HTTP (SFTP, DB)**    | When protocol is **non-HTTP** (e.g., SSH, SFTP, PostgreSQL) and backend expects TLS directly  | At MO Workload      | ✅ Yes (via NLB)         | ✅ Yes (EIP)   | ✅ NLB SG                        |
| 3 | **NLB → ALB – Multi-tenant HTTPS**               | For **multiple** HTTPS workloads with **host-based routing** (e.g., site1, site2)             | At ALB              | ✅ Yes (via NLB)         | ✅ Yes (EIP)   | ❌ WAF only (no SG by host rule) |
| 4 | **NLB → ALB – Single HTTPS with IP restriction** | For **single HTTPS** app with **tight access control** (e.g., IP allowlist, Geo restrictions) | At ALB              | ✅ Yes (via NLB)         | ✅ Yes (EIP)   | ✅ WAF or NLB SG (or both)       |

---

## 🔍 Summary Table: Capabilities by Pattern

| Capability                          | Pattern 1  | Pattern 2 | Pattern 3  | Pattern 4  |
| ----------------------------------- | ---------- | --------- | ---------- | ---------- |
| TLS terminated at MO (for CAC/mTLS) | ✅          | ✅         | ❌          | ❌          |
| TLS terminated at ALB               | ❌          | ❌         | ✅          | ✅          |
| HTTP-level routing (Host/Path)      | ❌          | ❌         | ✅          | ❌ (Single) |
| WAF / OIDC / Header injection       | ❌          | ❌         | ✅          | ✅          |
| IP allowlisting via SG              | ✅          | ✅         | ❌          | ✅          |
| IP allowlisting via WAF             | ❌          | ❌         | ✅ (broad)  | ✅ (strict) |
| Source IP preserved to ALB          | N/A        | N/A       | ✅          | ✅          |
| Protocol support (HTTPS/TCP)        | HTTPS only | Any TCP   | HTTPS only | HTTPS only |

---

## 🧭 Decision Flow



---

## 🔐 Security Notes

* **Static IP** for all patterns is achieved using **NLB with EIP**
* **Source IP preserved** to ALB in **patterns 3 and 4**, allowing **GeoIP WAF**, audit logging, or user analytics
* **ALB WAF** gives **granular L7 IP filtering** (e.g., block non-DoD CIDRs, allow Gov VPNs)
* **NLB security groups** support **network-layer allowlisting**

---


