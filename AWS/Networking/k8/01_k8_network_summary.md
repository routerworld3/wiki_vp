Yes — add this section to your summary.

## How to Enable EKS VPC CNI Custom Networking

Custom networking is enabled by configuring the AWS VPC CNI so that **Pod IPs come from alternate subnets**, usually subnets created from a secondary VPC CIDR such as `100.64.0.0/16` or another non-overlapping range.

AWS uses an `ENIConfig` Kubernetes custom resource to tell the CNI:

```text
For nodes in this Availability Zone,
create secondary ENIs in this subnet,
and use this security group for Pod ENIs.
```

AWS states that when custom networking is enabled, the VPC CNI creates secondary ENIs in the subnet defined in `ENIConfig`, and Pods receive IPs from that ENIConfig subnet. ([AWS Documentation][1])

---

## High-Level Enablement Steps

### Step 1 — Add secondary CIDR to the VPC

Example:

```text
Primary VPC CIDR:    10.0.0.0/16
Secondary VPC CIDR:  100.64.0.0/16
```

The primary CIDR continues to be used for:

```text
EC2 node primary ENI
node IP
kubelet
hostNetwork Pods
load balancers
VPC endpoints
```

The secondary CIDR is used for:

```text
Pod ENIs
Pod IPs
secondary ENIs created by AWS VPC CNI
```

---

### Step 2 — Create Pod subnets from the secondary CIDR

Create one Pod subnet per Availability Zone.

Example:

```text
AZ-a Pod subnet: 100.64.1.0/24
AZ-b Pod subnet: 100.64.2.0/24
AZ-c Pod subnet: 100.64.3.0/24
```

These subnets should be in the **same AZs** as your worker nodes.

Example mapping:

```text
Node subnet us-east-1a: 10.0.1.0/24
Pod subnet  us-east-1a: 100.64.1.0/24

Node subnet us-east-1b: 10.0.2.0/24
Pod subnet  us-east-1b: 100.64.2.0/24
```

---

### Step 3 — Enable custom networking in the `aws-node` DaemonSet

Run:

```bash
kubectl set env daemonset aws-node \
  -n kube-system \
  AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
```

This tells the AWS VPC CNI:

```text
Do not assign normal Pod IPs from the node primary subnet.
Use ENIConfig-defined subnets instead.
```

AWS documents this environment variable as the switch that enables custom networking. ([AWS Documentation][1])

---

### Step 4 — Tell CNI how to choose the right ENIConfig

The common production method is to use the node’s Availability Zone label.

```bash
kubectl set env daemonset aws-node \
  -n kube-system \
  ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone
```

This tells the CNI:

```text
Look at the node AZ label.
If node is in us-east-1a, use ENIConfig named us-east-1a.
If node is in us-east-1b, use ENIConfig named us-east-1b.
```

---

### Step 5 — Create one `ENIConfig` per Availability Zone

Example for `us-east-1a`:

```yaml
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: us-east-1a
spec:
  securityGroups:
    - sg-0123456789abcdef0
  subnet: subnet-aaa11111111111111
```

Example for `us-east-1b`:

```yaml
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: us-east-1b
spec:
  securityGroups:
    - sg-0123456789abcdef0
  subnet: subnet-bbb22222222222222
```

Apply them:

```bash
kubectl apply -f eni-us-east-1a.yaml
kubectl apply -f eni-us-east-1b.yaml
```

Verify:

```bash
kubectl get eniconfigs
```

Expected:

```text
NAME         AGE
us-east-1a   2m
us-east-1b   2m
```

---

## Does AWS assign the secondary NIC automatically?

Yes.

You do **not** manually attach the secondary NIC/ENI to the EC2 instance.

Once custom networking is enabled and `ENIConfig` exists, the AWS VPC CNI daemon `ipamd` automatically does this:

```text
1. Pod is scheduled to a node.
2. CNI checks if the node has available Pod IPs.
3. If not, CNI looks at the node's ENIConfig.
4. CNI creates/attaches a secondary ENI in the ENIConfig subnet.
5. CNI assigns secondary IPs, or prefixes if prefix delegation is enabled, to that ENI.
6. Pod receives an IP from that secondary ENI.
```

AWS documentation says the VPC CNI plugin creates secondary network interfaces for the EC2 node, and with custom networking it creates those secondary ENIs in the subnet defined by the `ENIConfig`. ([AWS Documentation][2])

So the answer is:

```text
Secondary ENI/NIC = automatically created and attached by AWS VPC CNI.
Pod IPs = automatically assigned from the ENIConfig subnet.
You only define which subnet/security group to use.
```

---

## Before and After

### Before custom networking

```text
Node subnet: 10.0.1.0/24

Primary ENI:
  Node IP: 10.0.1.10

Pod IPs:
  10.0.1.11
  10.0.1.12
  10.0.1.13
```

Problem:

```text
Pods consume the same subnet as nodes.
```

---

### After custom networking

```text
Node subnet: 10.0.1.0/24
Pod subnet:  100.64.1.0/24

Primary ENI:
  Node IP: 10.0.1.10

Secondary ENI created automatically by CNI:
  ENI subnet: 100.64.1.0/24

Pod IPs:
  100.64.1.11
  100.64.1.12
  100.64.1.13
```

Result:

```text
Node keeps using 10.0.1.10.
Pods now consume 100.64.x.x addresses.
```

---

## Important Note: Existing Nodes

For production clusters, do not assume existing running Pods will automatically move to the new Pod subnet.

Recommended approach:

```text
1. Enable custom networking.
2. Create ENIConfig resources.
3. Create new worker nodes.
4. Cordon and drain old nodes.
5. Let Pods reschedule onto new nodes.
6. Confirm new Pods receive secondary CIDR IPs.
7. Remove old nodes.
```

AWS notes that after creating `ENIConfig` resources, you need to create new worker nodes and drain existing nodes; existing worker nodes and Pods remain unaffected. ([AWS Documentation][1])

---

## Quick verification commands

Check `aws-node` settings:

```bash
kubectl describe daemonset aws-node -n kube-system | egrep \
'AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG|ENI_CONFIG_LABEL_DEF|ENABLE_PREFIX_DELEGATION'
```

Check ENIConfigs:

```bash
kubectl get eniconfigs
```

Check node AZ labels:

```bash
kubectl get nodes \
  -L topology.kubernetes.io/zone
```

Check Pod IPs:

```bash
kubectl get pods -A -o wide
```

Expected after custom networking:

```text
NODE IPs: 10.x.x.x
POD IPs:  100.64.x.x
```

---

## Updated Key Point

```text
Custom Networking:
  Solves VPC/subnet IP exhaustion by moving Pod IPs to secondary CIDR subnets.

Secondary ENI:
  Automatically created and attached by AWS VPC CNI based on ENIConfig.

Prefix Delegation:
  Solves Pod density by assigning /28 prefixes to ENI slots instead of assigning one IP at a time.

Best large-scale design:
  Custom Networking + Prefix Delegation
  = Pods use secondary CIDR and nodes support more Pods.
```

[1]: https://docs.aws.amazon.com/eks/latest/best-practices/custom-networking.html?utm_source=chatgpt.com "Custom Networking - Amazon EKS"
[2]: https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network.html?utm_source=chatgpt.com "Deploy Pods in alternate subnets with custom networking"
