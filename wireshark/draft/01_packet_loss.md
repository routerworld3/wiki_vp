Yes — **TCP retransmissions can indicate packet loss**, but not every retransmission proves the network dropped a packet. You need to distinguish **real network loss** from **capture loss, reordering, duplicate ACKs, or application/server delay**.

The most important distinction is this:

* **Fast Retransmission** usually means TCP detected likely loss because it received multiple duplicate ACKs.
* **RTO Retransmission** means the sender waited for the retransmission timeout because no useful ACK arrived. RTOs are generally more damaging to performance.
* **TCP Previous segment not captured** may mean Wireshark missed the packet during capture, not necessarily that the network lost it.

## 1. How much packet loss is acceptable?

There is no single universal number, but for normal enterprise TCP traffic these are useful guidelines:

|  Packet loss | Interpretation                                                        |
| -----------: | --------------------------------------------------------------------- |
|       **0%** | Ideal                                                                 |
|   **< 0.1%** | Usually excellent                                                     |
| **0.1–0.5%** | Often tolerable, but measurable on high-latency/high-throughput flows |
|   **0.5–1%** | Concerning for TCP performance                                        |
|     **1–2%** | Significant degradation likely                                        |
|     **> 2%** | Serious issue for many TCP applications                               |
|      **5%+** | Usually very poor TCP performance                                     |

For something like downloading a large RHUI update or Docker image, even **0.5–1% loss can noticeably hurt throughput**, especially if RTT is high.

For example:

```text
Client ---- 70 ms RTT ---- Server

0% loss      -> potentially hundreds of Mbps
0.5% loss    -> TCP starts repeatedly reducing congestion window
1–2% loss    -> throughput can collapse dramatically
RTO events   -> pauses may become very obvious
```

So I would not say:

> "1% loss is acceptable."

For a properly functioning data-center or AWS network path, I would generally expect **very close to zero packet loss under normal conditions**.

---

# 2. How to quantify packet loss in Wireshark

A simple first approximation is:

```text
TCP loss rate ≈ Retransmitted TCP segments / Total TCP segments × 100
```

For example:

```text
Total TCP packets:      100,000
Retransmissions:            250

Loss estimate:

250 / 100,000 × 100
= 0.25%
```

That gives you an approximate retransmission percentage.

But I would call it:

> **TCP retransmission rate**

rather than absolute packet-loss percentage, because retransmissions and packet loss are not exactly the same thing.

---

# 3. Useful Wireshark filters

Start with a single TCP conversation if possible.

For example:

```wireshark
ip.addr == 10.1.10.20 && ip.addr == 10.50.20.30
```

Then look at all retransmissions:

```wireshark
tcp.analysis.retransmission
```

Fast retransmissions:

```wireshark
tcp.analysis.fast_retransmission
```

RTO-related retransmissions are typically included under:

```wireshark
tcp.analysis.retransmission
```

Wireshark may also label packets as:

```text
TCP Retransmission
TCP Fast Retransmission
TCP Spurious Retransmission
```

You can combine:

```wireshark
tcp.analysis.retransmission ||
tcp.analysis.fast_retransmission
```

I would also inspect:

```wireshark
tcp.analysis.duplicate_ack
```

and:

```wireshark
tcp.analysis.lost_segment
```

However, be careful with:

```wireshark
tcp.analysis.lost_segment
```

because Wireshark is saying:

> "Based on the sequence numbers I observed, something appears to be missing."

That missing packet could have been lost **by the capture itself**.

---

# 4. The better way: analyze one TCP stream

Suppose your problem is:

```text
EC2 Client
10.10.1.10

     |
     | downloading 2 GB Docker image
     |
     v

Registry
172.20.10.50
```

Find the stream:

```wireshark
tcp.stream eq 37
```

Then check:

```wireshark
tcp.stream eq 37 &&
tcp.analysis.retransmission
```

Now suppose Wireshark shows:

```text
Total packets in stream:       48,000
Retransmissions:                  220
Fast retransmissions:             175
RTO-style retransmissions:         45
```

Approximate retransmission rate:

```text
220 / 48,000 × 100
= 0.46%
```

That is enough that I would investigate it, particularly if the user says downloads are slow.

---

# 5. RTO is much more important than the raw percentage

Consider two captures.

### Capture A

```text
100,000 packets
500 retransmissions
0 RTOs
```

Retransmission rate:

```text
0.5%
```

### Capture B

```text
100,000 packets
100 retransmissions
20 RTOs
```

Retransmission rate:

```text
0.1%
```

Capture B may actually **feel worse to the application**.

Why?

A fast retransmission may recover relatively quickly:

```text
Packet 100
Packet 101
Packet 102     <- lost
Packet 103
Packet 104

Receiver:
ACK 102
ACK 102
ACK 102

Sender:
"I received several duplicate ACKs.
Packet 102 probably got lost."

Fast Retransmit 102
```

Recovery may happen within roughly an RTT.

But with an RTO:

```text
Sender sends packet
      |
      X packet/ACK disappears
      |
Sender waits...
      |
      | 200 ms
      | 400 ms
      | 800 ms ...
      |
RTO expires
      |
Retransmit
```

The TCP connection can essentially pause while waiting.

That is why repeated:

```text
TCP Retransmission
TCP Retransmission
TCP RTO
TCP RTO
```

is much more concerning than occasional isolated fast retransmissions.

---

# 6. What packet loss looks like in Wireshark

A classic loss sequence might look like:

```text
Client                         Server
  |                              |
  | Seq=1000 Len=1460 ---------->|
  | Seq=2460 Len=1460 ------X    |   LOSS
  | Seq=3920 Len=1460 ---------->|
  |                              |
  |<----------- ACK=2460         |
  |<----------- ACK=2460         | duplicate ACK
  |<----------- ACK=2460         | duplicate ACK
  |                              |
  | Seq=2460 Len=1460 ---------->| Fast Retransmission
  |                              |
  |<----------- ACK=5380         |
```

Wireshark may show:

```text
[TCP Dup ACK]
[TCP Dup ACK]
[TCP Dup ACK]
[TCP Fast Retransmission]
```

That is strong evidence of packet loss.

---

# 7. RTO-type loss looks different

You may see:

```text
Client                         Server

Seq=1000 --------------------->

          nothing comes back

          200 ms pause

Seq=1000 --------------------->   TCP Retransmission

          nothing

          400 ms pause

Seq=1000 --------------------->   TCP Retransmission
```

There may be no duplicate ACKs because the receiver did not receive enough subsequent packets to tell the sender what was missing.

That often produces:

```text
TCP Retransmission
TCP Retransmission
```

with large time gaps.

This is the kind of pattern that often explains:

> "Small download works, but large download freezes or becomes extremely slow."

---

# 8. Very important: determine which direction is losing packets

Don't simply count retransmissions.

Determine:

```text
Client → Server loss

versus

Server → Client loss
```

For a large file download:

```text
Client                 Server
  |                       |
  | GET ----------------->|
  |                       |
  |<==== lots of data ====|
```

Most data travels:

```text
Server → Client
```

If the server retransmits packets, one possibility is:

```text
Server → Client packet loss
```

But there is another possibility:

```text
Server → Client packet arrived

Client sends ACK
        X

ACK lost Client → Server

Server thinks data was lost
and retransmits it.
```

So seeing a server retransmission doesn't automatically tell you **which network direction is broken**.

---

# 9. This is why dual-sided capture is extremely valuable

Capture at:

```text
Server-side capture
        +
Client-side capture
```

Then compare sequence numbers.

For example:

### Server capture

```text
12:00:01.100
Server sends Seq=50000
```

### Client capture

If you see:

```text
12:00:01.170
Client receives Seq=50000
```

then the forward packet wasn't lost.

Now check the ACK.

Client:

```text
12:00:01.171
ACK=51460
```

Server capture:

```text
ACK never appears
```

Now you have strong evidence of:

```text
Client → Server ACK loss
```

instead of server-to-client data loss.

---

# 10. Capture loss can fool Wireshark

This matters a lot with high-speed captures.

Imagine:

```text
Actual network:

Packet 1
Packet 2
Packet 3
Packet 4
```

But your capture PC records:

```text
Packet 1
Packet 2
Packet 4
```

Wireshark may report:

```text
TCP Previous segment not captured
```

That doesn't mean the network dropped Packet 3.

It might mean:

```text
Network delivered packet
        |
NIC received packet
        |
capture buffer overflow
        X
Wireshark never recorded it
```

You should check:

```text
Capture → capture statistics
```

for dropped packets.

Also watch for offloading effects such as:

```text
TSO
GSO
GRO
LRO
```

when capturing directly on the endpoint.

---

# 11. A better metric than packet loss alone

When troubleshooting slow TCP, I usually look at five things together:

| Metric                       | What it tells you                     |
| ---------------------------- | ------------------------------------- |
| Retransmission %             | Likely loss/recovery frequency        |
| RTO count                    | Severe loss/recovery delays           |
| Duplicate ACKs               | Receiver identifying missing sequence |
| RTT                          | Network latency                       |
| TCP window / bytes in flight | Whether TCP is being throttled        |

For example:

```text
RTT:                    70 ms
Retransmission rate:   0.8%
RTO events:             34
Duplicate ACKs:        1,240
TCP throughput:        12 Mbps
Expected throughput:  200 Mbps
```

This is a very strong indication that packet loss is hurting TCP performance.

---

# 12. Wireshark Statistics you should use

For troubleshooting a particular problem, start with:

```text
Statistics
  → Conversations
  → TCP
```

Find the client/server flow.

You'll get:

```text
Address A
Address B
Packets A → B
Packets B → A
Bytes
Duration
Bits/s
```

Then filter that flow.

For example:

```wireshark
tcp.stream eq 12
```

Then:

```wireshark
tcp.stream eq 12 &&
tcp.analysis.retransmission
```

The displayed packet count gives you the retransmission count.

If the stream contains:

```text
20,000 packets
```

and retransmission filter shows:

```text
80 packets
```

then:

```text
80 / 20,000 × 100

= 0.4% retransmission rate
```

---

## How I would evaluate your capture

For a slow download, I would use this mental model:

```text
                  Slow TCP transfer
                         |
             +-----------+-----------+
             |                       |
          Packet loss              No loss
             |                       |
       +-----+-----+          +------+------+
       |           |          |             |
 Fast Retrans     RTO       Window       Application
       |           |       limitation       delay
 moderate       severe
 impact         impact
```

If your Wireshark capture shows **occasional isolated retransmissions**, I would not immediately blame the network.

If you see **clusters of duplicate ACKs + fast retransmissions**, you likely have real packet loss.

If you see **repeated RTO retransmissions with 200 ms / 400 ms / 800 ms-style pauses**, that is much more serious and is very likely to explain a slow or stalled download.

For your kind of AWS/network-performance troubleshooting, I would start investigating seriously once the retransmission rate is consistently around **0.5% or higher**, but I would pay even more attention to **any recurring RTOs**, because a small number of RTO events can hurt performance much more than the percentage alone.
