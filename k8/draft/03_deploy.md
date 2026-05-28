
## Step 0 — Shared prerequisites (both paths)

Install these locally: `aws cli`, `eksctl`, `kubectl`, `helm`, plus `uds` CLI (UDS only) and `flux` CLI (optional, Big Bang).

```bash
# UDS CLI (mac/linux via Homebrew)
brew install defenseunicorns/tap/uds

# Flux CLI (optional, for inspecting Big Bang)
brew install fluxcd/tap/flux
```

## Step 1 — Create the EKS cluster (used by both)

This is identical regardless of which platform you install on top. Save as `eks-cluster.yaml`:

```yaml
# eks-cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: platform-demo
  region: us-east-1
  version: "1.31"
managedNodeGroups:
  - name: ng-1
    instanceType: m5.2xlarge   # Big Bang/UDS full stacks are hungry
    desiredCapacity: 3
    minSize: 3
    maxSize: 4
    volumeSize: 100
iam:
  withOIDC: true               # needed for AWS Load Balancer Controller / IRSA
addons:
  - name: vpc-cni
  - name: aws-ebs-csi-driver   # persistent storage for Prometheus/Loki/Keycloak
```

```bash
eksctl create cluster -f eks-cluster.yaml
aws eks update-kubeconfig --name platform-demo --region us-east-1
kubectl get nodes   # confirm 3 Ready nodes
```

You'll also want the AWS Load Balancer Controller so the Istio ingress gateway's `type: LoadBalancer` Service provisions a real NLB (this connects directly to your networking guide's NLB → NodePort → Service → Pod flow).

---

# Path A — Big Bang on EKS

Big Bang's model: you install **Flux**, then hand Flux a Git repo + a Big Bang `HelmRelease`. Flux pulls it and installs ~20 charts. You don't `helm install` each tool.

## A1 — Install Flux

```bash
flux install
# or the Big Bang bootstrap script which installs a pinned Flux version:
# https://repo1.dso.mil/big-bang/bigbang  → docs/assets/scripts/install_flux.sh
```

## A2 — Give Big Bang its config

Big Bang is configured through a values file that toggles which packages ("addons") are on. Minimal `bigbang-values.yaml`:

```yaml
# bigbang-values.yaml — turn the platform stack on/off here
istio:
  enabled: true
istioOperator:
  enabled: true
monitoring:        # Prometheus + Grafana
  enabled: true
loki:              # logs
  enabled: true
kiali:             # mesh UI
  enabled: true
kyverno:           # policy engine
  enabled: true
kyvernoPolicies:
  enabled: true
# turn off heavy ones you don't need for a demo:
clusterAuditor:
  enabled: false
neuvector:
  enabled: false
```

## A3 — Deploy Big Bang via Flux

Big Bang is hosted on Repo1 (DoD's GitLab), not GitHub. You point a Flux `HelmRelease` at the Big Bang chart:

```yaml
# bigbang-release.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: bigbang
  namespace: bigbang
spec:
  interval: 5m
  url: https://repo1.dso.mil/big-bang/bigbang.git
  ref:
    tag: 2.x.x          # ← check repo1.dso.mil/big-bang/bigbang/-/releases
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: bigbang
  namespace: bigbang
spec:
  interval: 5m
  chart:
    spec:
      chart: ./chart
      sourceRef:
        kind: GitRepository
        name: bigbang
  valuesFrom:
    - kind: Secret
      name: bigbang-values   # your bigbang-values.yaml stored as a secret
```

```bash
kubectl create namespace bigbang
kubectl create secret generic bigbang-values \
  -n bigbang --from-file=values.yaml=bigbang-values.yaml
kubectl apply -f bigbang-release.yaml

# watch Flux install the whole platform (10–20 min)
watch kubectl get helmreleases -A
```

When it settles you'll have `istio-system`, `monitoring`, `logging`, `kiali`, `kyverno` namespaces all populated — installed and continuously reconciled by Flux.

## A4 — Deploy your sample app on Big Bang (the GitOps way)

You add the app to Git as a `HelmRelease`. I'll use **podinfo** (a standard demo app) so it's runnable. Commit this to the repo Flux watches:

```yaml
# apps/podinfo.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: podinfo
  namespace: podinfo
spec:
  interval: 10m
  url: https://stefanprodan.github.io/podinfo
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: podinfo
spec:
  interval: 5m
  chart:
    spec:
      chart: podinfo
      version: "6.x.x"
      sourceRef:
        kind: HelmRepository
        name: podinfo
  values:
    replicaCount: 2
```

Then expose it through the Istio gateway Big Bang already installed — exactly the Gateway + VirtualService pattern from your networking guide:

```yaml
# apps/podinfo-routing.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: podinfo-gw
  namespace: podinfo
spec:
  selector:
    istio: ingressgateway      # matches the Big Bang ingress gateway pod label
  servers:
  - port: { number: 80, name: http, protocol: HTTP }
    hosts: ["podinfo.bigbang.dev"]
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: podinfo-vs
  namespace: podinfo
spec:
  hosts: ["podinfo.bigbang.dev"]
  gateways: ["podinfo-gw"]
  http:
  - route:
    - destination:
        host: podinfo          # the K8s Service name
        port: { number: 9898 }
```

```bash
git add apps/ && git commit -m "deploy podinfo" && git push
# Flux notices the commit and deploys it. You never run kubectl apply for the app.
kubectl get pods -n podinfo
```

---

# Path B — UDS Core on EKS

UDS's model: everything (charts **and** container images) is bundled into a **Zarf package**. You `uds deploy` it. No Flux required. This is what makes it air-gap-capable.

## B1 — Install UDS Core on the EKS cluster

The `k3d-core-demo` bundle you saw in the docs creates its *own* k3d cluster — don't use that on EKS. For an existing cluster like EKS, you deploy the **core** package onto your current kube-context:

```bash
# kubeconfig already points at EKS from Step 1
uds deploy core:latest        # check github.com/defenseunicorns/uds-core/releases for the tag

# deploy a specific version:
# uds deploy core:0.4x.x
```

This unpacks Istio, Keycloak (SSO), Pepr-based UDS Operator, the policy engine, and the monitoring/logging baseline onto your EKS nodes. Watch it:

```bash
uds zarf tools monitor          # bundled k9s
kubectl get pods -A
```

Production note: on a real EKS install you supply a `uds-config.yaml` for domain, certs, and (importantly) point Loki/object storage at **S3** instead of the demo's bundled MinIO.

## B2 — Deploy your sample app on UDS Core (the package way)

You wrap the app as a Zarf package, then a UDS bundle. First the app's `zarf.yaml`:

```yaml
# zarf.yaml — bundles the chart AND the image (so it works offline)
kind: ZarfPackageConfig
metadata:
  name: podinfo
  version: 0.0.1
components:
  - name: podinfo
    required: true
    charts:
      - name: podinfo
        url: https://stefanprodan.github.io/podinfo
        version: 6.x.x
        namespace: podinfo
    images:
      - ghcr.io/stefanprodan/podinfo:6.x.x   # baked into the package
```

```bash
uds zarf package create .
# produces zarf-package-podinfo-amd64-0.0.1.tar.zst — images included
```

Then a UDS `Package` custom resource tells the UDS Operator how to wire Istio/SSO/network policy automatically — this is UDS's nicer replacement for hand-writing VirtualServices:

```yaml
# uds-package-podinfo.yaml
apiVersion: uds.dev/v1alpha1
kind: Package
metadata:
  name: podinfo
  namespace: podinfo
spec:
  network:
    expose:
      - service: podinfo
        selector:
          app.kubernetes.io/name: podinfo
        host: podinfo            # → podinfo.<your-domain>
        gateway: tenant
        port: 9898
```

```bash
uds zarf package deploy zarf-package-podinfo-amd64-0.0.1.tar.zst
kubectl apply -f uds-package-podinfo.yaml
kubectl get pods,svc -n podinfo
```

The UDS Operator reads that `Package` CR and generates the Istio VirtualService, the network policies (default-deny → allow this), and SSO hooks for you. That's the main day-to-day difference from Big Bang: **Big Bang you hand-write the Istio routing; UDS you declare a `Package` and the operator writes the routing.**

---

## Side-by-side of the two app deployments

| | Big Bang | UDS Core |
|---|---|---|
| Install platform | `flux install` → apply Big Bang `HelmRelease` | `uds deploy core:latest` |
| Platform source | Git repo on Repo1 (pulled by Flux) | Zarf package (pushed by CLI) |
| Deploy your app | `git commit` a `HelmRelease` → Flux deploys | `uds zarf package create` → `uds zarf package deploy` |
| Expose your app | hand-write Istio `Gateway` + `VirtualService` | declare a UDS `Package` CR; operator writes routing |
| Update your app | push new commit to Git | build + deploy new package version |
| Air-gap | harder (needs Git + image registry reachable) | first-class (images travel in the package) |
| Self-heals drift | yes (Flux reverts manual `kubectl` changes) | no continuous reconcile unless you add Flux |

## Cleanup (avoid AWS charges)

```bash
eksctl delete cluster --name platform-demo --region us-east-1
```

Both platforms are genuinely heavy, so if your goal is just to *learn the mechanics* rather than test EKS specifically, the fastest path is the local k3d bundles (`uds deploy k3d-core-demo:latest` for UDS; the k3d dev setup for Big Bang) — same concepts, no AWS bill.

Want me to put this whole thing into a single downloadable runbook file (markdown), or expand either path into a fuller production-grade config (real domains, S3-backed Loki, AWS LB Controller wiring)?
