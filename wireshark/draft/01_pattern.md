# Wireshark Packet Loss Troubleshooting Guide

**Audience:** Network / systems engineers triaging "the network is slow" or "the transfer hangs" complaints.
**Goal:** Prove whether loss exists, where it is, and whether it is actually a network problem at all.

---

## 0. Before You Trust a Single Packet

Bad captures produce fake loss. Do these first, every time.

| Check | How | Why it matters |
|---|---|---|
| Capture drops | Statistics → Capture File Properties → *Dropped packets* | Dropped-by-capture looks identical to dropped-by-network |
| NIC offload | `ethtool -K eth0 gro off lro off tso off gso off` | TSO/GRO produce 20–60 KB "segments" and bogus out-of-order / checksum flags |
| Full handshake captured | Filter `tcp.flags.syn==1` | Without the SYN, Wireshark cannot learn the **window scale factor** and will report nonsense window sizes |
| Snaplen | `dumpcap -s 128` for pure TCP analysis | Prevents disk-bound capture drops on high-rate links |
| Capture tool | `dumpcap -b filesize:100000 -b files:20` | The Wireshark GUI is a poor capture engine; dissection while capturing causes drops |
| Clock | NTP-sync both endpoints | Required for meaningful dual-point correlation |

> **Rule:** If you see `[TCP ACKed unseen segment]` but **no retransmission anywhere in the file**, that is almost always a *capture* drop, not a *network* drop. Real network loss produces a recovery event.

### Capture point determines the answer

This is the single highest-value technique in the guide.

| Where you captured | You see original + retransmission | You see retransmission only |
|---|---|---|
| **Sender side** | Normal — tells you nothing about where loss was | (impossible) |
| **Receiver side** | Original arrived → the **ACK** was lost, or the retransmit was spurious/premature | **The data was lost upstream of this capture point** |

Capture on both ends simultaneously, filter on the same `tcp.stream`, and compare. Loss is between the point where a segment last appears and the point where it never appears. Repeat, bisecting the path, until you own the offending hop.

---

## 1. Fast Retransmit vs. RTO Retransmission

Both are "the sender sent that data again." They mean radically different things about path health and cost radically different amounts of throughput.

### Fast Retransmit (RFC 5681 / 6675)

The receiver got data *after* a hole, so it emits a duplicate ACK for every out-of-order segment that arrives. When the sender counts **3 duplicate ACKs** (dupthresh), it concludes the segment is gone and resends it immediately without waiting for any timer.

- **Trigger:** ACK-clock driven — feedback from the receiver.
- **Recovery latency:** ≈ 1 RTT.
- **Congestion response:** Fast Recovery. `ssthresh = cwnd/2`, `cwnd ≈ ssthresh`. Throughput dips, pipe stays open.
- **Precondition:** enough data in flight *behind* the loss to generate 3 dupACKs. It cannot help tail loss.
- **Meaning:** isolated, sporadic loss on a path that is otherwise passing traffic.

### RTO Retransmission (RFC 6298)

No usable ACK feedback arrived, so the retransmission timer fired.

- **Trigger:** timer expiry. `RTO = SRTT + max(G, 4 × RTTVAR)`, floored at 200 ms (Linux) / 300 ms (Windows); **1 s** for the initial SYN.
- **Recovery latency:** hundreds of ms to many seconds.
- **Congestion response:** brutal. `cwnd` collapses to 1 MSS (or IW), sender re-enters slow start.
- **Backoff:** RTO **doubles** on each successive failure — 200 ms → 400 → 800 → 1.6 s → 3.2 s…
- **Meaning:** the ACK clock broke. Causes: burst/tail loss, ACK-path loss, blackhole, path failure, receiver dead, firewall silently dropping.

### Side-by-side

| | Fast Retransmit | RTO Retransmission |
|---|---|---|
| Detected by | 3× DupACK / SACK | Timer expiry |
| Preceded by DupACKs | **Yes** | **No** (that's the tell) |
| Typical gap before resend | ~1 RTT (ms) | ≥ 200 ms, growing |
| cwnd after | Halved | 1 MSS, slow start |
| Throughput impact | Dip | Cliff |
| Repeats for same segment | Rarely | Often, with doubling intervals |
| Severity | Low–moderate | High |
| Wireshark field | `tcp.analysis.fast_retransmission` | `tcp.analysis.retransmission` + `tcp.analysis.rto` |

### How Wireshark actually decides (heuristics — not ground truth)

Wireshark is inferring, not reading the sender's mind:

1. Segment carries data at/below the highest byte already seen, **and** ≥2 dupACKs were seen in the reverse direction, **and** it arrived within **20 ms** of the last dupACK → **Fast Retransmission**.
2. Segment has a lower sequence than expected but arrives within ~3 ms of the preceding one with no dupACKs → **Out-Of-Order** (reordering, not loss).
3. The data was already cumulatively ACKed by the peer → **Spurious Retransmission**.
4. Otherwise → **Retransmission**, and Wireshark attaches `tcp.analysis.rto` = time since the original transmission.

Because these are heuristics, always sanity-check against IP ID, TTL, and the tcptrace graph before writing the ticket.

---

## 2. Quantifying Loss

### Core display filters

```
tcp.analysis.flags && !tcp.analysis.window_update     # all expert events, minus noise
tcp.analysis.retransmission                            # every resend
tcp.analysis.fast_retransmission                       # DupACK-driven
tcp.analysis.spurious_retransmission                   # original did arrive
tcp.analysis.out_of_order                              # reordering, NOT loss
tcp.analysis.duplicate_ack                             # any dupACK
tcp.analysis.duplicate_ack_num >= 3                    # enough to trigger fast retransmit
tcp.analysis.lost_segment                              # ACKed unseen segment
tcp.analysis.zero_window                               # receiver stalled
tcp.analysis.window_full                               # sender hit receiver's advertised window
tcp.analysis.rto > 1                                   # backed-off timer, severe
tcp.options.sack_le                                    # SACK blocks present
```

### Retransmission rate

```bash
# totals
tshark -r cap.pcap -q -z io,stat,0,"COUNT(tcp)tcp","COUNT(tcp.analysis.retransmission)tcp.analysis.retransmission","COUNT(tcp.analysis.fast_retransmission)tcp.analysis.fast_retransmission","COUNT(tcp.analysis.duplicate_ack)tcp.analysis.duplicate_ack","COUNT(tcp.analysis.zero_window)tcp.analysis.zero_window"

# per-second, to find the burst
tshark -r cap.pcap -q -z io,stat,1,"COUNT(tcp.analysis.retransmission)tcp.analysis.retransmission"

# expert summary and per-conversation view
tshark -r cap.pcap -q -z expert
tshark -r cap.pcap -q -z conv,tcp
```

Rough interpretation for bulk TCP transfer:

| Retransmit rate | Reading |
|---|---|
| < 0.1 % | Normal internet background |
| 0.1 – 1 % | Noticeable on long-fat pipes; investigate if throughput matters |
| 1 – 5 % | Users will complain |
| > 5 % | Broken path — chase hardware, duplex, buffers, wireless, policing |

Loss is **not** uniformly distributed. A 0.3 % average hiding a 40 % one-second burst is a very different fault than steady 0.3 %. Always look at the per-second graph.

### Visual tools

- **Statistics → TCP Stream Graphs → Time Sequence (tcptrace)** — retransmissions appear below the ACK line; stalls appear as flat segments; window exhaustion appears as the data line touching the upper window boundary.
- **Statistics → I/O Graph** — plot throughput and overlay `tcp.analysis.retransmission` as a second series. Correlate the throughput cliff with the loss burst.
- **Statistics → Conversations → TCP tab** — sort by bytes, find the stream that matters, right-click → Apply as Filter.

---

## 3. The Four Signatures

### Signature A — DupACK + Fast Retransmit = packet loss (recoverable)

**Filter**
```
tcp.analysis.duplicate_ack_num >= 3 || tcp.analysis.fast_retransmission
```

**What it looks like**
```
#1041  A→B  Seq=51001 Len=1460
#1042  A→B  Seq=52461 Len=1460      <-- this one dies in the path
#1043  A→B  Seq=53921 Len=1460
#1044  B→A  ACK=52461               [TCP Dup ACK]  SACK=53921-55381
#1045  B→A  ACK=52461               [TCP Dup ACK]
#1046  B→A  ACK=52461               [TCP Dup ACK]
#1047  A→B  Seq=52461 Len=1460      [TCP Fast Retransmission]
#1052  B→A  ACK=58301               ← hole filled, stream resumes
```

**Diagnosis:** genuine loss of an individual segment in the forward path. TCP recovered in about one RTT. Cause is usually congestion/tail-drop on a queue, a policer, a marginal link, or wireless.

**Confirm it's real loss, not reordering:**
- Reordering shows **1–2** dupACKs then an `[TCP Out-Of-Order]` frame — no retransmission needed.
- If the retransmit is flagged `[TCP Spurious Retransmission]`, the original *did* arrive; the sender fired early, or ACKs are being lost/delayed. Suspect ECMP/LAG path imbalance or an over-tight RTO.
- Compare IP ID and TTL between the original and the retransmit to be certain you're not looking at a SPAN-port duplicate.

**Impact:** modest. `cwnd` halves and recovers. On a long-RTT path even 0.5 % loss will cap throughput hard (Mathis: BW ≈ MSS / (RTT × √p)) — so quantify before you dismiss it.

---

### Signature B — Repeated RTO retransmission = severe loss

**Filter**
```
tcp.analysis.retransmission && !tcp.analysis.fast_retransmission
tcp.analysis.rto > 0.5
```

**What it looks like — note the doubling, and the absence of any DupACK**
```
10.000  A→B  Seq=90001 Len=1460
10.220  A→B  Seq=90001 Len=1460   [TCP Retransmission]  RTO=0.22
10.660  A→B  Seq=90001 Len=1460   [TCP Retransmission]  RTO=0.44
11.540  A→B  Seq=90001 Len=1460   [TCP Retransmission]  RTO=0.88
13.300  A→B  Seq=90001 Len=1460   [TCP Retransmission]  RTO=1.76
16.820  A→B  Seq=90001 Len=1460   [TCP Retransmission]  RTO=3.52
```

**Diagnosis:** the ACK clock is dead. Either a burst wiped out enough segments that no dupACKs could be generated, or nothing is getting through at all in one direction.

**Sub-cases to separate:**

| Observation | Meaning |
|---|---|
| Repeated RTO on **SYN** at 1 s, 3 s, 7 s, 15 s | Server unreachable or port silently filtered — this is a firewall/routing problem, not congestion |
| RTO on the **last** segments of a burst only | Tail loss — there was no following data to trigger dupACKs. Fixable with TLP/RACK on modern stacks |
| RTOs everywhere, throughout the stream | Real severe path loss, or a device dropping under load |
| Backoff runs to the stack limit, then RST or silent abandon | Path failure. Linux `tcp_retries2` default 15 ≈ 15+ minutes |
| RTOs that stop the instant segment size shrinks | **Not loss — go to Signature C** |

**Impact:** severe. Every RTO drives `cwnd` to 1 MSS and restarts slow start. A handful of RTOs will destroy throughput far more than hundreds of fast retransmits.

---

### Signature C — Large DF packets + missing ICMP = PMTU black hole

The most commonly misdiagnosed fault in this list. It *presents* as packet loss and *is* reported as retransmissions, but nothing is congested — a router needs to fragment, can't (DF set), sends ICMP Type 3 Code 4 "Fragmentation Needed," and **something drops that ICMP**. The sender never learns to shrink, so it retransmits the same oversized frame into the void forever.

**Classic user report:** "The connection establishes, small requests work, but large uploads/downloads hang." SSH logs in but `ls` of a big directory freezes. TLS handshake stalls at the certificate. HTTP GET of a small page fine, large page dead.

**Filters**
```
ip.flags.df == 1 && ip.len > 1400              # full-size DF packets
icmp.type == 3 && icmp.code == 4               # frag-needed — expect ZERO hits in a black hole
tcp.analysis.retransmission && tcp.len > 1000  # only the big ones are dying
tcp.options.mss_val                            # what each side negotiated at SYN
```

**Confirmation checklist**

1. Handshake and small segments succeed cleanly — no loss at all on packets under ~500 bytes.
2. Loss is **size-correlated**: sort by `tcp.len`; every retransmitted segment is at or near full MSS, every small segment is fine. Random congestion loss is *not* size-selective like this.
3. All retransmits are RTO-driven with exponential backoff and **zero DupACKs** (Signature B pattern) — because nothing after the hole ever arrives either.
4. **No ICMP Type 3 Code 4 in the capture.** If it *were* arriving, the sender would have adjusted within one RTT.
5. Receiver-side capture shows the large segments **never arriving at all**, while small ones do.
6. If the sender is Linux with `net.ipv4.tcp_mtu_probing=1`, watch for the segment to suddenly shrink (e.g. 1460 → 1400 → 1280) and then succeed. **That is a definitive confirmation of an MTU issue**, not congestion.

**Out-of-band proof**
```bash
# Linux — binary search the working payload size (add 28 for IP+ICMP headers)
ping -M do -s 1472 <dest>      # 1472 + 28 = 1500
ping -M do -s 1372 <dest>      # 1400 path
ping -M do -s 1272 <dest>      # 1280 — typical tunnel-safe floor

# Windows
ping -f -l 1472 <dest>

tracepath <dest>               # reports the PMTU and where it changes
```

**Usual root causes:** GRE / IPsec / VXLAN / WireGuard tunnel overhead, PPPoE (1492), a firewall or ACL blocking all ICMP, an MTU mismatch on one leg of a LAG or a VM overlay.

**Fixes:** stop filtering ICMP Type 3 Code 4 (the correct fix); or clamp MSS on the tunnel interface (`iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu` / `ip tcp adjust-mss 1360` on Cisco); or lower the endpoint MTU. Enabling `tcp_mtu_probing` is a workaround, not a fix.

---

### Signature D — Zero Window = receiver/application problem, not network loss

**Filters**
```
tcp.analysis.zero_window                       # receiver says "stop, my buffer is full"
tcp.analysis.zero_window_probe
tcp.analysis.window_update                     # receiver says "OK, resume"
tcp.analysis.window_full                       # sender has filled the advertised window
```

**What it looks like**
```
20.100  B→A  ACK=901441  Win=0        [TCP ZeroWindow]
20.400  A→B  Seq=901441  Len=1        [TCP ZeroWindowProbe]
20.400  B→A  ACK=901441  Win=0        [TCP ZeroWindowProbeAck]
21.200  A→B  Seq=901441  Len=1        [TCP ZeroWindowProbe]     ← backing off
...
26.900  B→A  ACK=901441  Win=65535    [TCP Window Update]       ← 6.8 s stall
```

**Diagnosis:** the receiving **application** is not draining its socket buffer. TCP is working perfectly and protecting it. There is **no loss**, no retransmission, no congestion. Look at the receiving host: pegged CPU, blocked disk I/O, GC pause, a single-threaded handler, a full application queue, a database lock, an undersized `SO_RCVBUF`.

**Measure the damage:** time-delta from the ZeroWindow frame to the Window Update. Set a time reference (Ctrl+T) on the ZeroWindow and read the delta. Sum those stall windows — that's your lost throughput, attributable entirely to the endpoint.

**Do not confuse these two:**

| Event | Sent by | Meaning |
|---|---|---|
| `[TCP ZeroWindow]` | **Receiver** | "My buffer is full. Stop sending." → receiving app is the bottleneck |
| `[TCP Window Full]` | **Sender** | "I've filled everything the receiver allowed." → sender is blocked, often just BDP/window-scaling tuning |

**Gotcha:** if your capture is missing the SYN, Wireshark doesn't know the window scale factor and will display raw, unscaled window values — a healthy 4 MB window can read as a tiny one. Confirm you captured the handshake before declaring a window problem.

**Also rule out** a simple BDP limit before blaming the app: if throughput ≈ advertised window ÷ RTT and the window never hits zero, you are window-limited, not loss-limited. Enable/raise window scaling.

---

## 4. Triage Decision Tree

```
Complaint: "slow / stalls / drops"
│
├─ Filter: tcp.analysis.flags && !tcp.analysis.window_update
│
├─ Nothing fires?
│   └─ Not a TCP loss problem. Check DNS, TLS, app latency, BDP/window limit, server think-time.
│
├─ tcp.analysis.zero_window present?
│   └─ SIGNATURE D → receiving host/application. Stop looking at the network.
│
├─ Retransmissions present — are they preceded by DupACKs?
│   │
│   ├─ YES (3+ DupACKs, resend within ~1 RTT)
│   │   └─ SIGNATURE A → real but recoverable path loss.
│   │       ├─ Retransmit flagged Spurious, or Out-Of-Order frames present?
│   │       │   └─ Reordering (ECMP/LAG) or premature RTO — not true loss.
│   │       └─ Quantify rate, find the per-second burst, bisect with dual captures.
│   │
│   └─ NO DupACKs, RTO with exponential backoff
│       └─ Is the loss size-correlated (only full-MSS DF segments die)
│          AND no ICMP type 3 code 4 anywhere?
│           ├─ YES → SIGNATURE C → PMTU black hole. Prove with ping -M do.
│           └─ NO  → SIGNATURE B → severe loss / path failure.
│                    ├─ On SYN only?     → firewall / routing / service down
│                    ├─ Tail of bursts?  → tail loss; enable TLP/RACK
│                    └─ Throughout?      → chase the path: interface errors,
│                                          duplex, buffers, policers, wireless
│
└─ Always: capture at both ends, compare, bisect toward the offending hop.
```

---

## 5. Field Notes

- **Fix RTOs before fast retransmits.** One RTO costs more throughput than fifty fast retransmits.
- **Loss rate alone is a weak metric.** Burstiness, RTT, and which direction the loss is in all matter more.
- **DupACK count without retransmission is reordering,** and reordering is often harmless — chasing it can waste days.
- **`[TCP ACKed unseen segment]` accuses your capture first,** the network second.
- **SACK is your friend:** `tcp.options.sack_le` / `sack_re` show exactly which byte ranges the receiver holds. The gap between the cumulative ACK and the first SACK left edge is the precise size of the hole.
- **Size-correlated loss is essentially always MTU.** Congestion does not preferentially discard large frames the way a DF-drop does.
- **Correlate with the hardware.** `show interface` counters (CRC, input drops, output drops, pause frames), queue-drop counters, and wireless retry rates should agree with your capture. If they don't, you're capturing in the wrong place.

---

## 6. Quick Reference Card

```
DupACK ×3  →  Fast Retransmit  →  loss, ~1 RTT recovery, cwnd halved      [MODERATE]
No DupACK  →  RTO ×N, doubling →  severe loss, cwnd = 1 MSS, slow start   [SEVERE]
Big DF pkts die, small pass, no ICMP 3/4  →  PMTU black hole              [MISCONFIG]
Win=0 + ZeroWindowProbe  →  receiving application stalled, NOT the network [ENDPOINT]
```
