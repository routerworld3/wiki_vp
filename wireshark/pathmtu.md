#### 1. Where MTU gets decided

```
Application  ─►  Socket API  ─►  OS kernel (TCP/UDP)  ─►  NIC driver  ─►  Wire
             (write 64 KB)        (slice into MSS)        (adds FCS)
```

* **The kernel, not the application, owns packetization.**  
* Every write the app makes is broken into segments no larger than the *current* **Maximum Segment Size (MSS)**, which is *Path‑MTU – L4/L3 headers* (40 bytes for IPv4+TCP).

---

#### 2. How the kernel discovers the right MSS/MTU

| Phase | Decision logic (TCP example) |
|-------|------------------------------|
| **SYN handshake** | Each side advertises its largest receive MSS (`TCP option 2`). Initial MSS chosen = `min(local MSS, peer MSS, interface MTU−40)`. 
| **After the first data burst** | *Path‑MTU Discovery* (PMTUD): kernel sends full‑size segments with DF=1. If an intermediate hop returns **ICMP Type 3 Code 4**, kernel lowers the path MTU and shrinks MSS. 
| **If ICMP never comes back** | Linux/FreeBSD/Windows now use **Packetization‑Layer PMTUD (PLPMTUD, RFC 4821)**: they probe with larger payloads and back off on loss, avoiding dependence on ICMP. 

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

### Why PLPMTUD exists  
Classical Path‑MTU Discovery (PMTUD – RFC 1191/1981) shrinks payload size only when it receives **ICMP “Fragmentation‑Needed” (Type 3 Code 4)**. When those ICMPs are filtered, large packets just vanish (“black‑hole” paths) and connections hang. **Packetization‑Layer PMTUD (PLPMTUD, RFC 4821)** fixes that by moving the logic **up one layer**, into the protocol that already has loss‑detection (TCP, SCTP, QUIC, …). It learns the usable size by *probing with real traffic* and watching whether the probe is acknowledged, so it works even when **no ICMP reaches the host**. citeturn1view0  

---

## The high‑level algorithm

| Step | Action | Result if probe **arrives** | Result if probe **lost** |
|------|--------|-----------------------------|--------------------------|
| 1 – Initialise | Start with a safe MSS (IPv4 ≈1460, IPv6 ≥1280). | — | — |
| 2 – “_Up‑probe_” | Send one data segment padded to **next‑larger candidate size** (e.g., 1500 → 1680 → 2000 → … or a binary search). | ACK covering the whole segment ⇒ raise *Path MTU* to that size, continue probing higher. | No ACK within **probe timeout** ⇒ assume the segment was too big; set a new “high‑water mark” below that size and probe again. |
| 3 – Production traffic | All following segments are limited to the *current* Path MTU (payload ≤ MSS). | Normal throughput. | Loss stops; connection continues at the lower MTU instead of stalling. |

The algorithm terminates when `search_low + 1 == search_high`; at that point the sender has found the largest size the path accepts. The same mechanism runs in reverse if it later observes repeated losses of full‑size segments (detecting a new bottleneck).

---

### How different transports implement the probes

| Transport | What a “probe packet” looks like | How success / failure is decided |
|-----------|----------------------------------|----------------------------------|
| **TCP** (kernel ≥ 2.6.17) | A single full‑size segment beyond previously ACKed data. (`tcp_mtu_probing`) | Segment ACKed → success; otherwise lost → failure. |
| **SCTP / DCCP** | HEARTBEAT/PAD chunk bundle of the target size. | Reception of HEARTBEAT‑ACK or SACK. |
| **QUIC** / HTTP‑3 | A `PING`+`PADDING` frame stuffed to target size (RFC 8899 update). | Normal ACK frame confirms delivery. |
| **Datagram apps (UDP/IPsec)** | Follows **DPLPMTUD** (RFC 8899). Probes include a PLPMTUD‑option or app‑level sequence number. | App‑level ACK/response or timer. |

---

## Linux example (what EC2 is running)

```bash
# See current setting (0=off, 1=black‑hole recovery, 2=always probe)
cat /proc/sys/net/ipv4/tcp_mtu_probing
# Force full PLPMTUD on every new TCP socket
sysctl -w net.ipv4.tcp_mtu_probing=2
```

Value `1` (the default since kernel 5.4) enables PLPMTUD only **after** the stack has detected that standard ICMP‑based PMTUD is failing; value `2` starts probing immediately. citeturn6search1

---

## What you observe on the wire

```text
Time   Dir  Len  Notes
------ ---- ---- ------------------------------------------------------
0.000  →    1460 Regular data
0.015  →    1680 ***Probe #1***    (DF=1)
0.030  ←     ACK  Probed bytes acknowledged   <-- success, raise PMTU
0.032  →    2000 ***Probe #2***
0.147  …   (no ACK; probe timer expires)      <-- considered lost
0.148  →    1750 ***Probe #3***               <-- next candidate down
0.165  ←     ACK  Success, PMTU=1750
```

The application never changes its send‑buffer calls—it just sees normal throughput once the search settles.

---

## Operational & design tips

1. **Leave jumbo‑frame (9001) MTU on intra‑VPC links** and let PLPMTUD adapt as traffic exits through NAT GW, TGW or on‑prem firewalls.  
2. **Clamp TCP MSS** (e.g., `--clamp-mss-to-pmtu` or fixed `1460`) at the first hop that *knows* it will soon hit a 1500‑byte link; this prevents super‑large probes from ever leaving AWS while still preserving jumbo performance inside.  
3. **Monitor** with `ss -tin`, where `pmtu` shows the live value per socket, or with Wireshark’s **“TCP Analyze > Path MTU”** feature.  
4. If you write your own UDP protocol, use the **DPLPMTUD state machine** from RFC 8899 or embed an ACKed sequence number so you can run the same probe/confirm cycle. citeturn7search0

---

### Take‑aways for architects

* **PLPMTUD is automatic** for every modern OS and for QUIC‑based stacks—you rarely need to touch the application.  
* It raises performance on good paths **and** prevents “large‑payload hangs” on ICMP‑filtered paths, which makes it ideal for mixed AWS/on‑prem networks.  
* The only mandatory network action is to **avoid mangling or blocking the probes** (e.g., middleboxes that drop TCP packets with uncommon MSS sizes); otherwise, the algorithm self‑tunes without operator help.
