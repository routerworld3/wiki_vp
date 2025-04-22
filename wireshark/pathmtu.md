#### 1. Where MTU gets decided

```
Application  ─►  Socket API  ─►  OS kernel (TCP/UDP)  ─►  NIC driver  ─►  Wire
             (write 64 KB)        (slice into MSS)        (adds FCS)
```

* **The kernel, not the application, owns packetization.**  
* Every write the app makes is broken into segments no larger than the *current* **Maximum Segment Size (MSS)**, which is *Path‑MTU – L4/L3 headers* (40 bytes for IPv4+TCP).

---

#### 2. How the kernel discovers the right MSS/MTU

| Phase | Decision logic (TCP example) | Reference |
|-------|------------------------------|-----------|
| **SYN handshake** | Each side advertises its largest receive MSS (`TCP option 2`). Initial MSS chosen = `min(local MSS, peer MSS, interface MTU−40)`. | citeturn0search3 |
| **After the first data burst** | *Path‑MTU Discovery* (PMTUD): kernel sends full‑size segments with DF=1. If an intermediate hop returns **ICMP Type 3 Code 4**, kernel lowers the path MTU and shrinks MSS. | citeturn0search3turn0search2 |
| **If ICMP never comes back** | Linux/FreeBSD/Windows now use **Packetization‑Layer PMTUD (PLPMTUD, RFC 4821)**: they probe with larger payloads and back off on loss, avoiding dependence on ICMP. | citeturn0search2 |

For UDP, the kernel simply hands the entire datagram to IP. If its size > interface MTU and DF=1, the send call fails with **EMSGSIZE**, giving the *application* a chance to chop the payload or clear DF.

---

#### 3. What knobs an application *can* turn

| API / Setting | OSes | Effect | When you’d use it |
|---------------|------|--------|-------------------|
| `setsockopt(IPPROTO_IP, IP_MTU_DISCOVER, IP_PMTUDISC_DO)` | Linux | Forces DF=1 and full PMTUD even for UDP; EMSGSIZE returned if oversize | DNS servers that must never fragment. citeturn0search0 |
| `setsockopt(IPPROTO_IP, IP_MTU_DISCOVER, IP_PMTUDISC_DONT)` | Linux | Clears DF; kernel may fragment. **Breaks PMTUD**—last‑ditch workaround for black‑hole paths. | Legacy UDP app where ICMP is blocked. |
| `setsockopt(IPPROTO_TCP, TCP_MAXSEG, size)` | Linux/BSD/Windows | Hard limits MSS for one TCP socket (cannot exceed interface MTU−40). | Middlebox‑friendly apps such as embedded TLS terminators. citeturn0search1 |
| `WSAIoctl(SIO_TCP_SET_MAXSEG, …)` | Windows | Same as `TCP_MAXSEG`. | As above. |
| QUIC / HTTP‑3 libraries (`max_packet_size`) | Cross‑platform | User‑space congestion algorithms probe MTU themselves; kernel sees UDP datagrams already sized. | High‑performance services over paths with frequent MTU changes (e.g., Wi‑Fi → 5G). |

> **Typical line‑of‑business software never calls these.** Databases, web servers, gRPC, etc., trust the kernel to adapt.

---

#### 4. Putting it together for your EC2‑to‑System‑B flow

1. **Inside the VPC** you leave the ENI MTU at 9001.  
2. The first egress hop (NAT GW, TGW, on‑prem firewall) **clamps MSS to ≤ 1460** so that no packet bigger than 1500 ever exits AWS.  
3. Applications on EC2 run unmodified; their sockets start with MSS≈8961 and instantly shrink after the SYN/SYN‑ACK when they hit the clamp.  
4. If the on‑prem firewall drops the ICMP “frag‑needed” messages, PLPMTUD still converges—just slower—because the OS probes upward from a safe baseline.  
5. Only if you run your own UDP protocol with DF=1 (VoIP, IPSec ESP in transport mode) do you need to set `IP_PMTUDISC_DO` or manually cap datagram size to ≈1472.

---

#### 5. Key take‑aways

* **Applications don’t “choose the MTU”;** they can *influence* it through socket options but normally let the OS adapt.  
* TCP’s combination of handshake MSS negotiation + (PL)PMTUD means the correct size is found automatically—*if* either ICMP is allowed *or* modern stacks are in use.  
* The only time you must intervene is when you:  
  * ship custom UDP over DF=1,  
  * tunnel protocols whose headers eat into the 1500 budget, or  
  * operate across middleboxes that mishandle PMTUD and cannot be fixed.
