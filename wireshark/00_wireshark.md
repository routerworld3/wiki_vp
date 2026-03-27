# TCP Congestion Control & Send/Receive Windows

These are two separate but related mechanisms. Let me break them down clearly.

---

## The Core Idea First

TCP has to solve two problems:
- **Don't overwhelm the receiver** → Receive Window
- **Don't overwhelm the network** → Congestion Control (via Congestion Window)

How much data TCP can actually send at once is controlled by whichever of these is the *smaller* limit.

---

## Receive Window (rwnd)

This is the receiver telling the sender *"here's how much buffer space I have right now."*

Think of it like a parking lot. The receiver says: *"I have 64 spots available — don't send more than 64 cars until I tell you otherwise."*

- It's **advertised by the receiver** in every ACK packet
- It prevents the sender from overflowing the receiver's buffer
- Modern systems use **Window Scaling** to allow windows larger than 65,535 bytes (the old 16-bit limit)

```
Sender                          Receiver
  |  -------- data (10KB) ------->  |
  |  <-- ACK + rwnd=54KB --------   |   (receiver says "54KB of space left")
  |  -------- data (20KB) ------->  |
  |  <-- ACK + rwnd=34KB --------   |
```

---

## Congestion Window (cwnd)

This is the **sender's self-imposed limit** based on estimated network capacity. The receiver never sees this — it's entirely internal to the sender.

The sender doesn't *know* how much bandwidth the network has, so it has to **probe carefully**.

### The 4 Phases of TCP Congestion Control

**1. Slow Start**
- Starts small (1–10 segments)
- **Doubles** cwnd every RTT (round trip time)
- Despite the name, this grows very fast — exponentially
- Ends when cwnd hits the *slow start threshold (ssthresh)*

**2. Congestion Avoidance**
- Once past ssthresh, growth slows to **+1 MSS per RTT** (linear)
- Carefully probing for more bandwidth without causing congestion
- This is the normal steady state

**3. Packet Loss Detected (Congestion Signal)**

Two types of loss, two different reactions:

| Loss Type | Detection | Reaction |
|---|---|---|
| **3 duplicate ACKs** | Fast Retransmit | Cut cwnd by 50%, stay in Congestion Avoidance (TCP Reno/CUBIC) |
| **Timeout** | Timer expires | Brutal reset — cwnd back to 1, restart Slow Start |

**4. Fast Recovery**
- After 3 dup ACKs (not timeout), TCP retransmits the missing segment and reduces cwnd without going all the way back to Slow Start
- Keeps throughput higher than a full reset would

---

## How They Work Together

```
Actual send limit = min(cwnd, rwnd)
```

Example:
- rwnd = 128KB (receiver has plenty of buffer)
- cwnd = 32KB (network is the bottleneck right now)
- → TCP can only send **32KB** in flight at once

Or flip it:
- rwnd = 16KB (receiver is slow/busy)
- cwnd = 64KB (network is wide open)
- → TCP can only send **16KB** — the **receiver** is the bottleneck

---

## The Analogy That Ties It Together

Imagine you're shipping boxes to a warehouse across town via a highway:

- **rwnd** = how many boxes the warehouse loading dock can hold (receiver capacity)
- **cwnd** = how many trucks you dare put on the highway before it jams (network capacity)
- You ship `min(dock space, highway capacity)` at a time
- If trucks start crashing (packet loss), you pull back trucks from the highway (reduce cwnd)
- The warehouse never cares about highway congestion — it just keeps reporting its dock space



The key insight to remember: **rwnd is about the receiver, cwnd is about the network, and TCP always respects the smaller of the two.**

---

# ⚡ Wireshark “Pro Layout” (Copy This Exactly)

## 🔹 Core Columns (in this order)

| Order | Column Name | Field               | Why it matters  |
| ----- | ----------- | ------------------- | --------------- |
| 1     | No.         | frame.number        | Packet order    |
| 2     | Time        | frame.time_relative | Timing / delays |
| 3     | Source      | ip.src              | Direction       |
| 4     | Destination | ip.dst              | Direction       |
| 5     | Protocol    | *default*           | TCP/HTTP        |
| 6     | Length      | frame.len           | Packet size     |
| 7     | Info        | *default*           | Flags summary   |

---

## 🔥 TCP ANALYSIS COLUMNS (CRITICAL)

Add these — this is where the real debugging happens:

| Column Name         | Field                        | What it tells you  |
| ------------------- | ---------------------------- | ------------------ |
| **SEQ**             | tcp.seq                      | Data flow          |
| **ACK**             | tcp.ack                      | Acknowledgment     |
| **LEN**             | tcp.len                      | Payload size       |
| **WIN**             | tcp.window_size_value        | Receiver buffer    |
| **WIN (scaled)**    | tcp.window_size              | Real usable window |
| **Bytes in Flight** | tcp.analysis.bytes_in_flight | Sender pressure    |
| **RTT**             | tcp.analysis.ack_rtt         | Latency            |
| **Stream**          | tcp.stream                   | Identify flow      |

---

## 🚨 OPTIONAL (BUT VERY POWERFUL)

| Column Name     | Field                          | Use                 |
| --------------- | ------------------------------ | ------------------- |
| **TCP Flags**   | tcp.flags                      | SYN/FIN/RST quickly |
| **Dup ACK #**   | tcp.analysis.duplicate_ack_num | Loss detection      |
| **Window Full** | tcp.analysis.window_full       | Receiver bottleneck |
| **Zero Window** | tcp.analysis.zero_window       | Hard stop           |

---

# 🛠️ HOW TO ADD (FAST)

1. Open Wireshark
2. Right-click any column → **Column Preferences**
3. Click **+**
4. Add:

Example:

```text
Title: WIN
Type: Custom
Field: tcp.window_size_value
```

Repeat for each field above.

---

# 👀 HOW TO READ THIS (THE REAL VALUE)

## 🔎 Pattern 1 — Receiver Bottleneck (YOUR CASE)

| What you see             | Meaning               |
| ------------------------ | --------------------- |
| WIN small or not growing | Client buffer limited |
| WIN Full flagged         | Receiver slow         |
| Bytes in Flight drops    | Sender blocked        |

👉 **Conclusion:** Client/WAN issue

---

## 🔎 Pattern 2 — Packet Loss

| What you see              | Meaning         |
| ------------------------- | --------------- |
| Duplicate ACKs increasing | Missing packets |
| Bytes in Flight spikes    | Retransmissions |
| RTT jitter                | Congestion      |

👉 **Conclusion:** Network issue

---

## 🔎 Pattern 3 — MTU Issue

| What you see                          | Meaning         |
| ------------------------------------- | --------------- |
| Large LEN packets fail                | Fragmentation   |
| Retransmissions only on large packets | MTU mismatch    |
| MSS small in SYN                      | Path limitation |

👉 **Conclusion:** MTU / PMTU problem

---

## 🔎 Pattern 4 — Clean but Failed Transfer

| What you see      | Meaning            |
| ----------------- | ------------------ |
| FIN, ACK sequence | Clean close        |
| No RST            | Not crash          |
| Partial data      | App/client stopped |

👉 **Conclusion:** Not HAProxy

---

# ⚡ “ONE SCREEN VIEW” (WHAT YOU SHOULD SEE)

Ideal debugging screen:

```
Time | Src → Dst | SEQ | ACK | LEN | WIN | BytesInFlight | RTT | Info
```

👉 With this, you can visually spot:

* Window shrinking → receiver slow
* Bytes in flight stuck → backpressure
* RTT increasing → WAN issue
* Retransmissions → loss

---

# 🔥 PRO TIP (WHAT MOST PEOPLE MISS)

### Always compare:

👉 **Bytes in Flight vs Window**

```text
If BytesInFlight ≈ Window → sender is blocked
```

💡 That is EXACTLY your HAProxy behavior:

> “waiting on client receive window”

---

# 🚀 Minimal Version (if you want ultra-clean)

If you want just **8 columns that solve 95% of problems**:

```
Time
Source
Destination
SEQ
ACK
LEN
WIN (scaled)
RTT
```

---

# 🔥 Final Takeaway

With this layout, you can answer in **under 30 seconds**:

* Loss? → retrans / dup ACK
* Slow client? → window full
* WAN issue? → RTT + window
* MTU? → MSS + large packet behavior

---


---

# ⚡ 1. PRE-BUILT WIRESHARK PROFILE (MANUAL IMPORT STYLE)

Wireshark profiles are just folders, but fastest way = **build once manually**.

## 🔹 Create Profile

* Go to: **Edit → Configuration Profiles**
* Click **+**
* Name:

```text
TCP-TROUBLESHOOT-PRO
```

---

## 🔹 Columns (Copy Exactly)

Add these under **Preferences → Appearance → Columns**

```
No.                    frame.number
Time                   frame.time_relative
Source                 ip.src
Destination            ip.dst
Protocol               _default_
Length                 frame.len
Info                   _default_

SEQ                    tcp.seq
ACK                    tcp.ack
LEN                    tcp.len
WIN                    tcp.window_size_value
WIN_SCALED             tcp.window_size
Bytes_In_Flight        tcp.analysis.bytes_in_flight
RTT                    tcp.analysis.ack_rtt
Stream                 tcp.stream
```

---

## 🔹 Optional (Highly Recommended)

```
Dup_ACK                tcp.analysis.duplicate_ack_num
Window_Full            tcp.analysis.window_full
Zero_Window            tcp.analysis.zero_window
Flags                  tcp.flags
```

---

# 🎨 2. EXACT COLORING RULES (THIS IS THE MAGIC)

Go to:
**View → Coloring Rules → +**

Add these **IN THIS ORDER (priority matters)**

---

## 🔴 1. Retransmissions (CRITICAL)

```
Name: TCP Retransmission
Filter: tcp.analysis.retransmission || tcp.analysis.fast_retransmission
Color: Black text, Red background
```

👉 Means: **Packet loss**

---

## 🟠 2. Duplicate ACK

```
Name: Duplicate ACK
Filter: tcp.analysis.duplicate_ack
Color: Black text, Orange background
```

👉 Means: **Loss detection in progress**

---

## 🟡 3. Window Full (YOUR MOST IMPORTANT)

```
Name: Window Full
Filter: tcp.analysis.window_full
Color: Black text, Yellow background
```

👉 Means: **Receiver bottleneck**

---

## 🟣 4. Zero Window (SEVERE)

```
Name: Zero Window
Filter: tcp.analysis.zero_window
Color: White text, Purple background
```

👉 Means: **Receiver completely stalled**

---

## 🔵 5. SYN (Connection Start)

```
Name: SYN
Filter: tcp.flags.syn == 1 && tcp.flags.ack == 0
Color: Black text, Light Blue background
```

---

## 🟢 6. FIN (Clean Close)

```
Name: FIN
Filter: tcp.flags.fin == 1
Color: Black text, Light Green background
```

---

## ⚫ 7. RST (Abnormal)

```
Name: RST
Filter: tcp.flags.reset == 1
Color: White text, Black background
```

👉 Means: **Hard failure**

---

# 👀 WHAT YOU GET VISUALLY

When you open a capture:

* 🔴 Red → LOSS
* 🟡 Yellow → CLIENT SLOW
* 🟣 Purple → CLIENT DEAD STOP
* ⚫ Black → RESET / ERROR
* 🟢 Green → NORMAL CLOSE

👉 You can diagnose **without even reading packets**

---

# ⚡ 3. ONE-LINE TCPDUMP (SERVER SIDE PROOF)

This is what you use on **EC2 / Use case / Linux**

---

## 🔹 Capture with everything needed

```bash
sudo tcpdump -i any -nn -s 0 -w capture.pcap tcp
```

👉 Best for later Wireshark analysis

---

## 🔹 LIVE RTT + FLOW (SUPER USEFUL)

```bash
sudo tcpdump -i any -nn tcp and host <CLIENT_IP>
```

---

## 🔹 Show SYN / MSS (MTU check)

```bash
sudo tcpdump -i any -nn 'tcp[tcpflags] & tcp-syn != 0'
```

👉 Look for:

```text
mss 1460 / 1360 / 1200
```

---

## 🔹 Detect Retransmissions (quick CLI view)

```bash
sudo tcpdump -i any -nn 'tcp[tcpflags] & (tcp-syn|tcp-fin|tcp-rst) == 0'
```

👉 Watch for repeated seq numbers

---

## 🔹 Check Zero Window / Window behavior

```bash
sudo tcpdump -i any -nn -vv tcp | grep -i window
```

---

## 🔹 BEST ONE-LINER (YOUR USE CASE)

```bash
sudo tcpdump -i any -nn -tt tcp and host <CLIENT_IP> -vv
```

👉 Shows:

* seq / ack
* window
* timestamps

---

# 🔥 4. 30-SECOND SERVER-SIDE METHOD (NO WIRESHARK)

Run this:

```bash
ss -tmi
```

Look for:

| Field           | Meaning           |
| --------------- | ----------------- |
| `rtt:`          | latency           |
| `cwnd:`         | congestion window |
| `bytes_acked`   | throughput        |
| `send` / `recv` | buffer usage      |

---

### 🚨 KEY SIGNAL

```text
send-q high + recv-q low → receiver slow
```

👉 EXACTLY your Use case case

---

# 🧠 FINAL “INSTANT DIAGNOSIS” WORKFLOW

### Open capture → don’t think → just look:

1. 🔴 Red?
   → LOSS

2. 🟡 Yellow everywhere?
   → CLIENT SLOW (your case)

3. 🟣 Purple?
   → CLIENT STALLED

4. ⚫ Black (RST)?
   → HARD FAILURE

5. None of above?
   → Check RTT + MSS

---


---

