
---

## Critical Finding From the Envoy Docs Relevant to Your Case

The default stream idle timeout is 5 minutes. This timeout is strongly recommended for all requests as it additionally defends against a peer that does not open the stream window once an entire response has been buffered to be sent to a downstream client.

This is **exactly your failure mode**. Your ss output showed the connection frozen for 243 seconds. The stream idle timeout controls how long an individual HTTP stream can sit with no data before being closed. For HTTP/1.1, this is the same as the connection idle timeout since each connection handles one stream at a time.

At 243 seconds of silence, the default 5-minute (300 second) stream idle timeout was 57 seconds away from firing and killing your transfer.

Also critically relevant from the edge proxy docs: the default settings are tailored for the service mesh use case, and some values need to be adjusted when using Envoy as an edge proxy — including the HTTP/2 initial connection window size limit to 1 MiB. Your default HTTP/2 window of 64KB is well below this recommended 1MiB.

---

## Get Current Envoy Config — Complete Cheatsheet

```bash
# ── STEP 1: Find your ingress gateway pod ──────────────────────────────────
# One command to get the pod name regardless of namespace
INGRESS_POD=$(kubectl get pod --all-namespaces \
  -l app=istio-ingressgateway \
  -o jsonpath='{.items[0].metadata.name}')

INGRESS_NS=$(kubectl get pod --all-namespaces \
  -l app=istio-ingressgateway \
  -o jsonpath='{.items[0].metadata.namespace}')

echo "Pod: $INGRESS_POD  Namespace: $INGRESS_NS"

# ── STEP 2: Dump complete Envoy config to file ────────────────────────────
# Full config dump — everything Envoy knows about itself
kubectl exec -n $INGRESS_NS $INGRESS_POD -- \
  curl -s http://localhost:15000/config_dump \
  > /tmp/envoy_config_full.json

echo "Config saved — $(wc -l < /tmp/envoy_config_full.json) lines"

# ── STEP 3: Check stream idle timeout — your most critical setting ────────
# Default is 300s (5 min) — fires 57s after your 243s stall snapshot
# Should be 3600s or higher for large file transfers
grep -o '"stream_idle_timeout":"[^"]*"' /tmp/envoy_config_full.json | \
  sort -u
# If no output → default 300s is being used — NOT set explicitly

# ── STEP 4: Check route timeout — kills transfer if set too short ─────────
# Default is 15 seconds — MUST be disabled (0s) for large file downloads
grep -o '"timeout":"[^"]*"' /tmp/envoy_config_full.json | \
  sort -u | head -20
# 15s default will kill any transfer taking more than 15s

# ── STEP 5: Check HTTP/2 window sizes — your rwnd_limited root cause ──────
# Default stream window = 65536 bytes (64KB) — far too small
# Should be 1048576 (1MB) per Envoy edge proxy best practices
grep -oE '"initial_stream_window_size":[0-9]+' /tmp/envoy_config_full.json | \
  sort -u
grep -oE '"initial_connection_window_size":[0-9]+' /tmp/envoy_config_full.json | \
  sort -u
# No output = default 64KB stream / 1MB connection being used

# ── STEP 6: Check per_connection_buffer_limit_bytes ──────────────────────
# Controls how much data Envoy buffers per connection
# Default 1MB — may be too small for large file transfers
grep -oE '"per_connection_buffer_limit_bytes":[0-9]+' /tmp/envoy_config_full.json | \
  sort -u

# ── STEP 7: Check connection idle timeout ────────────────────────────────
# How long a connection with no active streams stays alive
# Default 1 hour — usually fine but verify
grep -o '"idle_timeout":"[^"]*"' /tmp/envoy_config_full.json | \
  sort -u | head -10

# ── STEP 8: Check max connection duration ────────────────────────────────
# Default unlimited (0) — if set too short will kill long transfers
grep -o '"max_connection_duration":"[^"]*"' /tmp/envoy_config_full.json | \
  sort -u

# ── STEP 9: Check what protocol Envoy uses toward MinIO ──────────────────
# http1 = HTTP/1.1 (susceptible to write timeout on backpressure)
# http2 = HTTP/2 (handles backpressure gracefully with flow control)
kubectl exec -n $INGRESS_NS $INGRESS_POD -- \
  curl -s http://localhost:15000/clusters | \
  grep -E "minio|somecompany|library" | \
  grep -oE "http[12]|h2" | sort -u

# ── STEP 10: Check current active stats during a transfer ─────────────────
# upstream_rq_active = requests currently in flight to MinIO
kubectl exec -n $INGRESS_NS $INGRESS_POD -- \
  curl -s http://localhost:15000/stats | \
  grep -E "upstream_rq_active|upstream_cx_active|upstream_rq_timeout|upstream_rq_rx_reset"

# ── STEP 11: Check UPE error count accumulated ───────────────────────────
# upstream_rq_rx_reset = total upstream resets received (your UPE source)
kubectl exec -n $INGRESS_NS $INGRESS_POD -- \
  curl -s http://localhost:15000/stats | \
  grep "upstream_rq_rx_reset\|upstream_reset"

# ── STEP 12: Check all applied EnvoyFilters and DestinationRules ─────────
# Shows what customizations are already in place
kubectl get envoyfilter --all-namespaces
kubectl get destinationrule --all-namespaces
kubectl get virtualservice --all-namespaces | grep -iE "minio|library|somecompany"
```

---

## Interpret What You Find

```bash
# After running the above — compare against these expected values

# stream_idle_timeout
# Found: "300s" or missing  → BAD  — will fire during your 243s stall
# Should be: "3600s"        → GOOD — gives 1 hour for slow clients

# route timeout
# Found: "15s"              → BAD  — kills any transfer over 15 seconds
# Found: "0s"               → GOOD — disabled for streaming
# Should be: "0s" or "3600s"

# initial_stream_window_size
# Found: 65536              → BAD  — 64KB fills in 48ms at 41Mbps
# Should be: 1048576        → GOOD — 1MB per Envoy edge best practices
# Should be: 4194304        → BETTER — 4MB for very slow clients

# per_connection_buffer_limit_bytes
# Found: 1048576 (1MB)      → may be limiting — increase to 32MB
# Should be: 33554432       → 32MB for large file transfers

# protocol toward MinIO
# Found: http1              → BAD  — no flow control, write timeout risk
# Should be: http2          → GOOD — graceful flow control via WINDOW_UPDATE
```

---

## One Command Summary — Paste This and Share Output

```bash
# Run this single block and share the output
# It shows everything relevant in one go

INGRESS_POD=$(kubectl get pod --all-namespaces \
  -l app=istio-ingressgateway \
  -o jsonpath='{.items[0].metadata.name}')
INGRESS_NS=$(kubectl get pod --all-namespaces \
  -l app=istio-ingressgateway \
  -o jsonpath='{.items[0].metadata.namespace}')

echo "=== Pod: $INGRESS_POD / Namespace: $INGRESS_NS ==="

kubectl exec -n $INGRESS_NS $INGRESS_POD -- \
  curl -s http://localhost:15000/config_dump > /tmp/envoy_full.json

echo "--- stream_idle_timeout (default 300s = BAD for large files) ---"
grep -o '"stream_idle_timeout":"[^"]*"' /tmp/envoy_full.json | sort -u

echo "--- route timeout (default 15s = kills large transfers) ---"
grep -o '"timeout":"[^"]*"' /tmp/envoy_full.json | sort -u | head -5

echo "--- HTTP/2 stream window (default 65536 = 64KB = TOO SMALL) ---"
grep -oE '"initial_stream_window_size":[0-9]+' /tmp/envoy_full.json | sort -u

echo "--- HTTP/2 connection window ---"
grep -oE '"initial_connection_window_size":[0-9]+' /tmp/envoy_full.json | sort -u

echo "--- per connection buffer limit ---"
grep -oE '"per_connection_buffer_limit_bytes":[0-9]+' /tmp/envoy_full.json | sort -u

echo "--- protocol toward backends ---"
kubectl exec -n $INGRESS_NS $INGRESS_POD -- \
  curl -s http://localhost:15000/clusters | \
  grep -oE "(minio|library|somecompany)[^|]*h[12]" | sort -u

echo "--- UPE reset count ---"
kubectl exec -n $INGRESS_NS $INGRESS_POD -- \
  curl -s http://localhost:15000/stats | \
  grep "upstream_rq_rx_reset" | sort -u

echo "--- Applied EnvoyFilters ---"
kubectl get envoyfilter --all-namespaces

echo "--- Applied DestinationRules ---"
kubectl get destinationrule --all-namespaces
```

Share the output and I can tell you exactly which settings need changing and give you the precise EnvoyFilter YAML to apply.
