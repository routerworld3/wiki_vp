

---

# 🔷 1. The Key Misconception

> **“TCP mode” ≠ “just pass packets blindly”**

Both F5 Networks BIG-IP and HAProxy can operate in TCP mode, but:

| Feature          | F5 (TCP profile) | HAProxy (TCP mode) |
| ---------------- | ---------------- | ------------------ |
| TCP termination  | ✅ Yes            | ✅ Yes              |
| TCP optimization | ✅ Advanced       | ❌ Minimal          |
| WAN optimization | ✅ Built-in       | ❌ None             |
| Buffer tuning    | Dynamic/adaptive | OS default         |
| Flow shaping     | Yes              | No                 |

👉 So both are “TCP proxies”
❗ But **F5 actively modifies TCP behavior**, HAProxy mostly does not.

---

# 🔷 2. What F5 “TCP WAN Profile” Actually Does

This is the missing piece.

F5 is NOT just forwarding TCP — it is **optimizing both sides independently**.

---

## 🟢 F5 splits the connection into TWO optimized legs

```text
Client (slow WAN) ⇄ F5 ⇄ Backend (fast AWS)
```

### Leg 1 (Client ↔ F5)

* Tuned for:

  * High RTT
  * Small buffers
  * Lossy WAN

### Leg 2 (F5 ↔ Backend)

* Tuned for:

  * Low RTT
  * High bandwidth
  * Large windows

---

## 🔥 Critical behavior

F5 does:

```text
Backend sends FAST → F5 buffers → F5 sends SLOW to client
```

👉 BUT it does it **intelligently and safely**

---

# 🔷 3. Why F5 Works but HAProxy Fails

## 🟢 With F5

```text
MinIO →→→ F5 →→ (smooth pacing) →→ Client
```

F5:

* Absorbs bursts
* Controls send rate
* Prevents buffer explosion
* Adjusts TCP windows dynamically

👉 Acts like a **shock absorber**

---

## 🔴 With HAProxy

```text
MinIO →→→ Envoy →→ HAProxy → (blocked) → Client
```

HAProxy:

* Relies on Linux TCP stack
* No WAN optimization
* No pacing intelligence

Envoy:

* Buffers aggressively (L7)

👉 Combined effect:

```text
FAST producer (MinIO)
→ buffered by Envoy
→ slow consumer (Client)
→ mismatch → failure
```

---

# 🔷 4. The REAL Difference (Packet-Level Behavior)

## 🟢 F5 behavior (simplified)

```text
Client rwnd ↓
→ F5 slows ACK pacing toward backend
→ Backend naturally slows
→ buffer stays stable
```

👉 F5 manipulates:

* ACK timing
* Window scaling
* Send rate

---

## 🔴 HAProxy behavior

```text
Client rwnd ↓
→ HAProxy stops sending
→ BUT Envoy keeps pulling from backend
→ buffer grows
```

👉 No feedback loop to backend

---

# 🔷 5. Why Your Failures Are “Rare but Large Files Fail”

This is classic **buffer accumulation problem**:

| File Size | Behavior                     |
| --------- | ---------------------------- |
| 10MB      | finishes before buffer issue |
| 100MB     | usually ok                   |
| 470MB+    | ❌ buffer builds up           |
| 3GB       | ❌ guaranteed failure         |

👉 Time-dependent failure

---

# 🔷 6. Where WAN Optimization Matters

F5 WAN profile typically includes:

* Larger TCP buffers
* Window scaling tuning
* Selective ACK optimization
* Packet pacing
* Nagle/delayed ACK tuning
* Loss recovery tuning

👉 These are **huge over high RTT paths**

---

# 🔷 7. Why RTT Alone Didn’t Explain Your Case

You observed:

> “RTT low but still failure”

Correct — because:

👉 This is NOT a latency problem
👉 This is a **rate mismatch + buffering problem**

---

# 🔷 8. The Hidden Factor: Envoy Makes It Worse

Even if HAProxy = F5 (it isn’t), you now also have:

```text
Envoy (HTTP proxy)
```

Which introduces:

* L7 buffering
* Independent flow control
* No TCP backpressure propagation

👉 This did NOT exist in your original F5 path (or behaved differently)

---

# 🔷 9. Simple Analogy

### 🟢 F5

> Smart valve with pressure regulation

### 🔴 HAProxy + Envoy

> Pipe + bucket

* Pipe (HAProxy) respects flow
* Bucket (Envoy) fills up
* Eventually spills (failure)

---

# 🔷 10. What Likely Changed in Your Migration

Even if architecture “looks same”, these changed:

### BEFORE

```text
Client → F5 (WAN optimized TCP) → NLB → MinIO
```

### AFTER

```text
Client → HAProxy (basic TCP) → NLB → Envoy → MinIO
```

👉 Two major differences:

1. ❌ Lost WAN optimization (F5 → HAProxy)
2. ❌ Added L7 buffering (Envoy)

---

# 🔷 11. Key Technical Root Cause

> **F5 slows the backend using TCP feedback — HAProxy + Envoy do not**

---

# 🔷 12. What You Can Do (Real Fix Options)

## 🔧 Option 1 — Closest to F5 behavior

* Remove Envoy from download path (for large objects)
* Keep pure TCP path

---

## 🔧 Option 2 — Tune Linux (HAProxy side)

Increase buffers:

```bash
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
```

---

## 🔧 Option 3 — MSS / MTU tuning (you already explored)

Ensure:

```text
MSS ≈ MTU - 40
```

---

## 🔧 Option 4 — Envoy tuning (critical)

Reduce buffering:

* `per_connection_buffer_limit_bytes`
* `initial_stream_window_size`
* `initial_connection_window_size`

---

## 🔧 Option 5 — Rate limiting upstream

Throttle MinIO or Envoy:

```text
Match client speed → avoid burst
```

---

# 🔷 13. Final Answer (Your Question)

> Why did F5 work but HAProxy fails if both are TCP mode?

### ✅ Answer:

> Because F5 is not just a TCP proxy — it is a **TCP optimization engine** that actively controls flow, while HAProxy relies on the OS TCP stack and does not perform WAN optimization. Combined with Envoy buffering, this creates a rate mismatch that leads to failure on large transfers.

---

# 🔷 14. One-Line Takeaway

> **F5 absorbs and regulates — HAProxy passes and relies — Envoy buffers and breaks flow**

---
Yes — but with one important caveat:

**You cannot fully mimic an F5 WAN profile with Linux sysctl alone.**
F5 does more than bigger buffers. It can change pacing behavior, ACK behavior, buffering strategy, loss recovery behavior, and per-leg TCP handling in ways plain Linux + HAProxy do not fully reproduce. So sysctl can make Linux **more WAN-friendly**, but it will not make HAProxy behave exactly like F5. ([Linux Kernel Documentation][1])

Below is a **safe “closest practical” Linux sysctl profile** for a HAProxy box serving **slow/high-RTT WAN clients** on the frontend and **fast/low-RTT backends** on the server side.

---

# Recommended sysctl profile with comments

Put this in a file such as:

```bash
/etc/sysctl.d/99-haproxy-wan.conf
```

```conf
########################################################################
# HAProxy WAN-friendly TCP tuning
# Goal:
#   - Larger TCP autotuned buffers for high-BDP / high-RTT clients
#   - Better tolerance for PMTU issues
#   - Keep SACK/window scaling enabled
#   - Avoid overly aggressive reset-to-slow-start after idle
#
# Caveat:
#   This does NOT fully replicate F5 WAN optimization behavior.
#   It only makes the Linux TCP stack more suitable for WAN clients.
########################################################################

############################
# Core socket buffer limits
############################

# Maximum OS receive buffer any socket can grow to.
# TCP autotuning cannot grow past this ceiling.
net.core.rmem_max = 16777216

# Maximum OS send buffer any socket can grow to.
net.core.wmem_max = 16777216


#########################################
# TCP autotuning min/default/max buffers
#########################################

# TCP receive buffer autotuning:
# min      = minimum per-socket receive buffer
# default  = starting/default autotuned value
# max      = largest autotuned receive buffer allowed
#
# Large max helps high-latency/high-bandwidth flows.
net.ipv4.tcp_rmem = 4096 262144 16777216

# TCP send buffer autotuning:
# min      = minimum per-socket send buffer
# default  = starting/default autotuned value
# max      = largest autotuned send buffer allowed
#
# Larger max helps HAProxy keep enough in flight on WAN legs.
net.ipv4.tcp_wmem = 4096 262144 16777216


#####################################################
# Enable/keep Linux receive-buffer autotuning active
#####################################################

# 1 = enabled (normally already enabled)
# Lets kernel dynamically size receive buffers up to tcp_rmem max.
net.ipv4.tcp_moderate_rcvbuf = 1


############################
# Memory pressure thresholds
############################

# TCP memory thresholds in pages, not bytes.
# Format: min pressure max
#
# These are global TCP memory thresholds.
# Leave generous but not absurd values.
# On many systems defaults are acceptable, but setting these avoids
# hitting low ceilings on smaller instances.
#
# Example below is a moderate increase; not a magic number.
net.ipv4.tcp_mem = 262144 524288 1048576


##########################################
# Keep TCP scaling / selective ACK enabled
##########################################

# Required for windows larger than 64 KB.
# Must stay enabled for high-BDP WAN flows.
net.ipv4.tcp_window_scaling = 1

# Selective ACK improves recovery from packet loss.
# Should stay enabled.
net.ipv4.tcp_sack = 1


###############################################
# Avoid unnecessary slow-start after idle time
###############################################

# 0 = do not cut congestion window just because the flow went idle
# Can help long-lived transfers that pause briefly.
net.ipv4.tcp_slow_start_after_idle = 0


#######################################
# Better behavior when PMTU is broken
#######################################

# 1 = enable TCP MTU probing only when black-hole is suspected
# Safer than forcing mode 2 in most environments.
# Helpful when ICMP frag-needed is blocked or path MTU is inconsistent.
net.ipv4.tcp_mtu_probing = 1

# Initial MSS used when MTU probing falls back.
# 1024 is a conservative value commonly used with probing.
net.ipv4.tcp_base_mss = 1024


#########################################
# Queue depth for bursts of new sessions
#########################################

# Maximum queued connection requests not yet accepted by app.
# Helps under bursts of new connections.
net.core.somaxconn = 65535

# SYN backlog for pending handshakes.
net.ipv4.tcp_max_syn_backlog = 8192


##################################
# Optional ephemeral port hygiene
##################################

# Broad ephemeral port range for many outbound connections.
net.ipv4.ip_local_port_range = 10240 65535


##################################################
# Keep timestamps enabled unless you have a reason
##################################################

# Helps RTT measurement and PAWS protection.
net.ipv4.tcp_timestamps = 1
```

---

# Apply it

```bash
sudo sysctl --system
```

Then verify:

```bash
sysctl net.core.rmem_max
sysctl net.core.wmem_max
sysctl net.ipv4.tcp_rmem
sysctl net.ipv4.tcp_wmem
sysctl net.ipv4.tcp_moderate_rcvbuf
sysctl net.ipv4.tcp_slow_start_after_idle
sysctl net.ipv4.tcp_mtu_probing
sysctl net.ipv4.tcp_sack
sysctl net.ipv4.tcp_window_scaling
```

The Linux kernel documents that `tcp_rmem` and `tcp_wmem` are min/default/max autotuning tuples, `tcp_moderate_rcvbuf` enables receive-buffer autotuning, `tcp_mtu_probing` controls Packetization-Layer PMTU discovery, and `tcp_slow_start_after_idle` controls whether TCP reduces congestion window after idle periods. ([Linux Kernel Documentation][1])

---

# What each one is really doing

## 1) `net.core.rmem_max` / `net.core.wmem_max`

These are the **OS ceilings** for socket receive/send buffers. If these stay small, your larger `tcp_rmem`/`tcp_wmem` max values are not very useful. Red Hat documents that TCP socket sizing depends on both the TCP tunables and the larger system socket limits. ([Red Hat Docs][2])

## 2) `net.ipv4.tcp_rmem` / `tcp_wmem`

These are **TCP autotuning ranges**, not fixed buffer sizes. The kernel can grow socket buffers dynamically as needed up to the max value. ([Linux Kernel Documentation][1])

## 3) `net.ipv4.tcp_mtu_probing`

This is helpful when PMTU discovery is partly broken or ICMP “fragmentation needed” messages are filtered. The kernel docs explicitly describe values `0`, `1`, and `2`, with `1` enabling probing when a black-hole is detected. ([Kernel][3])

## 4) `net.ipv4.tcp_sack`

Keep it on. Red Hat notes that disabling SACK reduces performance and increases retransmission inefficiency. ([Red Hat Docs][4])

## 5) `net.ipv4.tcp_slow_start_after_idle=0`

This can help flows that briefly stall and resume instead of repeatedly falling back too hard after idle. The setting is documented by the kernel. ([Linux Kernel Documentation][1])

---

# What I would **not** change first

I would avoid blindly changing these unless you have a specific reason:

* `tcp_low_latency`
* `tcp_no_metrics_save`
* `tcp_dsack`
* `tcp_retries2`
* `tcp_fin_timeout`
* `tcp_tw_reuse`

Those are often changed in random tuning guides, but they are usually **not** the root fix for your kind of large-download / slow-client issue.

---

# Practical interpretation for your case

If your path is:

```text
Client/WAN → HAProxy EC2 → NLB → Envoy → MinIO
```

this sysctl profile helps mainly on the **frontend TCP leg**:

```text
Client ⇄ HAProxy
```

It does **not** solve:

* Envoy buffering behavior
* application-layer stalls
* downstream proxy receive-window collapse
* middlebox issues beyond HAProxy
* asymmetric path weirdness
* PMTU problems that persist despite probing

So if you already “mimicked F5” and the issue remained, that actually fits the evidence: the problem is likely **not just HAProxy socket sizing**. It is more likely a combination of **slow downstream drain + HTTP/L7 buffering + WAN path behavior**, not simply missing Linux TCP buffers. ([Linux Kernel Documentation][1])

---

# Safer “lighter” version

If you want a more conservative profile first:

```conf
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.ipv4.tcp_rmem = 4096 262144 8388608
net.ipv4.tcp_wmem = 4096 262144 8388608
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = 1024
```

---

# recommendation

Use the commented profile above, but treat it as **supporting tuning**, not the root fix. If the issue persists after this, your next most valuable checks are:

1. packet capture on HAProxy during a failed transfer,
2. `ss -tmi` on the HAProxy frontend socket during failure,
3. Envoy per-connection / stream buffer limits,
4. proof of receive-window collapse or zero-window from the downstream side.


[1]: https://docs.kernel.org/networking/ip-sysctl.html?utm_source=chatgpt.com "IP Sysctl"
[2]: https://docs.redhat.com/en/documentation/red_hat_data_grid/7.2/html/performance_tuning_guide/networking_configuration?utm_source=chatgpt.com "Chapter 4. Networking Configuration"
[3]: https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt?utm_source=chatgpt.com "ip-sysctl.txt"
[4]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/pdf/network_troubleshooting_and_performance_tuning/Red_Hat_Enterprise_Linux-10-Network_troubleshooting_and_performance_tuning-en-US.pdf?utm_source=chatgpt.com "Network troubleshooting and performance tuning"

