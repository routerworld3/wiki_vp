# Kubernetes Networking Guide
## Plain K8s and K8s with Istio — for beginners

---

## What is Kubernetes? A quick mental model

Think of Kubernetes (K8s) as an **operating system for your servers**. Instead of manually deciding which machine runs what, you describe what you want and Kubernetes figures it out.

| Object | What it does |
|---|---|
| **Pod** | One running instance of your app (like a process) |
| **Deployment** | Manages your Pods — keeps N copies alive, handles updates |
| **Service** | A stable address that routes traffic to your Pods |
| **Node** | An actual server (VM or physical) that runs Pods |

---

## Part 1 — Kubernetes without Istio

Deploy a simple web app called `webapp`. You need exactly **two files**.

### deployment.yaml

```yaml
# deployment.yaml — tells K8s: "run 2 copies of webapp"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2              # run 2 Pods
  selector:
    matchLabels:
      app: webapp          # ← selector finds Pods with this label
  template:
    metadata:
      labels:
        app: webapp        # ← Pods get this label (must match above)
    spec:
      containers:
      - name: webapp
        image: nginx:latest
        ports:
        - containerPort: 80
```

**Key notes:**
- `replicas: 2` — K8s will always keep 2 Pods running. If one crashes, it starts a replacement automatically.
- `app: webapp` — this label is the "wiring". The Deployment uses it to own its Pods, and the Service uses it to find them. A mismatch = no traffic delivered.
- `containerPort: 80` — purely informational (documents what port the app uses). It does **not** open any external access.

---

### service.yaml (without Istio — type: LoadBalancer)

```yaml
# service.yaml — creates an AWS NLB and routes to our Pods
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: LoadBalancer        # tells AWS: "create an NLB for me"
  selector:
    app: webapp             # ← finds Pods with this label
  ports:
  - port: 80               # external port (what clients connect to)
    targetPort: 80         # port on the Pod container
    nodePort: 30080        # port opened on every Node (auto-assigned if omitted)
```

**Key notes:**
- `type: LoadBalancer` — on AWS/EKS this triggers the cloud controller to automatically provision an NLB.
- `selector: app: webapp` — K8s watches all Pods with this label and builds an endpoint list. If no Pods match, traffic is dropped silently.
- `nodePort: 30080` — the hidden middle layer. The NLB sends traffic to `NodeIP:30080` on any node, then K8s routes it to the right Pod. Range must be 30000–32767.

---

### Traffic flow — without Istio

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 500" width="600">
  <defs>
    <marker id="arr" viewBox="0 0 10 10" refX="8" refY="5"
            markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M2 1L8 5L2 9" fill="none" stroke="#555" stroke-width="1.5"
            stroke-linecap="round" stroke-linejoin="round"/>
    </marker>
  </defs>

  <!-- Client -->
  <rect x="175" y="20" width="250" height="50" rx="8"
        fill="#f1efe8" stroke="#b4b2a9" stroke-width="1"/>
  <text x="300" y="50" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#2c2c2a">Client (browser / curl)</text>

  <line x1="300" y1="70" x2="300" y2="105"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr)"/>
  <text x="320" y="93" font-family="sans-serif" font-size="11"
        fill="#888780">DNS → NLB IP</text>

  <!-- NLB -->
  <rect x="150" y="108" width="300" height="50" rx="8"
        fill="#e6f1fb" stroke="#85b7eb" stroke-width="1"/>
  <text x="300" y="128" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#0c447c">AWS Network Load Balancer</text>
  <text x="300" y="148" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#185fa5">Created by type: LoadBalancer</text>

  <line x1="300" y1="158" x2="300" y2="193"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr)"/>
  <text x="320" y="181" font-family="sans-serif" font-size="11"
        fill="#888780">TCP :30080</text>

  <!-- NodePort -->
  <rect x="110" y="196" width="380" height="50" rx="8"
        fill="#faeeda" stroke="#ef9f27" stroke-width="1"/>
  <text x="300" y="216" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#633806">NodePort (port 30080 on every node)</text>
  <text x="300" y="236" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">NLB hits any node — kube-proxy routes onward</text>

  <line x1="300" y1="246" x2="300" y2="281"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr)"/>

  <!-- Service -->
  <rect x="150" y="284" width="300" height="50" rx="8"
        fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1"/>
  <text x="300" y="304" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#085041">Service: webapp-service</text>
  <text x="300" y="324" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#0f6e56">Picks a Pod via selector: app=webapp</text>

  <!-- Split to Pods -->
  <line x1="250" y1="334" x2="155" y2="396"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr)"/>
  <line x1="350" y1="334" x2="445" y2="396"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr)"/>
  <text x="175" y="378" font-family="sans-serif" font-size="11"
        fill="#888780">round-robin</text>

  <!-- Pod 1 -->
  <rect x="60" y="399" width="190" height="50" rx="8"
        fill="#eeedfe" stroke="#afa9ec" stroke-width="1"/>
  <text x="155" y="419" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#26215c">Pod 1: webapp</text>
  <text x="155" y="439" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#534ab7">nginx on port 80</text>

  <!-- Pod 2 -->
  <rect x="350" y="399" width="190" height="50" rx="8"
        fill="#eeedfe" stroke="#afa9ec" stroke-width="1"/>
  <text x="445" y="419" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#26215c">Pod 2: webapp</text>
  <text x="445" y="439" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#534ab7">nginx on port 80</text>

  <text x="300" y="475" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#888780">replicas: 2 — same Deployment, 2 identical Pods</text>
</svg>
```

> **Key insight:** The NodePort layer is invisible in your config (K8s manages it), but it's physically real. The NLB never talks directly to a Pod — it always hits a Node first, then `kube-proxy` routes to the right Pod via the Service's selector.

---

## Part 2 — Service types

| Type | Visibility | When to use |
|---|---|---|
| **ClusterIP** | Internal only | Databases, internal APIs, anything that should never be public |
| **NodePort** | Node IP + fixed port (30000–32767) | Dev/testing, or when you manage your own load balancer externally |
| **LoadBalancer** | Cloud NLB with public IP | Production services that need to be reachable from the internet |

> **LoadBalancer ⊃ NodePort ⊃ ClusterIP** — each type builds on the previous one.

---

## Part 3 — Adding Istio

Istio is a **service mesh**. It adds a proxy called **Envoy** to every Pod as a "sidecar" — a second container that intercepts all traffic in and out. Think of it as a smart traffic cop living next to your app.

With Istio you now need **four files** instead of two.

### Files overview

| File | Change from plain K8s |
|---|---|
| `deployment.yaml` | **Unchanged.** Istio auto-injects the Envoy sidecar. |
| `service.yaml` | Now uses `type: ClusterIP` — internal only. Istio handles external entry. |
| `gateway.yaml` | **New.** Tells Istio's edge proxy which ports/hostnames to accept. |
| `virtualservice.yaml` | **New.** L7 routing rules — host/path → service. |

> There is also a **cluster-wide** `istio-ingressgateway` Service (type: LoadBalancer) installed once when you install Istio. You do not create this per app.

---

### gateway.yaml

```yaml
# gateway.yaml — opens port 80 on the Istio edge proxy
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: webapp-gateway
spec:
  selector:
    istio: ingressgateway   # targets the Istio edge proxy pod
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"                   # accept any hostname (use "myapp.com" in production)
```

---

### virtualservice.yaml

```yaml
# virtualservice.yaml — routing rules: host/* → webapp-service
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: webapp-vs
spec:
  hosts:
  - "*"
  gateways:
  - webapp-gateway          # references the Gateway above by name
  http:
  - route:
    - destination:
        host: webapp-service  # K8s Service name
        port:
          number: 80
```

---

### Traffic flow — with Istio

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 620 660" width="620">
  <defs>
    <marker id="arr2" viewBox="0 0 10 10" refX="8" refY="5"
            markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M2 1L8 5L2 9" fill="none" stroke="#555" stroke-width="1.5"
            stroke-linecap="round" stroke-linejoin="round"/>
    </marker>
  </defs>

  <!-- Istio zone bracket -->
  <rect x="16" y="240" width="588" height="380" rx="10"
        fill="none" stroke="#d85a30" stroke-width="1" stroke-dasharray="5 4"/>
  <text x="28" y="260" font-family="sans-serif" font-size="11"
        fill="#d85a30">Istio layer</text>

  <!-- Client -->
  <rect x="185" y="20" width="250" height="44" rx="8"
        fill="#f1efe8" stroke="#b4b2a9" stroke-width="1"/>
  <text x="310" y="47" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#2c2c2a">Client</text>

  <line x1="310" y1="64" x2="310" y2="96"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr2)"/>

  <!-- NLB -->
  <rect x="155" y="99" width="310" height="50" rx="8"
        fill="#e6f1fb" stroke="#85b7eb" stroke-width="1"/>
  <text x="310" y="119" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#0c447c">AWS Network Load Balancer</text>
  <text x="310" y="139" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#185fa5">From istio-ingressgateway Service (LoadBalancer)</text>

  <line x1="310" y1="149" x2="310" y2="181"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr2)"/>
  <text x="330" y="170" font-family="sans-serif" font-size="11" fill="#888780">TCP :80</text>

  <!-- NodePort -->
  <rect x="120" y="184" width="380" height="44" rx="8"
        fill="#faeeda" stroke="#ef9f27" stroke-width="1"/>
  <text x="310" y="200" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#633806">NodePort (on every node)</text>
  <text x="310" y="218" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">kube-proxy routes to ingressgateway Pod</text>

  <line x1="310" y1="228" x2="310" y2="260"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr2)"/>

  <!-- istio-ingressgateway Service -->
  <rect x="100" y="263" width="420" height="50" rx="8"
        fill="#faece7" stroke="#f0997b" stroke-width="1"/>
  <text x="310" y="283" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#4a1b0c">Service: istio-ingressgateway</text>
  <text x="310" y="303" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#993c1d">Cluster-wide — installed once with Istio</text>

  <line x1="310" y1="313" x2="310" y2="345"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr2)"/>

  <!-- Envoy ingress pod -->
  <rect x="90" y="348" width="440" height="50" rx="8"
        fill="#faece7" stroke="#f0997b" stroke-width="1"/>
  <text x="310" y="368" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#4a1b0c">Pod: istio-ingressgateway (Envoy)</text>
  <text x="310" y="388" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#993c1d">Reads Gateway config → applies VirtualService rules</text>

  <line x1="310" y1="398" x2="310" y2="430"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr2)"/>
  <text x="330" y="420" font-family="sans-serif" font-size="11" fill="#888780">L7 routing</text>

  <!-- webapp-service -->
  <rect x="130" y="433" width="360" height="50" rx="8"
        fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1"/>
  <text x="310" y="453" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#085041">Service: webapp-service (ClusterIP)</text>
  <text x="310" y="473" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#0f6e56">Internal — selector: app=webapp</text>

  <!-- Split to Pods -->
  <line x1="260" y1="483" x2="165" y2="545"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr2)"/>
  <line x1="360" y1="483" x2="455" y2="545"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr2)"/>

  <!-- Pod 1 -->
  <rect x="60" y="548" width="210" height="50" rx="8"
        fill="#eeedfe" stroke="#afa9ec" stroke-width="1"/>
  <text x="165" y="568" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#26215c">Pod 1: webapp</text>
  <text x="165" y="588" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#534ab7">Envoy sidecar + nginx app</text>

  <!-- Pod 2 -->
  <rect x="350" y="548" width="210" height="50" rx="8"
        fill="#eeedfe" stroke="#afa9ec" stroke-width="1"/>
  <text x="455" y="568" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#26215c">Pod 2: webapp</text>
  <text x="455" y="588" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#534ab7">Envoy sidecar + nginx app</text>

  <text x="310" y="625" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#888780">replicas: 2 — Envoy sidecar auto-injected by Istio</text>
</svg>
```

---

## Part 4 — The selector chain: how everything is wired

Nothing in Kubernetes is hardwired by position — everything is connected by **matching labels and names**.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 620 500" width="620">
  <defs>
    <marker id="arr3" viewBox="0 0 10 10" refX="8" refY="5"
            markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M2 1L8 5L2 9" fill="none" stroke="#555" stroke-width="1.5"
            stroke-linecap="round" stroke-linejoin="round"/>
    </marker>
  </defs>

  <!-- VirtualService -->
  <rect x="30" y="30" width="250" height="56" rx="8"
        fill="#e6f1fb" stroke="#85b7eb" stroke-width="1"/>
  <text x="155" y="52" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#0c447c">VirtualService</text>
  <text x="155" y="72" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#185fa5">gateways: [webapp-gateway]</text>

  <!-- VS → Gateway (by name) -->
  <line x1="155" y1="86" x2="155" y2="160"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr3)"/>
  <rect x="76" y="104" width="158" height="20" rx="4" fill="#fff" opacity="0.9"/>
  <text x="155" y="118" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#888780">references by name</text>

  <!-- Gateway -->
  <rect x="30" y="163" width="250" height="56" rx="8"
        fill="#e1f5ee" stroke="#5dcaa5" stroke-width="1"/>
  <text x="155" y="185" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#085041">Gateway</text>
  <text x="155" y="205" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#0f6e56">selector: istio: ingressgateway</text>

  <!-- Gateway → ingress pod (by label) -->
  <line x1="280" y1="191" x2="340" y2="191"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr3)"/>
  <text x="310" y="183" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#888780">matches label</text>

  <!-- Istio ingress pod -->
  <rect x="340" y="163" width="250" height="56" rx="8"
        fill="#faece7" stroke="#f0997b" stroke-width="1"/>
  <text x="465" y="185" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#4a1b0c">Ingress gateway Pod</text>
  <text x="465" y="205" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#993c1d">label: istio=ingressgateway</text>

  <!-- VS → webapp-service (dashed, by name) -->
  <path d="M280 58 L570 58 L570 300" fill="none" stroke="#555"
        stroke-width="1.5" stroke-dasharray="5 3" marker-end="url(#arr3)"/>
  <rect x="380" y="44" width="180" height="20" rx="4" fill="#fff" opacity="0.9"/>
  <text x="470" y="58" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#888780">routes to by name</text>

  <!-- webapp-service -->
  <rect x="340" y="303" width="250" height="56" rx="8"
        fill="#faeeda" stroke="#ef9f27" stroke-width="1"/>
  <text x="465" y="323" text-anchor="middle" font-family="sans-serif"
        font-size="14" font-weight="500" fill="#633806">Service: webapp-service</text>
  <text x="465" y="343" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#854f0b">selector: app=webapp</text>

  <!-- Service → Pods -->
  <line x1="465" y1="359" x2="465" y2="400"
        stroke="#555" stroke-width="1.5" marker-end="url(#arr3)"/>
  <text x="483" y="385" font-family="sans-serif" font-size="11" fill="#888780">matches label</text>

  <!-- Pods -->
  <rect x="340" y="403" width="115" height="56" rx="8"
        fill="#eeedfe" stroke="#afa9ec" stroke-width="1"/>
  <text x="397" y="425" text-anchor="middle" font-family="sans-serif"
        font-size="13" font-weight="500" fill="#26215c">Pod 1</text>
  <text x="397" y="445" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#534ab7">app=webapp</text>

  <rect x="465" y="403" width="115" height="56" rx="8"
        fill="#eeedfe" stroke="#afa9ec" stroke-width="1"/>
  <text x="522" y="425" text-anchor="middle" font-family="sans-serif"
        font-size="13" font-weight="500" fill="#26215c">Pod 2</text>
  <text x="522" y="445" text-anchor="middle" font-family="sans-serif"
        font-size="11" fill="#534ab7">app=webapp</text>

  <!-- Warning box -->
  <rect x="30" y="370" width="280" height="80" rx="8"
        fill="#fcebeb" stroke="#f09595" stroke-width="1"/>
  <text x="170" y="398" text-anchor="middle" font-family="sans-serif"
        font-size="13" font-weight="500" fill="#501313">⚠ If labels don't match</text>
  <text x="170" y="418" text-anchor="middle" font-family="sans-serif"
        font-size="12" fill="#a32d2d">Service has 0 endpoints</text>
  <text x="170" y="436" text-anchor="middle" font-family="sans-serif"
        font-size="12" fill="#a32d2d">Traffic silently drops</text>
</svg>
```

---

## Part 5 — Side-by-side comparison

| | Without Istio | With Istio |
|---|---|---|
| **Files needed** | deployment.yaml, service.yaml (LoadBalancer) | deployment.yaml, service.yaml (ClusterIP), gateway.yaml, virtualservice.yaml |
| **External entry** | Your app's Service (LoadBalancer) | istio-ingressgateway Service (cluster-wide, shared) |
| **Routing control** | L4 only (IP + port) | L7 (host, path, headers, weights) |
| **Traffic visibility** | None built-in | Metrics, tracing, mTLS between Pods |
| **App Service type** | LoadBalancer | ClusterIP |
| **NLB count** | One per app Service | One shared for whole cluster |
| **Proxy in Pod** | None | Envoy sidecar (auto-injected) |

---

## Memory anchors

**Without Istio:**
```
NLB → NodePort → Service → Pod
```
Two files. Your Service *is* the load balancer.

**With Istio:**
```
NLB → NodePort → Envoy (ingress) → VirtualService rules → Service → Pod (Envoy sidecar)
```
Four files. Istio owns the entry point; your Service becomes internal-only.

**The selector rule — never forget this:**
> If `selector: app=webapp` in your Service doesn't exactly match `labels: app=webapp` on your Pods, the Service has zero endpoints and traffic silently drops — no error, no warning.

**Gateway vs VirtualService:**
- **Gateway** = *opens the door* (which ports/hosts to accept)
- **VirtualService** = *directs the visitor* (where to send them once inside)
