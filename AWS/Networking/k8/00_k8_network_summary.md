## Brief Summary — AWS VPC CNI, Custom Networking, and Prefix Delegation

AWS VPC CNI gives each Kubernetes Pod a real VPC IP address. This makes Pod networking simple and AWS-native, but it also creates two major limits.

---

## 1. Why there is a Pod IP limit per node

Each EC2 instance has two important limits:

```text
1. How many ENIs/NICs can attach to the instance
2. How many IP addresses each ENI can hold
```

Example:

```text
m5.large:
- Max ENIs: 3
- Max IPv4 addresses per ENI: 10
```

Each ENI must have one **primary IP**.

```text
Primary ENI:
- Primary IP = Node IP
- Secondary IPs = Pod IPs

Secondary ENI:
- Primary IP = required by AWS, usually not used by Pods
- Secondary IPs = Pod IPs
```

So Pod capacity is limited by:

```text
Number of ENIs × IPs per ENI
```

This means the EC2 instance may still have CPU and memory available, but Kubernetes cannot schedule more Pods because the node has no more available Pod IPs.

---

## 2. Default VPC CNI behavior

In default mode:

```text
Node IP comes from primary subnet
Pod IPs also come from primary subnet
```

Example:

```text
VPC/Subnet: 10.0.1.0/24

Node IP: 10.0.1.10
Pod-1:   10.0.1.11
Pod-2:   10.0.1.12
Pod-3:   10.0.1.13
```

Problem:

```text
Pods consume the same VPC CIDR space as nodes, load balancers, endpoints, databases, and other AWS resources.
```

This can cause **VPC/subnet IP exhaustion**.

---

## 3. Custom Networking solves the address exhaustion problem

Custom networking lets you separate node IPs and Pod IPs.

```text
Node IPs come from primary VPC CIDR
Pod IPs come from secondary VPC CIDR
```

Example:

```text
Primary CIDR:   10.0.0.0/16
Secondary CIDR: 100.64.0.0/16

Node IP: 10.0.1.10
Pod-1:   100.64.1.11
Pod-2:   100.64.1.12
Pod-3:   100.64.1.13
```

Key point:

```text
Custom Networking solves VPC IP exhaustion by moving Pod IPs to a separate secondary CIDR.
```

This is useful when the enterprise wants to preserve routable/private IP space like `10.x.x.x` for nodes and infrastructure, while Pods use a large non-routable/CGNAT-style range such as `100.64.0.0/10`.

But custom networking does **not** mainly solve Pod density per node. In fact, it can reduce default Pod capacity because the primary ENI is no longer used for normal Pod IP allocation.

---

## 4. Prefix Delegation solves a different problem: Pod density

Prefix delegation does not primarily solve VPC CIDR exhaustion.

It solves this problem:

```text
The node has CPU and memory left, but it cannot run more Pods because the ENI IP slots are full.
```

Without prefix delegation:

```text
1 ENI slot = 1 secondary IP = 1 Pod IP
```

With prefix delegation:

```text
1 ENI slot = 1 /28 prefix = 16 Pod IPs
```

Example:

```text
Without prefix delegation:
ENI slot gives: 10.0.1.11
Only 1 Pod can use it

With prefix delegation:
ENI slot gives: 10.0.1.16/28
Up to 16 Pod IPs come from that prefix
```

Key point:

```text
Prefix Delegation increases how many Pod IPs a node can support without attaching many more ENIs.
```

It improves:

```text
- Pod density per node
- Pod startup speed
- ENI/IP allocation efficiency
- Scale-out performance
```

---

## 5. The simple difference

| Feature                                   | Problem it solves                           | What it changes                                     |
| ----------------------------------------- | ------------------------------------------- | --------------------------------------------------- |
| **Default VPC CNI**                       | Basic Pod networking                        | Pods get IPs from same subnet as node               |
| **Custom Networking**                     | VPC/subnet IP exhaustion                    | Pods get IPs from secondary CIDR                    |
| **Prefix Delegation**                     | Per-node Pod density limit                  | ENI slot holds a `/28` prefix instead of one IP     |
| **Custom Networking + Prefix Delegation** | Large-scale EKS IPv4 exhaustion and density | Pods use secondary CIDR and nodes support more Pods |

---

## 6. Best mental model

```text
ENI limit = how many network cards the EC2 instance can have

IP-per-ENI limit = how many IP slots each network card can hold

Default VPC CNI = each Pod consumes one IP from the node subnet

Custom Networking = move Pod IPs to a secondary CIDR, such as 100.64.x.x

Prefix Delegation = each ENI slot gives a block of 16 Pod IPs instead of one Pod IP
```

---

## 7. One-line takeaway

**Custom Networking solves the “I am running out of VPC/subnet IP addresses because Pods consume too many IPs” problem. Prefix Delegation solves the “my EC2 node cannot run more Pods because ENI IP slots are limited” problem.**
