
---

### ✅ F5 to AWS Load Balancer Migration Decision Table

| **Question / Feature**                                               | **If YES → Use**        | **If NO → Use**      | **Notes / Action**                                                      |
| -------------------------------------------------------------------- | ----------------------- | -------------------- | ----------------------------------------------------------------------- |
| **Is the traffic HTTP or HTTPS?**                                    | ALB                     | NLB                  | ALB supports Layer 7 routing; NLB is L4 only                            |
| **Do you need TLS termination (SSL offload)?**                       | ALB or NLB              | NLB                  | Both can terminate TLS; if passthrough needed, use NLB                  |
| **Do you need TLS passthrough (end-to-end encryption)?**             | NLB                     | ALB                  | ALB cannot passthrough TLS                                              |
| **Do you need mTLS (client cert validation)?**                       | ALB (with TLS listener) | NLB (requires proxy) | ALB supports mTLS directly; NLB requires custom TLS proxy (e.g., Envoy) |
| **Do you need path-based or host-based routing?**                    | ALB                     | NLB                  | Only ALB supports L7 routing                                            |
| **Do you need sticky sessions (session affinity)?**                  | ALB                     | NLB                  | ALB supports cookie-based stickiness                                    |
| **Is traffic non-HTTP(S) (e.g., SMTP, SIP, custom TCP/UDP)?**        | NLB                     | ALB                  | Use NLB for non-HTTP protocols                                          |
| **Do you need to preserve the client’s IP address natively?**        | NLB                     | ALB                  | ALB requires X-Forwarded-For headers                                    |
| **Do you want native WAF integration?**                              | ALB                     | NLB                  | Only ALB integrates with AWS WAF                                        |
| **Do you require WebSocket or HTTP/2 support?**                      | ALB                     | NLB                  | ALB supports modern L7 protocols                                        |
| **Is the application Lambda-based (serverless backend)?**            | ALB                     | NLB                  | ALB can target Lambda functions directly                                |
| **Is custom TCP health check needed?**                               | NLB                     | ALB                  | ALB supports only HTTP/HTTPS health checks                              |
| **Is ultra-low latency, high-throughput needed (e.g. game server)?** | NLB                     | ALB                  | NLB is better suited for high-performance L4 traffic                    |
| **Do you need listener-level TLS handshake logs?**                   | NLB                     | ALB                  | NLB TLS listeners support CloudWatch logs                               |

---

### 🔽 Final Load Balancer Choice

| **Criteria Scorecard**    | **Choose** |
| ------------------------- | ---------- |
| ≥ 3 answers in ALB column | ALB        |
| ≥ 3 answers in NLB column | NLB        |
| Mixed/complex traffic     | Hybrid     |

---

### 🛠 Tip: Hybrid Pattern

For apps needing **both L7 features and static IPs**, consider:

* ALB → NLB (private IP target)
* ALB fronted by **AWS Global Accelerator** to provide static IPs

---

Would you like a **Google Sheet**, **Excel template**, or **interactive form** version of this table for planning migrations of multiple F5 VIPs?
