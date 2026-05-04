# VPN Design Patterns

---

# 🧭 1. Generic Routing Encapsulation (GRE)

## 👉 Design Intent: “Make anything routable”

### 🧠 Why GRE exists

Native **IPsec** has limitations:

* Doesn’t support multicast (breaks routing protocols)
* Doesn’t carry non-IP traffic well
* Point-to-point mindset

👉 GRE solves this by:

> Wrapping packets inside another IP packet → acts like a virtual wire

---

## 🏗️ Design Use Case

```
Site A ───── GRE Tunnel ───── Site B
             (then secured by IPsec)
```

### When you choose GRE:

* You need **dynamic routing (OSPF/BGP/EIGRP) over VPN**
* You want **protocol transparency**
* You’re okay with:

  * Static topology
  * Manual scaling

---

## ⚖️ Design Tradeoffs

| Strength                   | Weakness                    |
| -------------------------- | --------------------------- |
| Supports routing protocols | Not encrypted (needs IPsec) |
| Simple concept             | Poor scalability            |
| Works everywhere           | Tunnel per peer             |

---

## 🧾 Designer Takeaway

> GRE is a **transport enabler**, not a scalable architecture.

---

# 🌐 2. Dynamic Multipoint VPN (DMVPN)

## 👉 Design Intent: “Scale hub-and-spoke without full mesh complexity”

---

## 🧠 Why DMVPN exists

Problem with GRE:

* For N sites → need N² tunnels (full mesh)
* Operational nightmare

👉 DMVPN solves:

> “Let’s build **one logical network**, and create tunnels only when needed”

---

## 🏗️ Design Model

```
        HUB
       / | \
      /  |  \
   Spoke Spoke Spoke
```

But dynamically becomes:

```
   Spoke A ───── Spoke B
        \        /
           HUB (control)
```

---

## 🔑 Key Design Concepts

* **NHRP (Next Hop Resolution Protocol)** → “ARP for tunnels”
* Dynamic tunnel creation
* Phases:

  * Phase 1 → Hub only
  * Phase 2 → Partial shortcut
  * Phase 3 → Full spoke-to-spoke

---

## 🎯 When you choose DMVPN

* Large number of branches
* Want:

  * Hub-and-spoke simplicity
  * With **on-demand spoke-to-spoke**

---

## ⚖️ Tradeoffs

| Strength                 | Weakness                 |
| ------------------------ | ------------------------ |
| Scales well              | Cisco proprietary        |
| Reduces tunnel count     | Operational complexity   |
| Supports dynamic routing | Harder to secure/inspect |

---

## 🧾 Designer Takeaway

> DMVPN is a **scalable overlay network** built on GRE + IPsec.

---

# 🔐 3. Cisco FlexVPN

## 👉 Design Intent: “Modern, standards-based VPN replacing DMVPN”

---

## 🧠 Why FlexVPN exists

DMVPN problems:

* Uses legacy protocols (NHRP, mGRE)
* Cisco-specific
* Hard to integrate multi-vendor

👉 FlexVPN solves:

> “Use **standards (IKEv2 + IPsec)** to achieve the same flexibility”

---

## 🏗️ Design Model

Same logical model as DMVPN:

```
        HUB (control plane)
       /   |    \
    Spoke Spoke Spoke
```

With dynamic shortcut:

```
   Spoke A ───── Spoke B
```

---

## 🔑 Key Design Concepts

* IKEv2-based
* Policy-driven tunnels
* Dynamic peer discovery
* Uses:

  * VTIs (Virtual Tunnel Interfaces)
  * Routing protocols (BGP preferred)

---

## 🎯 When you choose FlexVPN

* You want:

  * Modern architecture
  * Standards-based design
  * Multi-vendor compatibility
* Replacing DMVPN

---

## ⚖️ Tradeoffs

| Strength                  | Weakness                          |
| ------------------------- | --------------------------------- |
| Standards-based           | Still complex                     |
| Flexible (hub/spoke/mesh) | Requires strong design discipline |
| Better security model     | Less “plug-and-play” than DMVPN   |

---

## 🧾 Designer Takeaway

> FlexVPN is **“DMVPN done right” using modern standards**

---

# 🧠 Putting It All Together (Design View)

| Feature         | GRE             | DMVPN  | FlexVPN     |
| --------------- | --------------- | ------ | ----------- |
| Encryption      | ❌ (needs IPsec) | ✅      | ✅           |
| Routing support | ✅               | ✅      | ✅           |
| Scalability     | ❌ Low           | ✅ High | ✅ High      |
| Spoke-to-spoke  | ❌               | ✅      | ✅           |
| Standards-based | ✅               | ❌      | ✅           |
| Complexity      | Low             | Medium | Medium-High |

---

# 🏗️ Real-World Design Thinking (Your Level)

## If you’re designing today:

### 🟢 Use GRE when:

* Simple site-to-site
* Lab/testing
* Controlled environment

---

### 🟡 Use DMVPN when:

* Existing Cisco-heavy environment
* Legacy deployments
* Need quick scalable solution

---

### 🔵 Use FlexVPN when:

* New design
* Multi-cloud / hybrid
* Multi-vendor
* Security-focused architecture

---


# 🧾 Final Designer Summary

* **GRE** → “Make routing work over tunnels”
* **DMVPN** → “Scale hub-and-spoke dynamically”
* **FlexVPN** → “Do DMVPN using modern standards”


