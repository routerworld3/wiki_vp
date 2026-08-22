

---

# Part 1: MSS Made Simple

## The one idea

MSS is a **receive** limit, not a send limit.

> When a host puts MSS in its SYN, it is saying:
> **"Don't send *me* anything bigger than this."**

It is not a negotiation. The two sides do **not** meet in the middle. Each number controls **the other side's sending**, and the two directions are independent.

## Your example

```
Client  ── SYN,     MSS = 1260 ──►  Server     "Don't send me over 1260"
Client  ◄── SYN/ACK, MSS = 1400 ──  Server     "Don't send me over 1400"
```

Read it by **crossing over**:

| Advertised by | Value | Controls |
|---|---|---|
| Client (1260) | 1260 | What the **Server** may send |
| Server (1400) | 1400 | What the **Client** may send |

**Simple answer:**

| Direction | Max segment |
|---|---|
| **Server → Client** | **1260 bytes** |
| **Client → Server** | **1400 bytes** |

## The one caveat

A host also can't exceed **its own MTU**, no matter what it's permitted to send.

> **What I actually send = smaller of (what you allowed me, what my own link can carry)**

A host's advertised MSS normally reveals its own MTU, so:

| Host | Says MSS | So its own MTU is | Its own send capability |
|---|---|---|---|
| Client | 1260 | 1300 | 1260 |
| Server | 1400 | 1440 | 1400 |

Apply the smaller-of rule:

| Direction | You allowed me | I'm capable of | **Real answer** |
|---|---|---|---|
| Server → Client | 1260 | 1400 | **1260** — *you* are the limit |
| Client → Server | 1400 | 1260 | **1260** — *I* am the limit |

So in practice **both directions run at 1260** — but for different reasons. The client is *allowed* 1400 and simply can't produce it.

⚠️ Don't shortcut this to "just take the minimum of the two." It happens to give the right number here. It gives the **wrong** number when a middlebox clamps the MSS in transit, because then the advertised value no longer reflects that host's real MTU, and the two directions become genuinely asymmetric.

## Two things that change the number in a real capture

**Options eat into MSS.** MSS is payload only. TCP timestamps consume 12 more bytes:

> 1260 − 12 = **1248 bytes** of actual payload

If your capture shows 1248 instead of 1260, nothing is broken.

**PMTUD can shrink it later.** MSS is fixed at handshake and never renegotiated, but an ICMP "Fragmentation Needed" mid-stream lowers the effective size. If those ICMPs are firewalled, you get a black hole: handshake works, small packets work, the connection dies the moment a full-size segment is sent.

---

# Part 2: How App Data Becomes Segments

## Short answer

**The OS kernel does the segmentation.** Not the app, not the NIC — with one important exception (offload) that I'll cover, because it's the reason your captures lie to you.

## The path

```
┌─────────────────────────────────────────────────────────┐
│ APPLICATION          write(fd, buffer, 1000000)         │
│                      "here's 1 MB, deal with it"        │
│                      Knows nothing about MSS or packets │
└──────────────────────────┬──────────────────────────────┘
                           │  copy into kernel memory
                           ▼
┌─────────────────────────────────────────────────────────┐
│ SOCKET SEND BUFFER   Kernel RAM. Byte stream. No        │
│                      packet boundaries exist yet.       │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ TCP LAYER (KERNEL)   ★ SEGMENTATION HAPPENS HERE ★      │
│                      Cuts the stream into ≤ MSS chunks  │
│                      Adds seq numbers, TCP header       │
│                      Decides how many to release, using │
│                      cwnd / rwnd / Nagle                │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ IP LAYER (KERNEL)    Adds IP header. Routing decision.  │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ NIC DRIVER / NIC     Adds Ethernet header, CRC.         │
│                      Puts bits on the wire.             │
│                      ✱ Unless TSO is on — see below     │
└─────────────────────────────────────────────────────────┘
```

## Who does what

| Layer | Role in segmentation |
|---|---|
| **Application** | **None.** Hands over a byte stream. Has no visibility into MSS, packets, or the wire. |
| **Socket buffer** | Just storage. Still a formless stream of bytes. |
| **TCP in the kernel** | **Does the cutting.** Chooses segment size and when to send. |
| **IP** | Wraps it. Only fragments if something already oversized slipped through — which shouldn't happen if MSS is right. |
| **NIC** | Normally just transmits. **With TSO enabled, it does the cutting instead.** |

## The consequence that matters for Wireshark

**There is no relationship between application writes and segments on the wire.**

| App does | Wire shows |
|---|---|
| One `write()` of 1 MB | ~800 segments of 1260 bytes |
| 100 × `write()` of 10 bytes | Possibly **one** segment of 1000 bytes (Nagle coalesced them) |
| One `write()` of 500 bytes | One segment of 500 bytes |

This is what "TCP is a byte stream, not a message protocol" actually means in practice. Never infer application behaviour from packet boundaries — a single HTTP response is not a single packet, and a single packet may contain two HTTP responses.

## What decides the size of each segment

TCP takes the **smallest** of:

1. **MSS** — the hard ceiling from the handshake
2. **How much data is sitting in the send buffer** — can't send what the app hasn't written
3. **Receive window** — what the peer says it can accept right now
4. **Congestion window** — what the sender thinks the network can absorb
5. **Nagle** — if there's unacked small data outstanding, hold small writes back and coalesce

So a segment smaller than MSS is **normal**, not a problem. It usually means the app just didn't have more to send at that instant.

## ✱ The offload exception — and why your capture looks wrong

Modern NICs support **TSO/GSO** (send side) and **LRO/GRO** (receive side). With these on, the kernel hands the NIC one giant 64 KB buffer and the **NIC** slices it into MSS-sized segments in hardware.

The problem: **Wireshark captures above the offload point.**

| What you see | What's actually on the wire | Why |
|---|---|---|
| `tcp.len == 64240` | 51 segments of 1260 | TSO — NIC hasn't cut it yet |
| Huge inbound packets | Many normal segments | GRO merged them before capture |
| "Checksum incorrect" everywhere | Checksums are fine | NIC computes them after capture |

**Disable offload before any capture you plan to analyse:**

```bash
ethtool -K eth0 tso off gso off lro off gro off      # Linux
Get-NetAdapterAdvancedProperty                        # Windows, then disable in NIC properties
```

Otherwise your segment sizes, retransmission counts, and interpacket timings are all fiction — and everything in the diagnosis-by-symptom work above becomes unreliable.

## Quick sanity filters

```
tcp.flags.syn == 1 && tcp.options.mss_val    # both advertisements, one screen
tcp.len == 1260                              # segments hitting the ceiling
tcp.len > 1460                               # offload is on — go fix it
tcp.analysis.push_bytes_sent                 # app-level message boundaries (PSH)
icmp.type == 3 && icmp.code == 4             # PMTUD shrinking things mid-stream
```

---

If you'd like, I can pull the MSS rules, the segmentation path, and the symptom/capture-point tables from all four of these answers into a single formatted reference document you can keep beside Wireshark.
