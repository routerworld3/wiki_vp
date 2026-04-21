# sample-app Deployment for Istio Troubleshooting Practice

> **Goal:** Deploy a single sample-app pod behind Istio on a cloud cluster so you can reproduce and fix every scenario in the troubleshooting guide — HTTP/1.1 buffer issues, upload failures, download timeouts, sidecar OOMKills.
>
> **Assumptions:**
> - You're on EKS, GKE, or AKS (anything with a working `LoadBalancer` Service type)
> - Istio is already installed, with `istio-ingressgateway` running in `istio-system`
> - You have `kubectl` and `istioctl` configured and pointing at the right cluster

---

## What This Deployment Looks Like

```
Internet
   │
   ▼
[ istio-ingressgateway ] ← cloud LoadBalancer (already provisioned)
   │
   ▼
[ Gateway: sample-app-gateway ]  ← accepts port 80
   │
   ▼
[ VirtualService: sample-app-vs ]  ← routes to sample-app Service
   │
   ▼
[ Service: sample-app (ClusterIP) ]
   │
   ▼
[ Pod: sample-app ]
   ├── sample-app container (port 9000)
   └── istio-proxy sidecar (auto-injected)
```

**Intentionally missing (to trigger failures):**
- No DestinationRule with `h2UpgradePolicy: UPGRADE` → HTTP/1.1 → upload failures
- No `timeout: 0s` on the VirtualService → default 15s route timeout
- Default sidecar resource limits → potential OOMKills with concurrent slow downloads

This is by design — you add those fixes one at a time while practicing troubleshooting.

---

## Step 0 — Pre-flight Checks

Verify your environment before applying anything.

```bash
# 1. Cluster connection works
kubectl cluster-info

# 2. You're on the cluster you expect
kubectl config current-context

# 3. Istio is installed and healthy
kubectl get pods -n istio-system
# Expect: istiod + istio-ingressgateway both Running

# 4. istioctl version matches istiod
istioctl version

# 5. The cloud LoadBalancer for ingress has an external IP
kubectl get svc istio-ingressgateway -n istio-system
# EXTERNAL-IP column should show a hostname (AWS NLB) or IP — not <pending>

# 6. You have permission to create namespaces + resources
kubectl auth can-i create namespace
kubectl auth can-i create deployment --namespace default
```

If any of these fail, stop and fix them first. Everything below assumes these pass.

### Grab the ingress address — you'll use it for testing

```bash
# On EKS (returns a hostname)
export INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# On GKE/AKS (returns an IP)
if [ -z "$INGRESS_HOST" ]; then
  export INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

echo "Ingress: $INGRESS_HOST"
```

---

## Step 1 — Create the Namespace with Sidecar Injection Enabled

sample-app needs to live in a namespace where Istio auto-injects sidecars.

**File: `00-namespace.yaml`**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: sample-app-demo
  labels:
    istio-injection: enabled       # auto-inject Envoy sidecar into every pod
```

```bash
kubectl apply -f 00-namespace.yaml

# Verify the injection label is set
kubectl get namespace sample-app-demo --show-labels
# Should show: istio-injection=enabled
```

---

## Step 2 — Create Credentials

Minimal root credentials for the sample-app server. In real deployments you'd use external secret managers.

**File: `01-credentials.yaml`**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sample-app-creds
  namespace: sample-app-demo
type: Opaque
stringData:
  sample-app_ROOT_USER: admin                    # this is not real username 
  sample-app_ROOT_PASSWORD: admin12345           # min 8 chars; change for anything real
```

```bash
kubectl apply -f 01-credentials.yaml
```

> Yes, these creds are terrible. This is a disposable test deployment. If you leave it running, rotate them.

---

## Step 3 — Deploy sample-app (Single Pod, Ephemeral Storage)

**File: `02-deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: sample-app-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: sample-app
        image: sample-app/sample-app:latest
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        ports:
        - name: api
          containerPort: 9000
        - name: console
          containerPort: 9001
        envFrom:
        - secretRef:
            name: sample-app-creds
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: data
        emptyDir: {}                          # ephemeral — data lost on pod restart
```

```bash
kubectl apply -f 02-deployment.yaml

# Wait for the pod to come up (should take ~30 seconds)
kubectl get pods -n sample-app-demo -w
# Look for: 2/2 Running (2 containers = sample-app + istio-proxy sidecar)
# Ctrl-C to exit the watch
```

### Verify the sidecar was injected

```bash
kubectl get pod -n sample-app-demo -l app=sample-app \
  -o jsonpath='{.items[0].spec.containers[*].name}'
# Expected output: "sample-app istio-proxy"
```

If you only see `sample-app` without `istio-proxy`, the namespace injection label didn't take. Delete the pod so it respawns with injection:

```bash
kubectl delete pod -n sample-app-demo -l app=sample-app
```

---

## Step 4 — Create the sample-app Service

Internal-only ClusterIP — Istio handles external entry.

**File: `03-service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sample-app
  namespace: sample-app-demo
spec:
  type: ClusterIP
  selector:
    app: sample-app
  ports:
  - name: http                   # ⚠ INTENTIONALLY "http" → HTTP/1.1 (this triggers upload failures)
    port: 9000
    targetPort: 9000
  - name: http-console
    port: 9001
    targetPort: 9001
```

```bash
kubectl apply -f 03-service.yaml

# Confirm endpoints exist (this is the #1 silent failure check)
kubectl get endpoints sample-app -n sample-app-demo
# Should show the pod IP:9000,9001 — NOT <none>
```

> **Note the port name:** I deliberately used `http` (not `http2`). This forces HTTP/1.1 between Envoy and sample-app, which is exactly what triggers the upload failure scenario in the troubleshooting guide. You'll change it to `http2` as part of the fix.

---

## Step 5 — Create the Istio Gateway

Opens port 80 on the shared `istio-ingressgateway`.

**File: `04-gateway.yaml`**

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: sample-app-gateway
  namespace: sample-app-demo
spec:
  selector:
    istio: ingressgateway              # shared cluster-wide ingress
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"                              # accept any hostname
```

```bash
kubectl apply -f 04-gateway.yaml
```

---

## Step 6 — Create the VirtualService

Routes all incoming requests to the sample-app service.

**File: `05-virtualservice.yaml`**

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: sample-app-vs
  namespace: sample-app-demo
spec:
  hosts:
  - "*"
  gateways:
  - sample-app-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: sample-app.sample-app-demo.svc.cluster.local
        port:
          number: 9000
    # ⚠ INTENTIONALLY NO timeout: 0s → default 15s route timeout will fire on slow downloads
```

```bash
kubectl apply -f 05-virtualservice.yaml
```

---

## Step 7 — Verify End-to-End

### 7a. Everything is in place

```bash
kubectl get all,gateway,virtualservice -n sample-app-demo
```

Expected: 1 pod `Running 2/2`, 1 deployment, 1 replicaset, 1 service, 1 gateway, 1 virtualservice.

### 7b. Istio sees the pod and config is synced

```bash
istioctl proxy-status | grep sample-app-demo
# Expect all columns: SYNCED
```

### 7c. Istio shows what resources affect the pod

```bash
POD=$(kubectl get pod -n sample-app-demo -l app=sample-app -o jsonpath='{.items[0].metadata.name}')
istioctl x describe pod $POD -n sample-app-demo
```

Expected output includes:
- `Service: sample-app` with port name `http` (confirms HTTP/1.1)
- `VirtualService: sample-app-vs`
- No `DestinationRule` (none created yet — this is intentional)

### 7d. Hit sample-app from outside

```bash
# You set INGRESS_HOST in Step 0
curl -v http://$INGRESS_HOST/sample-app/health/live
# Expect: HTTP/1.1 200 OK
```

If you get `200` — you're fully wired up.

If you get `404` — VirtualService didn't match. Check `kubectl logs -l app=istio-ingressgateway -n istio-system --tail=50`.

If you get `503` → `UH` response flag — Service has no endpoints. Check `kubectl get endpoints sample-app -n sample-app-demo`.

---

## Step 8 — Install the sample-app Client (mc) to Generate Real Traffic

You need a way to actually upload and download files. The sample-app client (`mc`) is the easiest option.

```bash
# macOS
brew install sample-app/stable/mc

# Linux
curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Windows (PowerShell)
# Invoke-WebRequest -Uri "https://dl.min.io/client/mc/release/windows-amd64/mc.exe" -OutFile "mc.exe"
```

### Configure an alias pointing at your ingress

```bash
mc alias set local http://$INGRESS_HOST admin admin12345

# Verify the alias works
mc admin info local

# Create a test bucket
mc mb local/testbucket
mc ls local
```

---

## Step 9 — Reproduce Each Troubleshooting Scenario

Now you can practice every scenario from the troubleshooting guide. Each one fails with the current config — then you apply the fix and verify.

### Scenario A — Large Upload Fails (HTTP/1.1 buffer limit)

**Generate a 300 MB test file and upload it:**

```bash
# Create a 300 MB file of random bytes
dd if=/dev/urandom of=/tmp/bigfile.bin bs=1M count=300

# Attempt upload
time mc cp /tmp/bigfile.bin local/testbucket/
# Expected: fails with UPE or similar error
```

**Observe the failure via logs:**

```bash
kubectl logs -l app=istio-ingressgateway -n istio-system --tail=50 | grep -v " 200 "
# Look for response flag UPE or UC
```

**Apply the fix (HTTP/2 DestinationRule):**

**File: `06-destinationrule-fix.yaml`**

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: sample-app-h2
  namespace: sample-app-demo
spec:
  host: sample-app.sample-app-demo.svc.cluster.local
  trafficPolicy:
    connectionPool:
      http:
        h2UpgradePolicy: UPGRADE       # force HTTP/2 — eliminates body buffering
        idleTimeout: 90s
```

```bash
kubectl apply -f 06-destinationrule-fix.yaml

# Verify HTTP/2 is now in use
istioctl proxy-config cluster $POD -n sample-app-demo \
  --fqdn sample-app.sample-app-demo.svc.cluster.local -o json \
  | jq '.[].typedExtensionProtocolOptions'
# Should show: http2_protocol_options

# Retry the upload
time mc cp /tmp/bigfile.bin local/testbucket/
# Expect: success
```

### Scenario B — Download Times Out (15s route timeout)

To reliably force this you need to simulate a slow client. Easiest approach: throttle via `curl --limit-rate`.

**Upload a reasonably large file first (with the HTTP/2 fix applied):**

```bash
mc cp /tmp/bigfile.bin local/testbucket/bigfile.bin
```

**Now download it *throttled* so the transfer exceeds 15 seconds:**

```bash
# Without fix — download at 10 MB/s for a 300 MB file = ~30s, will hit 15s timeout
curl --limit-rate 10M -o /tmp/download.bin \
  "http://$INGRESS_HOST/testbucket/bigfile.bin" -v
# Expected: truncated file or connection reset mid-stream
```

**Check the response flag:**

```bash
kubectl logs -l app=istio-ingressgateway -n istio-system --tail=50 | grep -v " 200 "
# Look for UT = Upstream Timeout
```

**Apply the fix (disable route timeout):**

**File: `07-virtualservice-fix.yaml`**

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: sample-app-vs
  namespace: sample-app-demo
spec:
  hosts:
  - "*"
  gateways:
  - sample-app-gateway
  http:
  - timeout: 0s                        # disable route timeout
    match:
    - uri:
        prefix: /
    route:
    - destination:
        host: sample-app.sample-app-demo.svc.cluster.local
        port:
          number: 9000
```

```bash
kubectl apply -f 07-virtualservice-fix.yaml

# Verify the timeout is now 0s
istioctl proxy-config routes $(kubectl get pod -l app=istio-ingressgateway -n istio-system -o jsonpath='{.items[0].metadata.name}') \
  -n istio-system -o json \
  | jq '.[] .virtualHosts[].routes[] | {timeout:.route.timeout}'
# Should show: "0s"

# Retry the throttled download
curl --limit-rate 10M -o /tmp/download.bin \
  "http://$INGRESS_HOST/testbucket/bigfile.bin"
# Expect: full file downloads successfully
```

### Scenario C — Sidecar Buffer Pressure (reverse-engineer your env)

This one's most useful as a **diagnostic walkthrough** rather than a reliable trigger (reproducing OOMKills consistently requires many parallel slow clients). Practice the diagnostic commands:

```bash
POD=$(kubectl get pod -n sample-app-demo -l app=sample-app -o jsonpath='{.items[0].metadata.name}')

# 1. Check sidecar resource limits
kubectl get pod $POD -n sample-app-demo -o json \
  | jq '.spec.containers[] | {name:.name, resources:.resources}'

# 2. Live resource usage
kubectl top pod -n sample-app-demo --containers

# 3. Check for OOMKill history
kubectl get pod $POD -n sample-app-demo -o json \
  | jq '.status.containerStatuses[] | {name:.name, restartCount:.restartCount, lastState:.lastState}'

# 4. Ask Envoy about watermark events
kubectl exec -it $POD -n sample-app-demo -c istio-proxy \
  -- curl -s localhost:15000/stats \
  | grep -E "downstream_flow_control_paused|watermark|server.memory"

# 5. Check current per-connection buffer limit
kubectl exec -it $POD -n sample-app-demo -c istio-proxy \
  -- curl -s localhost:15000/config_dump \
  | jq '.. | .per_connection_buffer_limit_bytes? // empty' | sort -u
# Default: 1048576 (1 MB)
```

### Scenario D — Practice the full reverse-engineering walkthrough

Pretend you know nothing about this deployment. Starting from `kubectl get pods --all-namespaces | grep sample-app`, run through every step of the reverse-engineering appendix and confirm each answer matches what you configured here. This is the best way to build muscle memory.

---

## Step 10 — Useful Practice Commands Cheat Sheet

```bash
# Shortcut — set POD once
export POD=$(kubectl get pod -n sample-app-demo -l app=sample-app -o jsonpath='{.items[0].metadata.name}')
export IGW=$(kubectl get pod -n istio-system -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}')

# What does istio think about this pod?
istioctl x describe pod $POD -n sample-app-demo

# What's the sidecar's view of the world?
istioctl proxy-config cluster $POD -n sample-app-demo
istioctl proxy-config routes $POD -n sample-app-demo
istioctl proxy-config listeners $POD -n sample-app-demo
istioctl proxy-config endpoints $POD -n sample-app-demo

# What's the ingress gateway's view?
istioctl proxy-config routes $IGW -n istio-system
istioctl proxy-config cluster $IGW -n istio-system --fqdn sample-app.sample-app-demo.svc.cluster.local

# Live Envoy admin on the sidecar
kubectl exec -it $POD -n sample-app-demo -c istio-proxy \
  -- curl -s localhost:15000/stats | grep -E "upstream_cx_http|5xx|watermark"

# Live Envoy admin on the ingress gateway
kubectl port-forward $IGW -n istio-system 15000:15000 &
curl -s localhost:15000/stats | grep -E "upstream_cx_http|5xx"

# Tail access logs with response flags highlighted
kubectl logs -f -l app=istio-ingressgateway -n istio-system \
  | grep -vE " 200 | 204 "
```

---

## Step 11 — Teardown

When you're done practicing, remove everything cleanly:

```bash
# Delete the whole namespace — takes everything with it
kubectl delete namespace sample-app-demo

# Verify
kubectl get namespace sample-app-demo
# Expect: Error from server (NotFound)

# The cloud LoadBalancer belongs to istio-ingressgateway, not you — leave it alone
```

---

## Summary — File Order

Apply in this order for the initial broken state:

| Order | File | Purpose |
|---|---|---|
| 1 | `00-namespace.yaml` | Namespace with Istio injection enabled |
| 2 | `01-credentials.yaml` | Root user/password Secret |
| 3 | `02-deployment.yaml` | Single sample-app pod, ephemeral storage |
| 4 | `03-service.yaml` | ClusterIP Service, port name `http` (HTTP/1.1 — intentional) |
| 5 | `04-gateway.yaml` | Istio Gateway opening port 80 |
| 6 | `05-virtualservice.yaml` | L7 routing, no timeout override (15s default — intentional) |

Then, as you work through the troubleshooting scenarios, add:

| Order | File | Fixes |
|---|---|---|
| 7 | `06-destinationrule-fix.yaml` | HTTP/2 upgrade — fixes upload failures |
| 8 | `07-virtualservice-fix.yaml` | `timeout: 0s` — fixes download timeouts |

One-shot apply for the full working state:

```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-credentials.yaml
kubectl apply -f 02-deployment.yaml
kubectl apply -f 03-service.yaml
kubectl apply -f 04-gateway.yaml
kubectl apply -f 05-virtualservice.yaml
# practice the broken state first, then:
kubectl apply -f 06-destinationrule-fix.yaml
kubectl apply -f 07-virtualservice-fix.yaml
```

---

*End of deployment guide.*
