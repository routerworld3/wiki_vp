**Mission Owner IPv4 Allocation Policy** section near the top of the document, before the technical options. This makes the governance message clear before explaining the technical solution.

Here is a concise section you can add:

````markdown
# Mission Owner IPv4 Allocation Policy

## Purpose

Private IPv4 space is a shared enterprise resource. Each Mission Owner cannot assume that a large RFC1918 block, such as a `/16`, will be available for every application, platform, or EKS environment.

A `/16` provides approximately **65,536 IP addresses**, which is normally far more than required for application servers, load balancers, endpoints, and infrastructure components. If multiple Mission Owners request `/16` allocations, the enterprise will quickly run into private IPv4 exhaustion.

To prevent unnecessary IP consumption, Mission Owners should size their routable IPv4 requests based on actual workload requirements.

---

## Default Maximum Allocation

The default maximum routable IPv4 allocation for a Mission Owner environment should be:

```text
/20 maximum per Mission Owner environment
````

A `/20` provides approximately:

```text
4,096 IP addresses
```

This is generally sufficient for:

```text
EC2 worker nodes
Application servers
ALBs / NLBs
NAT gateways
VPC endpoints
Interface endpoints
Inspection or security appliances
Management components
Shared services inside the VPC
```

For most application and server workloads, a `/20` should be treated as the upper limit unless there is a validated technical reason for more space.

---

## Requests Larger Than /20

Any request larger than a `/20` must include written justification.

The justification should explain:

```text
Why more than 4,096 routable IP addresses are required
Expected number of servers or nodes
Expected number of load balancers
Expected number of VPC endpoints
Expected number of Kubernetes worker nodes
Expected number of routable services
Growth projection over 12–24 months
Why secondary CIDR, custom networking, NAT, or IPv6 cannot solve the requirement
```

A larger request should not be approved only because the Mission Owner wants future flexibility.

---

## Why /16 Requests Are a Problem

A `/16` allocation consumes a very large amount of private IPv4 space.

```text
/16 = ~65,536 IP addresses
/20 = ~4,096 IP addresses
```

One `/16` equals sixteen `/20` allocations.

```text
1 x /16 = 16 x /20
```

If every Mission Owner requests a `/16`, the enterprise private IPv4 pool will be exhausted quickly, even if the actual workload only needs a small fraction of that space.

This becomes especially problematic in EKS environments because, by default, Pods can consume VPC IP addresses directly. Without proper design, Kubernetes growth can consume routable IPv4 space much faster than traditional server-based applications.

---

## Recommended Direction for EKS / Kubernetes Workloads

Mission Owners deploying EKS or Kubernetes should not request a large routable CIDR only to support Pod growth.

Instead, they should use the enterprise EKS IP conservation pattern:

```text
Small routable CIDR for nodes, load balancers, endpoints, and infrastructure
Secondary CIDR such as 100.64.x.x for Pod IPs
AWS VPC CNI custom networking
Prefix delegation for Pod density
NAT, ALB, NLB, or Istio Gateway for cross-VPC communication
IPv6 evaluation for long-term modernization
```

Mission Owners should be directed to the EKS private IPv4 exhaustion design guidance, which explains how Pod IPs can be moved to secondary CIDR space while preserving routable IPv4 address space. This is especially important when multiple Mission Owners are deploying Kubernetes clusters and requesting large CIDR blocks.

---

## Policy Summary

```text
Default maximum routable allocation:
  /20 per Mission Owner environment

Requests larger than /20:
  Require written technical justification

/16 requests:
  Should not be approved by default

EKS / Kubernetes environments:
  Should use custom networking and secondary CIDR for Pod IPs

Goal:
  Preserve enterprise routable private IPv4 space and prevent exhaustion across Mission Owners
```

````

You can also add this shorter executive version at the beginning of the document:

```markdown
## Enterprise IPAM Position

Mission Owners should not request `/16` routable IPv4 allocations by default. A `/16` provides approximately 65,536 IP addresses and creates an enterprise-wide IPv4 exhaustion risk when repeated across multiple Mission Owners.

The default maximum routable IPv4 allocation should be `/20` per Mission Owner environment. Requests larger than `/20` must include technical justification, capacity estimates, and an explanation of why secondary CIDR, EKS custom networking, NAT/gateway patterns, or IPv6 cannot satisfy the requirement.

For EKS environments, Mission Owners should follow the private IPv4 exhaustion mitigation pattern described in this document: use a small routable CIDR for nodes and infrastructure, and use secondary CIDR space such as `100.64.x.x` for Pod IPs through AWS VPC CNI custom networking.
````

This aligns well with the earlier document’s key point: **routable IP space should be reserved for things that actually need to be reachable, while Pod growth should be handled through secondary CIDR/custom networking patterns**.
