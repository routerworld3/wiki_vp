

```text
Client (WAN) → HAProxy (TCP) → AWS NLB → Istio/Envoy → MinIO
```

---

# 🔷 1. First — Break the Path into TCP Segments

This is the **most important mental model**:

```text
[ TCP #1 ]  Client ⇄ HAProxy
[ TCP #2 ]  HAProxy ⇄ NLB ⇄ Envoy
[ TCP #3 ]  Envoy ⇄ MinIO
```

👉 Each one has:

* Its **own congestion window (cwnd)**
* Its **own receive window (rwnd)**
* Its **own RTT**

🚨 **These are NOT shared end-to-end**

---

# 🔷 2. What Happens in a GOOD Transfer (Packet Flow)

## 🟢 Step-by-step

### 🔹 Leg 3: MinIO → Envoy (FAST, AWS internal)

```text
MinIO sends data fast
→ TCP window large
→ High throughput (Gbps)
```

Envoy receives quickly:

```text
[DATA][DATA][DATA][DATA]
ACKs immediately
```

---

### 🔹 Leg 2: Envoy → HAProxy (still fast)

Envoy forwards:

```text
HTTP/2 DATA frames → TCP packets → HAProxy
```

Still:

* Low RTT
* No bottleneck

---

### 🔹 Leg 1: HAProxy → Client (WAN)

Now:

```text
HAProxy sends → Client
Client ACKs → reasonably fast
```

So:

* `rwnd` stays open
* HAProxy keeps sending
* Flow is smooth

---

# 🔷 3. What Happens in FAILURE Case (Your Scenario)

Now let’s replay with **slow WAN / constrained client**

---

## 🔴 Step 1: Client Becomes Slow

Client side:

```text
Small receive buffer OR slow network
→ Advertised window shrinks
```

Packet-level:

```text
Client → ACK (rwnd = small)
Client → ACK (rwnd = 0)   ← 🚨 ZERO WINDOW
```

---

## 🔴 Step 2: HAProxy Reaction (TCP Mode — GOOD behavior)

HAProxy sees:

```text
rwnd = 0 → STOP sending
```

So:

```text
HAProxy send buffer fills slowly
→ but respects client speed
```

👉 This is correct TCP backpressure

---

## 🔴 Step 3: Envoy Behavior (THIS IS THE BREAK POINT)

Envoy is **NOT a TCP proxy** — it is HTTP/1.1 proxy

So instead of:

```text
Client slow → propagate slowdown to MinIO
```

It does:

```text
MinIO → Envoy → BUFFER → HAProxy (slow drain)
```

---

### 📦 Packet-level view inside Envoy

#### From MinIO:

```text
[DATA][DATA][DATA][DATA][DATA]  (FAST)
```

#### Envoy buffers:

```text
Memory buffer grows:
[██████████████████████████]
```

#### Toward HAProxy:

```text
Small writes (because HAProxy blocked by client)
```

---

## 🔴 Step 4: Buffer Explosion

Now:

| Segment          | Behavior  |
| ---------------- | --------- |
| MinIO → Envoy    | FAST      |
| Envoy → HAProxy  | SLOW      |
| HAProxy → Client | VERY SLOW |

So:

```text
Incoming rate  >> Outgoing rate
```

👉 Envoy buffer keeps growing

---

## 🔴 Step 5: Failure Trigger

Eventually one happens:

### ❌ Case A: Envoy buffer limit hit

```text
Envoy resets stream
```

### ❌ Case B: Timeout

```text
Upstream or downstream timeout
```

### ❌ Case C: Client closes cleanly

```text
Client gives up → sends FIN
```

---

## 🔴 Step 6: Why HAProxy Shows `term=--`

This is your key observation:

```text
term=--  (clean FIN both sides)
```

Because:

* Client closed cleanly
* Envoy closed cleanly
* HAProxy just relayed FIN

👉 From HAProxy perspective:
✔ No timeout
✔ No RST
✔ Looks normal

But:

🚨 **Application failed (partial file)**

---

# 🔷 4. Packet-Level Timeline (Simplified)

## 🟢 Good Case

```text
MinIO →→→ Envoy →→→ HAProxy →→→ Client
        (balanced flow rates)
```

---

## 🔴 Failure Case

```text
MinIO →→→→→ Envoy →→ (buffering) → HAProxy → (blocked) → Client
          ↑
          buffer grows
          ↑
      eventually reset / close
```

---

# 🔷 5. Where Exactly the Problem Lives

### ✅ NOT here:

* NLB (L4 pass-through)
* HAProxy (TCP correct behavior)
* MinIO (sending fine)

### 🔥 PROBLEM HERE:

```text
Envoy (HTTP proxy, L7)
```

Because it:

* Terminates TCP
* Breaks end-to-end flow control
* Buffers aggressively

---

# 🔷 6. Why This Did NOT Happen with F5

Your old path:

```text
Client → F5 → NLB → MinIO
```

If F5 was in TCP mode:

```text
Client slow → F5 slows → MinIO slows
```

👉 True backpressure end-to-end

---

# 🔷 7. Key Metrics That Match Your Observations

From your data:

| Metric                   | Failure Meaning               |
| ------------------------ | ----------------------------- |
| Low RTT but failure      | Not network latency issue     |
| `rcv_space` small        | Client bottleneck             |
| `bytes_retrans` moderate | Not main issue                |
| `term=--`                | Clean close (client gave up)  |
| Large file fails only    | Buffer accumulation over time |

---

# 🔷 8. Root Cause (One Line)

> **HTTP proxy (Envoy) decouples TCP flow → causes buffer buildup when client is slower than backend**

---

# 🔷 9. Fix Options (Practical)

## 🔧 Option 1 (Best for your case)

👉 Use **TCP mode / passthrough**

* HAProxy TCP (already good)
* Avoid HTTP proxy in path for large downloads

---

## 🔧 Option 2

Tune Envoy:

* `per_connection_buffer_limit_bytes`
* `stream_idle_timeout`
* `max_connection_duration`
* disable buffering where possible

---

## 🔧 Option 3

Limit upstream speed:

```text
MinIO throttling OR Envoy rate limiting
```

---

## 🔧 Option 4

Client-side fix:

* Increase receive buffer
* Improve WAN path

---

# 🔷 10. Final Mental Model (VERY IMPORTANT)

### ✅ TCP Proxy Path (Works)

```text
Client slow → entire chain slows → stable
```

### ❌ HTTP Proxy Path (Your issue)

```text
Client slow → Envoy buffers → overflow → failure
```

---

# 🔷 11. Final Summary (Short)

* You have **3 independent TCP connections**
* Backpressure stops at Envoy
* Envoy buffers instead of slowing backend
* Large files amplify mismatch → failure
* HAProxy logs look clean because failure is upstream

---


