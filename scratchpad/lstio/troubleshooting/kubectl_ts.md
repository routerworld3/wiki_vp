# Appendix — Pod Configuration
## A Step-by-Step Troubleshooting Playbook for Blind Environments

> **Scenario:** You've been dropped into a cluster you've never seen. Someone says "webapp is broken" and you have `kubectl` + `istioctl` access but no documentation. This appendix walks you from knowing nothing to understanding the full traffic path, in the order you'd actually investigate.

---

## The Mental Model — Follow the Packet

When debugging blind, **always walk the path a request takes**, from outside in:

```
1. DNS / external IP     →  What does a client hit?
2. AWS LoadBalancer      →  Which K8s Service is it pointing at?
3. Istio ingress gateway →  Is there one? What's its config?
4. Gateway resource      →  Which hostnames/ports are accepted?
5. VirtualService        →  How is the request routed?
6. DestinationRule       →  What protocol / LB policy / subsets?
7. K8s Service           →  What selector? What endpoints?
8. Pod                   →  What containers? What labels? What image?
9. Sidecar Envoy config  →  What does Envoy think it's doing?
```

Each step answers "what do I talk to next?" — so if any step fails, you know exactly where the chain broke.

---

## Step 0 — Orient Yourself

Before anything else, figure out **where you are** and **what's installed**.

```bash
# What cluster am I on?
kubectl config current-context

# What namespaces exist?
kubectl get namespaces

# Is Istio installed? If yes, what version?
kubectl get pods -n istio-system
istioctl version

# Is the app you're debugging in a specific namespace?
# Search all namespaces for a pod matching the app name
kubectl get pods --all-namespaces | grep -i webapp
kubectl get pods --all-namespaces | grep -i example-app
```

**What to look for:**
- `istio-system` namespace exists + `istiod` pod running → Istio is installed
- `istio-ingressgateway` pod in `istio-system` → Istio handles ingress
- App pod location tells you the namespace to scope everything else to

From here I'll assume the app is in namespace `<NS>` — substitute your real namespace in every command.

---

## Step 1 — Find the Pod and Its Basic Identity

Start at the target: find the Pod, confirm it's running, see its labels.

```bash
# List pods and check status
kubectl get pods -n <NS> -l app=webapp
# or if you don't know the label yet
kubectl get pods -n <NS>

# Get a detailed view of one pod
kubectl describe pod <POD_NAME> -n <NS>
```

**What to look for in `describe`:**
- `Status: Running` → pod is alive
- `Ready: 2/2` (or `1/1` without Istio) → both containers are healthy
- `Labels:` — these are what Services will match against. **Memorize these.**
- `Containers:` — how many containers in the pod?
  - Just `webapp` (or `example-app`) → no sidecar, this pod is NOT in the mesh
  - `webapp` + `istio-proxy` → sidecar injected, pod IS in the mesh
- `Events:` — recent failures (image pull errors, OOMKills, crash loops)

### Quick way to extract just labels

```bash
kubectl get pod <POD_NAME> -n <NS> --show-labels

# Or as JSON
kubectl get pod <POD_NAME> -n <NS> -o jsonpath='{.metadata.labels}' | jq
```

### Is there a sidecar? One-liner check

```bash
kubectl get pod <POD_NAME> -n <NS> \
  -o jsonpath='{.spec.containers[*].name}'
# Output like "webapp istio-proxy" means sidecar present
# Output like "webapp" alone means no sidecar
```

### Check for recent OOMKills (critical for sidecar memory issues)

```bash
kubectl get pod <POD_NAME> -n <NS> -o json \
  | jq '.status.containerStatuses[] | {name:.name, restartCount:.restartCount, lastState:.lastState}'
# Look for: "reason": "OOMKilled"
```

---

## Step 2 — Trace Back to the Deployment

The Pod is managed by *something* — usually a Deployment. Find it.

```bash
# Owner reference tells you what controls this pod
kubectl get pod <POD_NAME> -n <NS> -o json \
  | jq '.metadata.ownerReferences'
# Usually shows kind: ReplicaSet — then find its owner

# Shortcut: list deployments in the namespace
kubectl get deployments -n <NS>

# Get full Deployment spec (where labels, replicas, image come from)
kubectl get deployment webapp -n <NS> -o yaml
```

**What to extract:**
- `spec.replicas` — how many pods are supposed to be running
- `spec.selector.matchLabels` — **must exactly match** Pod labels (mismatch = Deployment won't own its Pods)
- `spec.template.metadata.labels` — what gets applied to new Pods
- `spec.template.spec.containers[].image` — what image and tag is deployed
- `spec.template.metadata.annotations` — sidecar overrides, e.g. `sidecar.istio.io/proxyMemory`

### Compact view of what's deployed

```bash
kubectl get deployment webapp -n <NS> \
  -o jsonpath='{.spec.template.spec.containers[*].image}'
```

---

## Step 3 — Find the Service That Targets the Pod

Now go up one layer: which Service is routing to this Pod?

```bash
# List services in the namespace
kubectl get services -n <NS>

# The selector is what matters — show each service's selector
kubectl get services -n <NS> -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,SELECTOR:.spec.selector,PORTS:.spec.ports[*].name
```

**What to look for:**
- A Service whose `selector` matches your Pod's labels
- `TYPE: ClusterIP` → internal only (expected with Istio)
- `TYPE: LoadBalancer` → has its own cloud LB (plain K8s style, or ingress gateway)
- `PORTS` — port name matters to Istio (`http` = HTTP/1.1 default, `http2` = HTTP/2)

### Confirm the Service actually found your Pod

**This is the single most important check in K8s debugging.** Zero endpoints = silent traffic drop.

```bash
kubectl get endpoints webapp-service -n <NS>
# If ENDPOINTS column is "<none>" — your selector doesn't match any Pod labels. STOP and fix this first.
```

```bash
# More detailed endpoints view (newer API)
kubectl get endpointslices -n <NS> -l kubernetes.io/service-name=webapp-service
```

### Full service spec

```bash
kubectl get service webapp-service -n <NS> -o yaml
```

---

## Step 4 — Is the Pod in the Istio Mesh?

If you saw `istio-proxy` as a container in Step 1, yes. Confirm with `istioctl`:

```bash
# Lists every pod istioctl knows about and its sidecar status
istioctl proxy-status

# Filter to your namespace
istioctl proxy-status | grep <NS>
```

**What to look for:**
- `SYNCED` in all columns (CDS, LDS, EDS, RDS) → sidecar is healthy and has current config
- `STALE` → sidecar is out of sync with istiod (config push problem)
- `NOT SENT` → istiod hasn't pushed this config yet
- Pod not listed at all → not in the mesh

### Quick per-pod detailed status

```bash
istioctl proxy-status <POD_NAME>.<NS>
```

---

## Step 5 — Which Istio Resources Apply to This Pod?

This is where `istioctl` really shines. It can tell you *exactly* which Istio resources are affecting a given pod.

### The "show me everything touching this pod" command

```bash
istioctl x describe pod <POD_NAME> -n <NS>
```

**Example output interpretation:**
```
Pod: webapp-7d9b8f-xyz12.webapp-ns
  Pod Revision: default
  Pod Ports: 80 (webapp), 15090 (istio-proxy), 15021 (istio-proxy)

Service: webapp-service
  Port: http 80/HTTP targets pod port 80        ← port name = "http" = HTTP/1.1

VirtualService: webapp-vs
   /api/* /ratings/* to webapp-service         ← routing rules

DestinationRule: webapp-dr for "webapp-service"
   Matching subsets: v1, v2
   Traffic Policy TLS Mode: ISTIO_MUTUAL
```

This one command tells you:
- Which Service covers this Pod
- Which VirtualService is routing to that Service
- Which DestinationRule applies (subsets, TLS, connection pool)
- Whether mTLS is on

### If `x describe` doesn't exist in your istioctl version

```bash
# Manually list everything and look for matches
kubectl get gateway,virtualservice,destinationrule,serviceentry,sidecar,envoyfilter -n <NS>

# Dump each one
kubectl get virtualservice -n <NS> -o yaml
kubectl get destinationrule -n <NS> -o yaml
kubectl get gateway -n <NS> -o yaml
```

---

## Step 6 — Understand the Gateway Entry Point

If the app is reachable from outside the cluster, there's a Gateway somewhere. Find it.

```bash
# Gateways can live in any namespace; -A searches all
kubectl get gateway -A

# Show which ports/hosts each Gateway opens
kubectl get gateway -A -o custom-columns=\
NAME:.metadata.name,\
NAMESPACE:.metadata.namespace,\
SELECTOR:.spec.selector,\
HOSTS:.spec.servers[*].hosts,\
PORTS:.spec.servers[*].port.number
```

### Follow the selector to the actual ingress Pod

```bash
# Most gateways use selector: istio: ingressgateway
# Find the pod it points to
kubectl get pods -n istio-system -l istio=ingressgateway
```

### Find the LoadBalancer the gateway is reachable through

```bash
# The istio-ingressgateway Service is usually where the cloud LB lives
kubectl get service istio-ingressgateway -n istio-system
# EXTERNAL-IP column = the AWS NLB / ELB / LB address
```

---

## Step 7 — Understand the VirtualService Routing

```bash
# Get the VirtualService and see where it routes
kubectl get virtualservice -n <NS> -o yaml

# Compact view — pull out hosts, gateway bindings, and destinations
kubectl get virtualservice -n <NS> -o json | jq '
  .items[] | {
    name: .metadata.name,
    hosts: .spec.hosts,
    gateways: .spec.gateways,
    routes: [.spec.http[]? | {
      match: .match,
      timeout: .timeout,
      route: [.route[] | {host: .destination.host, subset: .destination.subset}]
    }]
  }
'
```

**What to look for:**
- `hosts` — what hostnames this VS handles
- `gateways` — which Gateway this VS is bound to (or `mesh` for internal-only)
- Route destinations — which Service (and which subset) traffic actually goes to
- `timeout` — if unset, Istio default 15s may fire on slow responses
- `retries`, `fault` — are retries or fault injection configured?

---

## Step 8 — Understand the DestinationRule (Protocol & Connection Pool)

This is often the key to protocol-level issues (HTTP/1.1 vs HTTP/2).

```bash
kubectl get destinationrule -n <NS> -o yaml

# Look for h2UpgradePolicy, idleTimeout, load balancer, subsets
kubectl get destinationrule -n <NS> -o json | jq '
  .items[] | {
    name: .metadata.name,
    host: .spec.host,
    trafficPolicy: .spec.trafficPolicy,
    subsets: [.spec.subsets[]? | {name:.name, labels:.labels}]
  }
'
```

**What matters:**
- `trafficPolicy.connectionPool.http.h2UpgradePolicy` — if `UPGRADE`, HTTP/2 is forced
- `trafficPolicy.connectionPool.http.idleTimeout` — controls stale-connection behavior
- `trafficPolicy.loadBalancer` — which LB algorithm
- `subsets[].labels` — **these must match Pod labels or the subset is empty**

---

## Step 9 — Ask Envoy Directly (The Source of Truth)

Envoy is what's actually forwarding packets. Its live config beats any YAML if they disagree.

### What clusters (upstreams) does Envoy know about?

```bash
# For the ingress gateway
istioctl proxy-config cluster <INGRESSGATEWAY_POD> -n istio-system

# For a specific app pod's sidecar
istioctl proxy-config cluster <POD_NAME> -n <NS>

# Drill into one cluster's full config
istioctl proxy-config cluster <POD_NAME> -n <NS> \
  --fqdn webapp-service.<NS>.svc.cluster.local -o json
```

### What routes does Envoy have configured?

```bash
istioctl proxy-config routes <POD_NAME> -n <NS>

# Detail — timeouts, retry policy, matches
istioctl proxy-config routes <POD_NAME> -n <NS> -o json \
  | jq '.[] .virtualHosts[].routes[] | {match:.match, timeout:.route.timeout, cluster:.route.cluster}'
```

### What listeners (inbound ports) are open?

```bash
istioctl proxy-config listeners <POD_NAME> -n <NS>
```

### What endpoints does Envoy think are behind each cluster?

```bash
istioctl proxy-config endpoints <POD_NAME> -n <NS>
# If a cluster shows HEALTHY endpoints count = 0, traffic to it will fail
```

---

## Step 10 — Read Envoy's Live Stats (Admin Interface)

Envoy exposes a local admin API on port 15000. This is where you see **what's actually happening right now**.

```bash
# Port-forward to the sidecar (or ingress gateway) admin port
kubectl port-forward <POD_NAME> -n <NS> 15000:15000
```

Now, in another terminal:

```bash
# Full config dump (huge — grep aggressively)
curl -s localhost:15000/config_dump | jq '.' | less

# Just the listeners
curl -s localhost:15000/listeners

# Live stats — grep for what you care about
curl -s localhost:15000/stats | grep upstream_cx_http1     # HTTP/1.1 connection counts
curl -s localhost:15000/stats | grep upstream_cx_http2     # HTTP/2 connection counts
curl -s localhost:15000/stats | grep watermark             # buffer pressure events
curl -s localhost:15000/stats | grep server.memory         # Envoy memory usage
curl -s localhost:15000/stats | grep 5xx                   # 5xx error counts

# Per-connection buffer limit (default 1 MB)
curl -s localhost:15000/config_dump \
  | jq '.. | .per_connection_buffer_limit_bytes? // empty' | sort -u
```

### Common "aha" stats to check

| Stat | What it tells you |
|---|---|
| `downstream_flow_control_paused_reading_total` rising | Slow client — buffer pressure |
| `upstream_cx_destroy_remote_with_active_rq` rising | Upstream is closing connections mid-request (stale-connection issue) |
| `upstream_cx_http1_total` vs `upstream_cx_http2_total` | Which HTTP version is actually in use |
| `upstream_rq_retry` rising | Retries are firing — backend is flaky |
| `server.memory_allocated` near `server.memory_heap_size` | Envoy is near OOM |

---

## Step 11 — Read Envoy Access Logs for Failed Requests

Envoy's access logs include a **response flag** — a 2-3 letter code that tells you exactly what went wrong.

```bash
# Ingress gateway logs — filter to non-200
kubectl logs -l app=istio-ingressgateway -n istio-system --tail=200 | grep -v " 200 "

# Sidecar logs on the app pod
kubectl logs <POD_NAME> -n <NS> -c istio-proxy --tail=200 | grep -v " 200 "
```

### Response flag cheat sheet

| Flag | Meaning |
|---|---|
| `UH` | No healthy upstream (empty cluster) |
| `UF` | Upstream connection failure |
| `UT` | Upstream request timeout (route timeout fired) |
| `UC` | Upstream connection terminated |
| `UR` | Upstream remote reset |
| `SI` | Stream idle timeout |
| `DT` | Downstream connection terminated |
| `DC` | Downstream connection termination |
| `NR` | No route configured |
| `UPE` | Upstream protocol error (e.g. body too large on HTTP/1.1) |

Seeing `NR` → your VirtualService isn't matching. Seeing `UH` → your Service has no endpoints. Seeing `UT` → extend your timeout. Seeing `UPE` on uploads → you need HTTP/2.

---

## Complete Walkthrough — Example: "webapp isn't responding"

Here's what the full reverse-engineering flow looks like in practice.

```bash
# 0. Where am I?
kubectl config current-context
kubectl get namespaces | grep -i webapp
# → found namespace "webapp-prod"

NS=webapp-prod

# 1. Find the pod
kubectl get pods -n $NS -l app=webapp
# → webapp-7d9b8f-xyz12   2/2   Running

# Check containers
kubectl get pod webapp-7d9b8f-xyz12 -n $NS \
  -o jsonpath='{.spec.containers[*].name}'
# → "webapp istio-proxy"  (so it's in the mesh)

# 2. Trace to the Deployment
kubectl get deployment -n $NS
# → webapp   2/2

# 3. Find the Service
kubectl get service -n $NS -o wide
# → webapp-service  ClusterIP  10.x.x.x  80/TCP  app=webapp

# Confirm endpoints exist
kubectl get endpoints webapp-service -n $NS
# → webapp-service   10.1.2.3:80,10.1.2.4:80   ✓ (two pods found)

# 4. Istio mesh status
istioctl proxy-status | grep $NS
# → all columns SYNCED ✓

# 5. Which Istio resources apply?
istioctl x describe pod webapp-7d9b8f-xyz12 -n $NS
# → Service: webapp-service (port name: http)
#   VirtualService: webapp-vs → routes /api/* to webapp-service
#   DestinationRule: webapp-dr (TLS Mode: ISTIO_MUTUAL)

# 6. Gateway entry point
kubectl get gateway -A
# → webapp-gateway in $NS, selector istio=ingressgateway

kubectl get service istio-ingressgateway -n istio-system
# → EXTERNAL-IP: abcd1234.elb.amazonaws.com

# 7. VirtualService details
kubectl get virtualservice webapp-vs -n $NS -o yaml
# → hosts: ["webapp.example.com"], gateways: [webapp-gateway]
#   http: [{ timeout: 10s, route: [{destination: webapp-service}] }]

# 8. DestinationRule details
kubectl get destinationrule webapp-dr -n $NS -o yaml
# → trafficPolicy.connectionPool.http.h2UpgradePolicy: UPGRADE

# 9. Ask Envoy what it sees
istioctl proxy-config cluster webapp-7d9b8f-xyz12 -n $NS \
  --fqdn webapp-service.$NS.svc.cluster.local
# → matches DestinationRule, HTTP/2 upgrade confirmed

istioctl proxy-config endpoints webapp-7d9b8f-xyz12 -n $NS \
  | grep webapp-service
# → 2 HEALTHY endpoints

# 10. Live stats
kubectl port-forward webapp-7d9b8f-xyz12 -n $NS 15000:15000 &
curl -s localhost:15000/stats | grep 5xx
# → if 5xx counters are rising, something upstream is failing

# 11. Access logs
kubectl logs webapp-7d9b8f-xyz12 -n $NS -c istio-proxy --tail=50 | grep -v " 200 "
# → response flags tell you the failure mode
```

By the time you've run these commands, you know:
- Exactly which Pods, Services, VirtualServices, DestinationRules, and Gateways are in play
- Which HTTP version is in use
- Whether endpoints exist
- Whether the sidecar is healthy
- What the recent failure pattern looks like

---

## Quick-Reference — One-Liner Per Layer

| Question | Command |
|---|---|
| Is the pod running? | `kubectl get pod -n <NS> -l app=<APP>` |
| Is it in the mesh? | `kubectl get pod <POD> -n <NS> -o jsonpath='{.spec.containers[*].name}'` |
| Who owns this pod? | `kubectl get pod <POD> -n <NS> -o jsonpath='{.metadata.ownerReferences}'` |
| What image is deployed? | `kubectl get deployment <DEPLOY> -n <NS> -o jsonpath='{.spec.template.spec.containers[*].image}'` |
| Does the Service have endpoints? | `kubectl get endpoints <SVC> -n <NS>` |
| What Istio resources affect this pod? | `istioctl x describe pod <POD> -n <NS>` |
| Is the sidecar synced? | `istioctl proxy-status \| grep <POD>` |
| Where does Envoy route this? | `istioctl proxy-config routes <POD> -n <NS>` |
| What's HTTP protocol to upstream? | `istioctl proxy-config cluster <POD> -n <NS> -o json \| jq '.[].typedExtensionProtocolOptions'` |
| Any OOMKills? | `kubectl get pod <POD> -n <NS> -o json \| jq '.status.containerStatuses[].lastState'` |
| What's the external entry point? | `kubectl get svc istio-ingressgateway -n istio-system` |
| Recent failed requests? | `kubectl logs -l app=istio-ingressgateway -n istio-system --tail=200 \| grep -v " 200 "` |

---

## Logic — When to Go Deeper

Use this decision tree when you find something broken:

```
Is the Pod Running?                              NO → check Events, image pulls, resource limits
 ↓ YES
Is there a sidecar (istio-proxy)?                NO → not in mesh; plain K8s debugging
 ↓ YES
Does proxy-status show SYNCED?                   NO → istiod / config push problem
 ↓ YES
Does the Service have endpoints?                 NO → label/selector mismatch — #1 failure mode
 ↓ YES
Does `istioctl x describe pod` show a VS?        NO → no routing — add VirtualService
 ↓ YES
Are Envoy clusters showing HEALTHY endpoints?    NO → Service routing but no healthy upstream
 ↓ YES
Access logs — are requests arriving?             NO → client isn't reaching ingress gateway
 ↓ YES
What response flag on failed requests?
   NR → no VirtualService match for this path
   UH → Service has no healthy endpoints
   UT → route timeout firing — increase timeout
   UPE → HTTP/1.1 buffer limit — upgrade to HTTP/2
   SI → stream idle timeout — extend stream_idle_timeout
   UC/UF → upstream closing connections — idle timeout mismatch
```

---

*End of reverse-engineering appendix.*
