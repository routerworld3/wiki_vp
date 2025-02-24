Below is a concise, table-based summary comparing AWS **Application Load Balancer (ALB)** and **Network Load Balancer (NLB)**, including a focused comparison on **stickiness**.

---

## 1. Overall Feature Comparison

| **Feature**                           | **Application Load Balancer (ALB)**                                                               | **Network Load Balancer (NLB)**                                                                                  |
|--------------------------------------|----------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| **OSI Layer**                        | Layer 7 (Application layer)                                                                       | Layer 4 (Transport layer)                                                                                       |
| **Supported Protocols**              | HTTP, HTTPS, gRPC, WebSocket                                                                      | TCP, UDP, TLS                                                                                                    |
| **Routing Capabilities**             | - Host-based routing<br>- Path-based routing<br>- Header/rule-based routing                        | - Directs traffic purely at the transport level<br>- Optional connection-based/ source IP-based hashing          |
| **Stickiness Mechanism**             | **Cookie-based** session affinity (AWSALB or custom)                                               | **Connection-based** (Layer 4) stickiness; optional source IP-based consistent hashing (no cookie support)       |
| **Use Cases**                        | - Web apps requiring advanced L7 features<br>- Microservices & container apps<br>- WAF integration | - High-throughput, low-latency workloads<br>- Real-time streaming, IoT, gaming<br>- Static IP per AZ requirements |
| **Performance/Latency**             | Processes at L7 (slightly higher latency) but scales to millions of requests/sec                   | Extremely low latency; scales to millions of requests/sec                                                        |
| **Preserving Client IP**             | Inserts `X-Forwarded-For` header for the target                                                   | Maintains source IP at network layer; can optionally enable Proxy Protocol                                       |
| **Target Types**                     | - EC2 instances<br>- IP addresses<br>- AWS Lambda<br>- Containers (ECS/EKS)                       | - EC2 instances<br>- IP addresses<br>- Private Link endpoints<br>- Containers (ECS/EKS)                           |
| **Static IP / Elastic IP Support**   | Not natively (uses DNS-based entry points)                                                         | Supports static IP (one per AZ), including Elastic IP addresses                                                  |
| **Key Differentiators**              | - Advanced request routing & inspection<br>- AWS WAF & Shield Advanced integration at L7           | - Ultra-low latency at L4<br>- Designed for sudden, large bursts of traffic                                      |
| **Typical Pricing Considerations**   | Charged per-hour + per LCU (Load Balancer Capacity Unit)                                           | Charged per-hour + per NLCU (Network Load Balancer Capacity Unit)                                               |
| **Best For**                         | - Traditional + modern web apps<br>- Stateful HTTP sessions needing sticky sessions                | - Non-HTTP use cases (TCP/UDP)<br>- High performance or real-time, low-latency apps                              |

---

## 2. Stickiness (Session Affinity) Comparison

| **Aspect**                               | **ALB**                                                       | **NLB**                                                                                          |
|-----------------------------------------|---------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| **Mechanism**                           | **Cookie-based** (via AWSALB or custom cookie)               | **Connection-based** at Layer 4; optional “source IP” consistent hashing                         |
| **Configuration Location**              | At the **Target Group** level                                | Also configured at the **Target Group** level, but options are more limited (no HTTP cookies)    |
| **Granularity**                         | - Request-level stickiness using HTTP cookies                | - Connection-level or IP-based<br>- Once a TCP/UDP flow ends, a new connection could be re-routed |
| **Common Use Cases**                    | - Maintaining user sessions (e.g., shopping carts)<br>- Web login session persistence | - Low-level protocols that don’t require HTTP inspection<br>- Handling stable connections for streaming or real-time data |
| **Impact on Client Experience**         | - Users with a valid cookie remain on the same backend<br>- Great for stateful web sessions | - Same connection => same target<br>- No cookie-based continuity across separate connections     |
| **Pros**                                | - True HTTP session-level stickiness<br>- Highly configurable cookie settings            | - Minimal overhead at L4<br>- Consistent hashing is simpler if you only need IP-based sticky routing |
| **Cons**                                | - Slightly higher latency due to L7 inspection<br>- More complex routing rules can cost more | - No out-of-the-box cookie support<br>- Stickiness is weaker if clients change IP or open new connections |

---

### Key Takeaways

1. **ALB** provides **cookie-based** session stickiness at Layer 7, making it ideal for stateful HTTP workloads.
2. **NLB** is a **Layer 4** load balancer offering **connection-based** stickiness or optional source-IP-based consistent hashing, suitable for high-performance or real-time workloads that do not rely on HTTP session cookies.

Use **ALB** if you need advanced routing, HTTP/HTTPS inspection, or session-level (cookie) stickiness.  
Use **NLB** if you need ultra-low latency, static IPs, or are handling TCP/UDP workloads at Layer 4 (and can manage state elsewhere).
