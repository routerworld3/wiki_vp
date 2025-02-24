Below is an updated comparison table between **Application Load Balancer (ALB)** and **Network Load Balancer (NLB)** with an added row on how each handles SSL/TLS termination.

---

## 1. Overall Feature Comparison

| **Feature**                           | **Application Load Balancer (ALB)**                                                                               | **Network Load Balancer (NLB)**                                                                                     |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| **OSI Layer**                        | Layer 7 (Application layer)                                                                                      | Layer 4 (Transport layer)                                                                                            |
| **Supported Protocols**              | HTTP, HTTPS, gRPC, WebSocket                                                                                     | TCP, UDP, TLS                                                                                                        |
| **Routing Capabilities**             | - Host-based routing<br>- Path-based routing<br>- Header/rule-based routing                                      | - Directs traffic purely at the transport layer<br>- Optional connection-based / source IP-based hashing             |
| **SSL/TLS Termination**              | - **Full SSL/TLS termination** at the load balancer (L7)<br>- Integrates with AWS Certificate Manager (ACM)<br>- Supports SNI for multiple certs<br>- Can re-encrypt or forward unencrypted traffic to targets | - **TLS pass-through** or **TLS termination** (L4)<br>- When terminating, can also integrate with ACM and SNI<br>- Limited Layer 7 visibility (no advanced routing if pass-through)              |
| **Stickiness Mechanism**             | **Cookie-based** session affinity (AWSALB cookie or custom)                                                      | **Connection-based** stickiness; optional source IP-based consistent hashing (no HTTP cookie support)                 |
| **Use Cases**                        | - Web applications needing advanced L7 features<br>- Microservices & container apps<br>- WAF (layer-7) integration | - High-throughput, low-latency workloads<br>- Real-time streaming, IoT, gaming<br>- Static IP per AZ requirements     |
| **Performance/Latency**             | Processes at L7 (slightly higher latency) but scales to millions of requests/sec                                 | Extremely low latency; scales to millions of requests/sec                                                             |
| **Preserving Client IP**             | Inserts `X-Forwarded-For` header                                                                                 | Maintains source IP at network layer; can optionally enable Proxy Protocol                                           |
| **Target Types**                     | - EC2 instances<br>- IP addresses<br>- AWS Lambda<br>- Containers (ECS/EKS)                                      | - EC2 instances<br>- IP addresses<br>- Private Link endpoints<br>- Containers (ECS/EKS)                               |
| **Static IP / Elastic IP Support**   | Not natively (resolves via DNS); no direct Elastic IP attachment                                                 | Supports static IP (one per AZ), including Elastic IP addresses                                                       |
| **Key Differentiators**              | - Advanced request routing & inspection<br>- AWS WAF & Shield Advanced at L7<br>- Cookie-based stickiness         | - Ultra-low latency at L4<br>- Designed for sudden, large bursts of traffic<br>- Source IP preserved at L4            |
| **Pricing Considerations**           | Hourly + per LCU (Load Balancer Capacity Unit)                                                                   | Hourly + per NLCU (Network Load Balancer Capacity Unit)                                                               |
| **Best For**                         | - Traditional + modern web apps requiring L7 routing<br>- Stateful HTTP sessions with cookie stickiness          | - Non-HTTP protocols (TCP/UDP)<br>- High performance or real-time, low-latency apps<br>- Scenarios needing static IPs |

---

## 2. Stickiness (Session Affinity) Comparison

| **Aspect**                               | **ALB**                                                                                                   | **NLB**                                                                                                                    |
|-----------------------------------------|-----------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| **Mechanism**                           | **Cookie-based** (via AWSALB or custom cookie)                                                            | **Connection-based** at Layer 4; optional “source IP” consistent hashing                                                  |
| **Configuration Location**              | At the **Target Group** level                                                                             | Also configured at the **Target Group** level (no HTTP cookie support)                                                    |
| **Granularity**                         | - Request-level stickiness using HTTP cookies                                                             | - Connection-level or IP-based<br>- Once a TCP/UDP flow ends, a new connection may be routed to a different target        |
| **Common Use Cases**                    | - Maintaining user sessions (e.g., shopping carts)<br>- Web login session persistence                     | - Low-level protocols that don’t require HTTP inspection<br>- Handling stable connections for streaming or real-time data |
| **Impact on Client Experience**         | - Users with a valid cookie stay on the same backend<br>- Ideal for stateful web sessions                 | - Same connection => same target<br>- No continuity across new connections unless using source IP-based hashing           |
| **Pros**                                | - True HTTP session-level stickiness<br>- Highly configurable cookie settings                             | - Minimal overhead at L4<br>- Consistent hashing can provide stable routing based on client IP                            |
| **Cons**                                | - Slightly higher latency due to L7 inspection<br>- More complex rules can lead to higher costs           | - No native cookie support<br>- Stickiness is weaker if clients frequently change IP/port                                 |

---

### SSL/TLS Termination Key Points

- **ALB** (Layer 7):
  - Terminates SSL/TLS and can inspect/route requests at the application layer.
  - Supports Server Name Indication (**SNI**) with multiple certificates on the same listener.
  - Easily integrates with **AWS Certificate Manager** (ACM) for certificate provisioning.
  - Can optionally re-encrypt traffic to targets (HTTPS on the backend) or send it unencrypted (HTTP).

- **NLB** (Layer 4):
  - Offers **TLS pass-through** (no decryption at the load balancer) or **TLS termination**.
  - If terminating TLS, can also integrate with **ACM** for certificate management and use SNI.
  - Minimal overhead at L4, but lacks the deep inspection or advanced routing that ALB provides.
  - In pass-through mode, all SSL/TLS negotiations occur directly on the target, so the LB does not inspect payloads.

---

## 3. Conclusion

- **Choose ALB** for advanced **Layer 7** features, **SSL/TLS termination** with detailed request-level routing, cookie-based stickiness, and integration with services like WAF.
- **Choose NLB** for **Layer 4** workloads that demand ultra-low latency, require **static IP** or Elastic IP support, or rely on protocols like TCP/UDP. NLB can do TLS termination or pass-through, but it does not offer HTTP-layer session cookies or inspection.
