# EKS VPC CNI — Clearing the Confusion

## The root of the confusion: "primary" means two different things

The word **primary** appears in two completely separate contexts. Mixing them up is why this feels confusing.

| Term | What it means | Scope |
|---|---|---|
| **Primary ENI** | The first network card of the EC2 instance (eth0). One per node. Cannot be detached. | One per **node** |
| **Primary IP (of an ENI)** | The first IP address on any given ENI. Every ENI has one. | One per **ENI** |

So a node with 3 ENIs has:
- **1 Primary ENI** (the first network card)
- **2 Secondary ENIs** (the additional network cards)
- **3 Primary IPs total** — one on each ENI (each ENI has its own primary IP)

This is the single most important thing to internalize. Let's draw it.

---

## Part 1 — Anatomy of one EC2 node (m5.large example)

An m5.large can attach **up to 3 ENIs**. Each ENI can hold **up to 10 IP addresses**. Let me show you what those IPs are actually called.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 520" width="720">
  <!-- Node frame -->
  <rect x="20" y="20" width="680" height="480" rx="12"
        fill="#f9f8f5" stroke="#b4b2a9" stroke-width="1.5"/>
  <text x="40" y="46" font-family="sans-serif" font-size="15"
        font-weight="600" fill="#2c2c2a">One EC2 m5.large node</text>
  <text x="40" y="66" font-family="sans-serif" font-size="11" fill="#888780">
    subnet: 10.0.1.0/24 · max 3 ENIs · max 10 IPs per ENI
  </text>

  <!-- PRIMARY ENI box -->
  <rect x="40" y="90" width="200" height="390" rx="10"
        fill="#e6f1fb" stroke="#0c447c" stroke-width="2"/>
  <text x="140" y="114" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#0c447c">PRIMARY ENI</text>
  <text x="140" y="130" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#185fa5">(eth0 — the first network card)</text>
  <text x="140" y="146" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#185fa5">cannot be detached</text>

  <!-- IP slot 1: Primary IP of Primary ENI = NODE IP -->
  <rect x="55" y="160" width="170" height="60" rx="6"
        fill="#fcebeb" stroke="#a32d2d" stroke-width="2"/>
  <text x="140" y="178" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#501313">PRIMARY IP</text>
  <text x="140" y="194" text-anchor="middle" font-family="sans-serif"
        font-size="12" font-weight="600" fill="#501313">10.0.1.10</text>
  <text x="140" y="212" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#a32d2d">= THE NODE IP (kubelet, SSH)</text>

  <!-- Secondary IPs -->
  <rect x="55" y="228" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="140" y="242" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">Secondary IP: 10.0.1.11</text>
  <rect x="55" y="251" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="140" y="265" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">Secondary IP: 10.0.1.12</text>
  <rect x="55" y="274" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="140" y="288" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">Secondary IP: 10.0.1.13</text>
  <rect x="55" y="297" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="140" y="311" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">Secondary IP: 10.0.1.14</text>
  <text x="140" y="332" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#888780">... up to 9 secondary IPs</text>
  <text x="140" y="348" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#888780">(10 slots − 1 primary)</text>

  <rect x="55" y="365" width="170" height="100" rx="6"
        fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1.5"/>
  <text x="140" y="385" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#04342c">Primary IP → NODE</text>
  <text x="140" y="402" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#04342c">Secondary IPs → PODS</text>
  <text x="140" y="426" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">9 pod IPs from this ENI</text>
  <text x="140" y="442" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">(in DEFAULT mode)</text>

  <!-- SECONDARY ENI 1 -->
  <rect x="255" y="90" width="200" height="390" rx="10"
        fill="#faeeda" stroke="#854f0b" stroke-width="2"/>
  <text x="355" y="114" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#633806">SECONDARY ENI #1</text>
  <text x="355" y="130" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">(eth1 — added by CNI when needed)</text>

  <!-- Primary IP of Secondary ENI -->
  <rect x="270" y="160" width="170" height="60" rx="6"
        fill="#fcebeb" stroke="#a32d2d" stroke-width="2"/>
  <text x="355" y="178" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#501313">PRIMARY IP</text>
  <text x="355" y="194" text-anchor="middle" font-family="sans-serif"
        font-size="12" font-weight="600" fill="#501313">10.0.1.20</text>
  <text x="355" y="212" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#a32d2d">NOT used by anyone — wasted slot</text>

  <!-- Secondary IPs -->
  <rect x="270" y="228" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="355" y="242" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">Secondary IP: 10.0.1.21</text>
  <rect x="270" y="251" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="355" y="265" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">Secondary IP: 10.0.1.22</text>
  <rect x="270" y="274" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="355" y="288" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">Secondary IP: 10.0.1.23</text>
  <text x="355" y="332" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#888780">... up to 9 secondary IPs</text>

  <rect x="270" y="365" width="170" height="100" rx="6"
        fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1.5"/>
  <text x="355" y="385" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#04342c">Primary IP → WASTED</text>
  <text x="355" y="402" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#04342c">Secondary IPs → PODS</text>
  <text x="355" y="426" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">9 pod IPs from this ENI</text>
  <text x="355" y="442" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">(in DEFAULT mode)</text>

  <!-- SECONDARY ENI 2 -->
  <rect x="470" y="90" width="210" height="390" rx="10"
        fill="#faeeda" stroke="#854f0b" stroke-width="2"/>
  <text x="575" y="114" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#633806">SECONDARY ENI #2</text>
  <text x="575" y="130" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">(eth2 — added by CNI when needed)</text>

  <rect x="485" y="160" width="180" height="60" rx="6"
        fill="#fcebeb" stroke="#a32d2d" stroke-width="2"/>
  <text x="575" y="178" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#501313">PRIMARY IP</text>
  <text x="575" y="194" text-anchor="middle" font-family="sans-serif"
        font-size="12" font-weight="600" fill="#501313">10.0.1.30</text>
  <text x="575" y="212" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#a32d2d">NOT used by anyone — wasted slot</text>

  <text x="575" y="288" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#888780">(secondary IPs</text>
  <text x="575" y="304" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#888780">go to pods)</text>

  <rect x="485" y="365" width="180" height="100" rx="6"
        fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1.5"/>
  <text x="575" y="385" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#04342c">Primary IP → WASTED</text>
  <text x="575" y="402" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#04342c">Secondary IPs → PODS</text>
  <text x="575" y="426" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">9 pod IPs from this ENI</text>
  <text x="575" y="442" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">(in DEFAULT mode)</text>
</svg>
```

### Read this diagram carefully — it answers your question directly

**Yes, the node uses the Primary IP** — but specifically **only one** Primary IP: the one on the Primary ENI.

Look at the boxes:

| ENI | Primary IP | Who uses Primary IP? | Secondary IPs |
|---|---|---|---|
| **Primary ENI** | 10.0.1.10 | **THE NODE** (kubelet, SSH, image pulls) | Given to pods |
| **Secondary ENI #1** | 10.0.1.20 | **Nobody** — wasted slot | Given to pods |
| **Secondary ENI #2** | 10.0.1.30 | **Nobody** — wasted slot | Given to pods |

**Why are the secondary ENIs' primary IPs "wasted"?** Because AWS requires every ENI to have a primary IP for the ENI itself to exist on the network — but only the node actually uses one of them. The other two primary IPs just sit there, doing nothing, but still counting against your IP slots.

---

## Part 2 — So how many pods can fit? (the math, finally)

For an m5.large with default VPC CNI:

```
Total IP slots = 3 ENIs × 10 IPs per ENI = 30 IP slots

Wasted on ENI primary IPs = 3 (one per ENI)
                              ↑
                              Of these 3:
                              • 1 is also the node IP (Primary ENI's primary IP)
                              • 2 are pure waste (Secondary ENIs' primary IPs)

Available for pods = 30 − 3 = 27 pod IPs

Then the CNI reserves a bit more for itself, so AWS publishes a "max pods = 29" 
for m5.large (the actual calculator does slightly different bookkeeping, but the 
principle — every ENI burns one slot — is correct).
```

**The key insight:** the more ENIs you add for more capacity, the more primary-IP slots you waste. There's no way around it in default mode. This is exactly the inefficiency prefix delegation fixes.

---

## Part 3 — The two completely different problems

Before talking about the solutions, let me state the two problems as cleanly as I can. They are not the same problem.

### Problem A — "Density problem"

> **My node has spare CPU and memory, but I can't schedule more pods on it because it ran out of IPs.**

This happens because AWS limits how many IPs each ENI can hold, and each ENI wastes one slot on its primary IP. On m5.large you get only 27 pod slots — but the node could comfortably run 40+ small pods if only it had more IPs.

**You are wasting compute. Not VPC IP space.**

### Problem B — "Address-space problem"

> **My VPC subnet is too small to hold all the pod IPs I need across my whole fleet.**

This happens when companies have a small slice of corporate IP space (say, a `/22` = 1024 IPs). After ~30 nodes, you've burned the whole `/22` and you can't add more nodes — not because the nodes are full, but because the *VPC subnet* is full.

**You are wasting nodes. Not compute per node.**

### Side-by-side

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 400" width="720">
  <!-- Problem A -->
  <rect x="20" y="20" width="330" height="360" rx="12"
        fill="#fff" stroke="#ef9f27" stroke-width="2"/>
  <text x="185" y="48" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#633806">PROBLEM A — Density</text>

  <text x="40" y="80" font-family="sans-serif" font-size="12" font-weight="600" fill="#412402">Symptom:</text>
  <text x="40" y="100" font-family="sans-serif" font-size="11" fill="#444">Node has 60% free CPU and RAM</text>
  <text x="40" y="118" font-family="sans-serif" font-size="11" fill="#444">but cannot schedule more pods</text>

  <text x="40" y="148" font-family="sans-serif" font-size="12" font-weight="600" fill="#412402">Where's the bottleneck?</text>
  <text x="40" y="168" font-family="sans-serif" font-size="11" fill="#444">Inside ONE node — IPs per ENI</text>

  <text x="40" y="198" font-family="sans-serif" font-size="12" font-weight="600" fill="#412402">VPC has lots of free IPs?</text>
  <text x="40" y="218" font-family="sans-serif" font-size="11" fill="#444">Yes — tons of space available</text>

  <text x="40" y="248" font-family="sans-serif" font-size="12" font-weight="600" fill="#412402">What's wasted?</text>
  <text x="40" y="268" font-family="sans-serif" font-size="11" fill="#444">CPU and RAM on each node</text>

  <text x="40" y="298" font-family="sans-serif" font-size="12" font-weight="600" fill="#412402">Fix:</text>
  <text x="40" y="318" font-family="sans-serif" font-size="11" font-weight="600" fill="#633806">PREFIX DELEGATION</text>
  <text x="40" y="336" font-family="sans-serif" font-size="11" fill="#854f0b">Pack more IPs into each ENI slot</text>

  <!-- Problem B -->
  <rect x="370" y="20" width="330" height="360" rx="12"
        fill="#fff" stroke="#85b7eb" stroke-width="2"/>
  <text x="535" y="48" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#0c447c">PROBLEM B — Address space</text>

  <text x="390" y="80" font-family="sans-serif" font-size="12" font-weight="600" fill="#04254a">Symptom:</text>
  <text x="390" y="100" font-family="sans-serif" font-size="11" fill="#444">Whole VPC subnet is out of IPs</text>
  <text x="390" y="118" font-family="sans-serif" font-size="11" fill="#444">cannot launch any more nodes</text>

  <text x="390" y="148" font-family="sans-serif" font-size="12" font-weight="600" fill="#04254a">Where's the bottleneck?</text>
  <text x="390" y="168" font-family="sans-serif" font-size="11" fill="#444">The whole VPC subnet CIDR</text>

  <text x="390" y="198" font-family="sans-serif" font-size="12" font-weight="600" fill="#04254a">Individual nodes are full?</text>
  <text x="390" y="218" font-family="sans-serif" font-size="11" fill="#444">No — they could hold more pods</text>

  <text x="390" y="248" font-family="sans-serif" font-size="12" font-weight="600" fill="#04254a">What's wasted?</text>
  <text x="390" y="268" font-family="sans-serif" font-size="11" fill="#444">Nothing — you literally can't grow</text>

  <text x="390" y="298" font-family="sans-serif" font-size="12" font-weight="600" fill="#04254a">Fix:</text>
  <text x="390" y="318" font-family="sans-serif" font-size="11" font-weight="600" fill="#0c447c">CUSTOM NETWORKING</text>
  <text x="390" y="336" font-family="sans-serif" font-size="11" fill="#185fa5">Put pod IPs in a non-routable CIDR</text>
</svg>
```

Now let's look at each solution in detail.

---

## Part 4 — Custom Networking explained from scratch

You said you understand this, but let me restate it precisely so it lines up with the new vocabulary.

**What it does:** Pod IPs no longer come from the node's subnet. They come from a **completely different subnet** in a **secondary VPC CIDR** (typically `100.64.0.0/16` from the CGNAT range).

### How the ENIs change

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 460" width="720">
  <rect x="20" y="20" width="680" height="420" rx="12"
        fill="#f9f8f5" stroke="#b4b2a9" stroke-width="1.5"/>
  <text x="40" y="46" font-family="sans-serif" font-size="15"
        font-weight="600" fill="#2c2c2a">m5.large with CUSTOM NETWORKING</text>
  <text x="40" y="66" font-family="sans-serif" font-size="11" fill="#888780">
    primary subnet: 10.0.1.0/24 · secondary subnet: 100.64.0.0/24
  </text>

  <!-- PRIMARY ENI - in primary subnet -->
  <rect x="40" y="90" width="200" height="330" rx="10"
        fill="#e6f1fb" stroke="#0c447c" stroke-width="2"/>
  <text x="140" y="114" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#0c447c">PRIMARY ENI</text>
  <text x="140" y="130" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#185fa5">subnet: 10.0.1.0/24</text>
  <text x="140" y="146" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#185fa5">(primary/routable subnet)</text>

  <rect x="55" y="160" width="170" height="60" rx="6"
        fill="#fcebeb" stroke="#a32d2d" stroke-width="2"/>
  <text x="140" y="178" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#501313">PRIMARY IP</text>
  <text x="140" y="194" text-anchor="middle" font-family="sans-serif"
        font-size="12" font-weight="600" fill="#501313">10.0.1.10</text>
  <text x="140" y="212" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#a32d2d">THE NODE IP (kubelet, SSH)</text>

  <rect x="55" y="234" width="170" height="80" rx="6"
        fill="#f0ede8" stroke="#b4b2a9" stroke-width="1" stroke-dasharray="4 3"/>
  <text x="140" y="254" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#888780">Secondary IPs HERE:</text>
  <text x="140" y="276" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#888780">NOT USED</text>
  <text x="140" y="296" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#888780">(pods won't come from</text>
  <text x="140" y="310" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#888780">primary subnet at all)</text>

  <rect x="55" y="335" width="170" height="75" rx="6"
        fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1.5"/>
  <text x="140" y="354" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#04342c">Used for:</text>
  <text x="140" y="372" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">• Node IP only</text>
  <text x="140" y="388" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">• SNAT for outbound pod traffic</text>
  <text x="140" y="404" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">• 0 pod IPs!</text>

  <!-- SECONDARY ENI 1 - in secondary subnet -->
  <rect x="255" y="90" width="200" height="330" rx="10"
        fill="#faeeda" stroke="#854f0b" stroke-width="2"/>
  <text x="355" y="114" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#633806">SECONDARY ENI #1</text>
  <text x="355" y="130" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">subnet: 100.64.0.0/24</text>
  <text x="355" y="146" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">(CGNAT secondary subnet)</text>

  <rect x="270" y="160" width="170" height="60" rx="6"
        fill="#fcebeb" stroke="#a32d2d" stroke-width="2"/>
  <text x="355" y="178" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#501313">PRIMARY IP</text>
  <text x="355" y="194" text-anchor="middle" font-family="sans-serif"
        font-size="12" font-weight="600" fill="#501313">100.64.0.10</text>
  <text x="355" y="212" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#a32d2d">wasted slot (ENI requirement)</text>

  <rect x="270" y="228" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="355" y="242" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">100.64.0.11 → Pod 1</text>
  <rect x="270" y="251" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="355" y="265" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">100.64.0.12 → Pod 2</text>
  <rect x="270" y="274" width="170" height="20" rx="3" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="355" y="288" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#26215c">100.64.0.13 → Pod 3</text>
  <text x="355" y="316" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#888780">... 9 pod IPs total</text>

  <rect x="270" y="335" width="170" height="75" rx="6"
        fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1.5"/>
  <text x="355" y="354" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#04342c">9 pod IPs from CGNAT</text>
  <text x="355" y="372" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">pod IPs don't touch</text>
  <text x="355" y="388" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#085041">your corporate /22</text>

  <!-- SECONDARY ENI 2 - in secondary subnet -->
  <rect x="470" y="90" width="210" height="330" rx="10"
        fill="#faeeda" stroke="#854f0b" stroke-width="2"/>
  <text x="575" y="114" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#633806">SECONDARY ENI #2</text>
  <text x="575" y="130" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">subnet: 100.64.0.0/24</text>
  <text x="575" y="146" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">(CGNAT secondary subnet)</text>

  <rect x="485" y="160" width="180" height="60" rx="6"
        fill="#fcebeb" stroke="#a32d2d" stroke-width="2"/>
  <text x="575" y="178" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#501313">PRIMARY IP</text>
  <text x="575" y="194" text-anchor="middle" font-family="sans-serif"
        font-size="12" font-weight="600" fill="#501313">100.64.0.20</text>
  <text x="575" y="212" text-anchor="middle" font-family="sans-serif"
        font-size="10" fill="#a32d2d">wasted slot</text>

  <text x="575" y="278" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#888780">9 secondary IPs</text>
  <text x="575" y="296" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#888780">→ pods (100.64.0.x)</text>

  <rect x="485" y="335" width="180" height="75" rx="6"
        fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1.5"/>
  <text x="575" y="354" text-anchor="middle" font-family="sans-serif"
        font-size="11" font-weight="700" fill="#04342c">9 pod IPs from CGNAT</text>
</svg>
```

### What changed?

| | Default | Custom Networking |
|---|---|---|
| **Primary ENI's primary IP** | Node IP | Node IP (same) |
| **Primary ENI's secondary IPs** | Used for pods | **Not used for pods** |
| **Secondary ENIs** | In same subnet as Primary ENI | **In a different, secondary subnet** |
| **Where do pod IPs come from?** | Primary subnet (10.0.1.0/24) | Secondary subnet (100.64.0.0/24) |

### So your specific question: does the node still use its Primary IP?

**Yes — completely unchanged.** The Primary ENI is still there, its Primary IP is still 10.0.1.10, and the node still uses it for kubelet, SSH, container image pulls, and outbound pod traffic (via SNAT). Custom networking does NOT change anything about the Primary ENI's role for the node.

What changes: the Primary ENI **stops sharing its secondary IPs with pods**. Pods only get IPs from the new Secondary ENIs in the 100.64.0.0/16 subnet.

### Pod density cost

Look at the diagram — you now get pods from 2 ENIs instead of 3. So:

```
Default mode:           3 ENIs × 9 pod IPs = 27 pods
Custom networking:      2 ENIs × 9 pod IPs = 18 pods (you lost ~9 slots!)
```

This is the painful tradeoff custom networking forces on you — and exactly what prefix delegation fixes.

---

## Part 5 — Prefix Delegation explained from scratch

The core idea, restated as simply as possible:

> **An "IP slot" on an ENI doesn't have to hold just 1 IP. With prefix delegation, each slot holds 16 IPs.**

Same number of ENIs. Same number of slots per ENI. But now each slot is a `/28` (16 IPs) instead of one IP.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 420" width="720">
  <!-- DEFAULT MODE -->
  <text x="180" y="30" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#0c447c">DEFAULT MODE</text>
  <text x="180" y="48" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#185fa5">1 slot = 1 IP</text>

  <rect x="40" y="60" width="280" height="340" rx="10"
        fill="#e6f1fb" stroke="#85b7eb" stroke-width="1.5"/>
  <text x="180" y="84" text-anchor="middle" font-family="sans-serif"
        font-size="12" font-weight="600" fill="#0c447c">One ENI on m5.large</text>

  <rect x="55" y="95" width="250" height="22" rx="4" fill="#fcebeb" stroke="#a32d2d" stroke-width="1.5"/>
  <text x="180" y="110" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#501313">Slot 0: Primary IP (ENI itself)</text>

  <rect x="55" y="121" width="250" height="22" rx="4" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="180" y="136" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#26215c">Slot 1: 10.0.1.11 → 1 pod IP</text>
  <rect x="55" y="147" width="250" height="22" rx="4" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="180" y="162" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#26215c">Slot 2: 10.0.1.12 → 1 pod IP</text>
  <rect x="55" y="173" width="250" height="22" rx="4" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="180" y="188" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#26215c">Slot 3: 10.0.1.13 → 1 pod IP</text>
  <rect x="55" y="199" width="250" height="22" rx="4" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="180" y="214" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#26215c">Slot 4: 10.0.1.14 → 1 pod IP</text>
  <text x="180" y="248" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#888780">... slots 5–9 ...</text>

  <rect x="55" y="270" width="250" height="50" rx="6" fill="#fff8e6" stroke="#c8954c" stroke-width="1.5"/>
  <text x="180" y="288" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="700" fill="#5b3e0e">9 pod IPs per ENI</text>
  <text x="180" y="306" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#5b3e0e">3 ENIs → 27 pod IPs total</text>

  <rect x="55" y="335" width="250" height="50" rx="6" fill="#fcebeb" stroke="#f09595" stroke-width="1.5"/>
  <text x="180" y="358" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="700" fill="#501313">Cap: ~29 pods/node</text>

  <!-- PREFIX MODE -->
  <text x="540" y="30" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="700" fill="#633806">PREFIX DELEGATION</text>
  <text x="540" y="48" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">1 slot = 1 prefix (/28 = 16 IPs)</text>

  <rect x="400" y="60" width="280" height="340" rx="10"
        fill="#faeeda" stroke="#ef9f27" stroke-width="1.5"/>
  <text x="540" y="84" text-anchor="middle" font-family="sans-serif"
        font-size="12" font-weight="600" fill="#633806">Same ENI, same 10 slots</text>

  <rect x="415" y="95" width="250" height="22" rx="4" fill="#fcebeb" stroke="#a32d2d" stroke-width="1.5"/>
  <text x="540" y="110" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#501313">Slot 0: Primary IP (ENI itself)</text>

  <rect x="415" y="121" width="250" height="22" rx="4" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="540" y="136" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#412402">Slot 1: 10.0.1.16/28 → 16 IPs</text>
  <rect x="415" y="147" width="250" height="22" rx="4" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="540" y="162" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#412402">Slot 2: 10.0.1.32/28 → 16 IPs</text>
  <rect x="415" y="173" width="250" height="22" rx="4" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="540" y="188" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#412402">Slot 3: 10.0.1.48/28 → 16 IPs</text>
  <rect x="415" y="199" width="250" height="22" rx="4" fill="#eeedfe" stroke="#afa9ec"/>
  <text x="540" y="214" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#412402">Slot 4: 10.0.1.64/28 → 16 IPs</text>
  <text x="540" y="248" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#888780">... slots 5–9 ...</text>

  <rect x="415" y="270" width="250" height="50" rx="6" fill="#fff8e6" stroke="#c8954c" stroke-width="1.5"/>
  <text x="540" y="288" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="700" fill="#5b3e0e">144 pod IPs per ENI</text>
  <text x="540" y="306" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#5b3e0e">3 ENIs → 432 pod IPs total</text>

  <rect x="415" y="335" width="250" height="50" rx="6" fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1.5"/>
  <text x="540" y="358" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="700" fill="#04342c">Cap: 110 pods/node</text>
</svg>
```

### Why this fixes the density problem

Look at what's the same and what changed:

| | Default | Prefix Delegation |
|---|---|---|
| ENI count | 3 | 3 (same!) |
| Slots per ENI | 10 | 10 (same!) |
| Primary IP per ENI | Yes | Yes (same!) |
| What's in each secondary slot | 1 IP | **16 IPs (a `/28` prefix)** |
| Pod IPs per ENI | 9 | **144** |

The ENI hardware limits didn't change. AWS didn't give you more ENIs or more slots. They just let you **stuff 16 IPs into each slot**.

### Walk-through: how a pod gets an IP with prefix delegation

A fresh m5.large node boots. A pod gets scheduled. Here's what happens:

1. **kubelet** asks the VPC CNI for an IP.
2. **CNI** has no IPs in its warm pool yet. It calls `AssignPrivateIpAddresses` on the Primary ENI with `Ipv4PrefixCount: 1`.
3. **EC2** allocates a contiguous `/28` from the subnet — say `10.0.1.32/28`. That's IPs `10.0.1.32` through `10.0.1.47` (16 addresses).
4. **CNI** gives the pod the first IP in the prefix: `10.0.1.32`.
5. **Pod 2 schedules.** CNI hands out `10.0.1.33` from the same prefix — **no EC2 API call needed**.
6. **Pods 3–16 schedule.** Each gets the next IP from the prefix. Still no EC2 API calls.
7. **Pod 17 schedules.** The prefix is exhausted. CNI requests another `/28`, gets `10.0.1.48/28`, and continues.

### The hidden cost: IP waste

That `/28` is **always 16 IPs at a time**. If your node only ever runs 3 pods, you've reserved 16 IPs from the subnet and 13 are sitting idle. If you run many small nodes, this fragments your subnet fast.

This is exactly why prefix delegation is often paired with **custom networking + CGNAT**: in CGNAT space you have so many IPs that the waste doesn't matter.

---

## Part 6 — Why the two are commonly combined

Now you can see why people use them together. Each fixes the OTHER's downside:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 440" width="720">
  <!-- Custom Networking alone -->
  <rect x="20" y="20" width="200" height="180" rx="10"
        fill="#e6f1fb" stroke="#85b7eb" stroke-width="1.5"/>
  <text x="120" y="48" text-anchor="middle" font-family="sans-serif"
        font-size="13" font-weight="700" fill="#0c447c">Custom Networking</text>
  <text x="120" y="72" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#04342c">✓ Saves primary IPs</text>
  <text x="120" y="92" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#085041">pods in CGNAT 100.64.x</text>
  <text x="120" y="124" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#501313">✗ Loses density</text>
  <text x="120" y="144" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#a32d2d">27 → 18 pods/node</text>
  <text x="120" y="164" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#a32d2d">(Primary ENI no longer</text>
  <text x="120" y="180" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#a32d2d">used for pods)</text>

  <!-- Prefix Delegation alone -->
  <rect x="500" y="20" width="200" height="180" rx="10"
        fill="#faeeda" stroke="#ef9f27" stroke-width="1.5"/>
  <text x="600" y="48" text-anchor="middle" font-family="sans-serif"
        font-size="13" font-weight="700" fill="#633806">Prefix Delegation</text>
  <text x="600" y="72" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#04342c">✓ Boosts density</text>
  <text x="600" y="92" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#085041">27 → 110 pods/node</text>
  <text x="600" y="124" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#501313">✗ Burns subnet IPs fast</text>
  <text x="600" y="144" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#a32d2d">16 IPs at a time per node</text>
  <text x="600" y="164" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#a32d2d">/24 subnet exhausted</text>
  <text x="600" y="180" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#a32d2d">in 16 nodes</text>

  <!-- Arrows -->
  <path d="M 220 100 Q 360 130 360 220" fill="none" stroke="#5dcaa5" stroke-width="2"/>
  <path d="M 500 100 Q 360 130 360 220" fill="none" stroke="#5dcaa5" stroke-width="2"/>

  <text x="245" y="155" font-family="sans-serif" font-size="10" font-weight="600" fill="#085041">density</text>
  <text x="245" y="170" font-family="sans-serif" font-size="10" font-weight="600" fill="#085041">problem</text>
  <text x="245" y="185" font-family="sans-serif" font-size="10" font-weight="600" fill="#085041">fixed by →</text>

  <text x="425" y="155" font-family="sans-serif" font-size="10" font-weight="600" fill="#085041">IP waste</text>
  <text x="425" y="170" font-family="sans-serif" font-size="10" font-weight="600" fill="#085041">problem</text>
  <text x="425" y="185" font-family="sans-serif" font-size="10" font-weight="600" fill="#085041">← fixed by</text>

  <!-- Combined -->
  <rect x="180" y="225" width="360" height="200" rx="10"
        fill="#e1f5ee" stroke="#04342c" stroke-width="2"/>
  <text x="360" y="252" text-anchor="middle" font-family="sans-serif"
        font-size="15" font-weight="700" fill="#04342c">Custom Networking + Prefix Delegation</text>
  <text x="360" y="272" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#085041">the production sweet spot</text>

  <text x="200" y="306" font-family="sans-serif" font-size="11" font-weight="600" fill="#04342c">✓ Pod IPs live in 100.64.0.0/16</text>
  <text x="200" y="322" font-family="sans-serif" font-size="10" fill="#085041">   → primary VPC CIDR stays clean for nodes</text>

  <text x="200" y="346" font-family="sans-serif" font-size="11" font-weight="600" fill="#04342c">✓ Each ENI slot holds a /28 (16 IPs)</text>
  <text x="200" y="362" font-family="sans-serif" font-size="10" fill="#085041">   → 110 pods/node restored</text>

  <text x="200" y="386" font-family="sans-serif" font-size="11" font-weight="600" fill="#04342c">✓ CGNAT has tons of space</text>
  <text x="200" y="402" font-family="sans-serif" font-size="10" fill="#085041">   → /28 IP waste doesn't matter</text>
</svg>
```

---

## Part 7 — Final summary table

Pin this somewhere — it's the whole story:

| Question | Default | Custom Networking | Prefix Delegation | Both |
|---|---|---|---|---|
| Where does **node IP** come from? | Primary subnet | Primary subnet | Primary subnet | Primary subnet |
| Where do **pod IPs** come from? | Primary subnet | Secondary subnet (CGNAT) | Primary subnet | Secondary subnet (CGNAT) |
| Does Primary ENI serve pods? | Yes | **No** | Yes | **No** |
| Pod IPs per ENI slot | 1 | 1 | **16** | **16** |
| Max pods on m5.large | ~29 | ~20 | 110 | 110 |
| **Fixes which problem?** | — | Address space | Density | Both |

---

## Part 8 — Three rules to remember

1. **Every ENI has exactly one Primary IP.** That Primary IP is required for the ENI to exist on the network. Only the **Primary ENI's Primary IP** is also used as the node IP. Secondary ENIs' Primary IPs are wasted — they exist because AWS requires them.

2. **Custom Networking changes where pod IPs come from, not where the node IP comes from.** The node IP is *always* the Primary ENI's Primary IP — that never changes regardless of which mode you use.

3. **Prefix Delegation changes what fits in each secondary IP slot.** Instead of one IP per slot, you get 16. Same ENI count, same slot count — just denser packing.
