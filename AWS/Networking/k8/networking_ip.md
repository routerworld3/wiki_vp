# Conserving VPC IP Space for K8s/Istio Mission Owners on AWS

Great question — this is one of the classic IP exhaustion problems on EKS,

## The core problem

By default, the **AWS VPC CNI** assigns every pod a **routable VPC IP** from your subnet CIDR. With Istio you also get a sidecar per pod, but sidecars share the pod's IP — so Istio itself doesn't double IP consumption. The real driver is pod density: a node running 50 pods consumes ~50 VPC IPs plus warm-pool ENI IPs. Multiply across mission owners and 10.0.0.0/8 disappears faster than you'd expect.

## Option 1 — Custom Networking with Secondary CIDR (the standard AWS pattern)

This is the canonical AWS-recommended approach and directly addresses your concern.

**How it works:**
1. Attach a **secondary CIDR** from the **100.64.0.0/10** CGNAT range to the VPC (AWS explicitly supports this — RFC 6598 space is allowed as a secondary CIDR).
2. Create subnets in the 100.64.x.x range.
3. Enable **VPC CNI custom networking**: `AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true` and define `ENIConfig` CRDs per AZ pointing at the 100.64 subnets.
4. **Nodes** stay on the routable 10.0.0.0/8 CIDR. **Pods** get IPs from 100.64.0.0/10.

**The key property you asked about:** Each mission owner gets their own EKS cluster (or node group) with its own 100.64.x.x secondary CIDR. Because pod IPs are **not advertised outside the VPC** — pods reach the outside world via SNAT to the node's primary VPC IP — different mission owners *can* reuse overlapping 100.64 ranges. The pod IPs are effectively private to each cluster.

**Caveats:**
- East-west pod-to-pod traffic *across* mission-owner VPCs won't work directly if CIDRs overlap — you'd need an Istio multi-cluster setup with east-west gateways (which terminate at node IPs, not pod IPs), or Transit Gateway with NAT, to bridge them.
- Make sure `AWS_VPC_K8S_CNI_EXTERNALSNAT=false` (the default) so egress SNATs to the node IP.

## Option 2 — Prefix Delegation (reduce ENI IP waste, keep VPC CIDR)

If you want to stay entirely within 10.0.0.0/8 but stop the CNI from over-allocating warm IPs, enable **prefix delegation**: `ENABLE_PREFIX_DELEGATION=true`. The CNI then allocates `/28` prefixes (16 IPs) per ENI slot instead of individual IPs. Pod density per node goes way up (e.g. an m5.large jumps from 29 to 110 pods) and warm-pool waste drops dramatically.

This doesn't *solve* CIDR exhaustion the way CGNAT does, but it's a cheap win you can stack on top of Option 1.

## Option 3 — Alternative CNI (Calico, Cilium) with overlay/VXLAN

Run a CNI that uses an **overlay network** for pods. Pod IPs come from a cluster-internal CIDR that's never on the VPC at all. Different mission owners trivially reuse the same pod CIDR because the VPC never sees those IPs. Egress SNATs to the node.

Trade-offs: small encapsulation overhead, you lose the "pod IP = VPC IP" property (which some AWS-native integrations like security groups for pods rely on), and you take on operating a non-default CNI.

## Mission-owner governance (orthogonal but important)

Whichever networking option you pick, put guardrails on consumption:

- **ResourceQuotas** per namespace capping pod count
- **LimitRanges** so a single deployment can't scale to thousands of replicas
- **Right-sized subnets** per mission owner — give each one a fixed `/20` or `/22` from the secondary CIDR rather than letting them dip into a shared pool
- **One EKS cluster per mission owner** (or at minimum, one node group per mission owner with dedicated subnets) — this is what makes 100.64 reuse safe

## Recommended pattern for your situation

For multi-tenant mission-owner isolation on AWS with 10.0.0.0/8 conservation:

Nodes on a small slice of 10.0.0.0/8 (say a `/20` per cluster — only need IPs for nodes, LBs, ENIs). Pods on **100.64.0.0/10 secondary CIDR** via VPC CNI custom networking, with each mission owner's cluster getting an isolated 100.64 range — and yes, ranges *can* overlap across mission owners as long as east-west pod traffic between them is mediated by gateways (Istio east-west gateway, ALB, or NAT). Add prefix delegation to reduce warm-IP waste. Enforce ResourceQuotas per namespace.

This gives you the CGNAT-style "pod IPs aren't directly exposed, so reuse is fine" property you described, while keeping your routable 10.0.0.0/8 space for things that actually need to be reachable.

Want me to sketch the actual `ENIConfig` YAML and the VPC CNI environment variables, or dig into how Istio multi-cluster east-west gateways work when pod CIDRs overlap?

I'll search for the official AWS documentation on this.Let me also pull the AWS blog on private NAT gateway with overlapping CIDRs, since that's the key reference for your multi-mission-owner reuse scenario.I have the official AWS sources. Here's the AWS-recommended approach with proper references.

# AWS Recommended Method for Mission-Owner IP Conservation

Your instinct is exactly the AWS-recommended pattern. There are **two official AWS documents** that together describe this end-to-end, plus one whitepaper that ties it into multi-VPC architecture.

## The two AWS recommendations (and what each covers)

**1. CNI Custom Networking — solves IP exhaustion *within* a single mission-owner cluster**

From the [Amazon EKS Best Practices Guide — Custom Networking](https://docs.aws.amazon.com/eks/latest/best-practices/custom-networking.html):

Custom networking addresses the IP exhaustion issue by assigning the node and Pod IPs from secondary VPC address spaces (CIDR). Custom networking support supports ENIConfig custom resource. The ENIConfig includes an alternate subnet CIDR range (carved from a secondary VPC CIDR), along with the security group(s) that the Pods will belong to.

AWS explicitly recommends CGNAT space for the secondary CIDR: while custom networking will accept valid VPC range for secondary CIDR range, we recommend that you use CIDRs (/16) from the CG-NAT space, i.e. 100.64.0.0/10 or 198.19.0.0/16 as those are less likely to be used in a corporate setting than other RFC1918 ranges.

The official tutorial with the actual `ENIConfig` YAML and the `AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true` setup is here: [Customize the secondary network interface in Amazon EKS nodes](https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network-tutorial.html) and [Deploy Pods in alternate subnets with custom networking](https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network.html).

**2. Private NAT Gateway + Transit Gateway — solves communication *between* mission-owner clusters that reuse the same 100.64 range**

This is the second half of your question and where the "different mission owners can share the same IP space" pattern is officially blessed. The canonical AWS blog post is [Addressing IPv4 address exhaustion in Amazon EKS clusters using private NAT gateways](https://aws.amazon.com/blogs/containers/addressing-ipv4-address-exhaustion-in-amazon-eks-clusters-using-private-nat-gateways/) (Jan 2023):

This post highlights the advantages of implementing a network architecture with a private NAT Gateway to deploy an Amazon EKS cluster. We demonstrate a use case where workloads deployed in an Amazon EKS cluster provisioned in a VPC (VPC-A) are made to communicate, using a private NAT gateway, with workloads deployed to another Amazon EKS cluster in a different VPC (VPC-B) with overlapping CIDR ranges. The routable address range (address ranges that cannot overlap) chosen here is 192.168.0.0/16 and the non-routable address range (address ranges that can overlap) is 100.64.0.0/16.

There's a working reference implementation on GitHub: [aws-samples/eks-private-nat-gateway](https://github.com/aws-samples/eks-private-nat-gateway), which demonstrates a use case where workloads deployed in an EKS cluster provisioned in a VPC are made to communicate, using a private NAT gateway, with workloads deployed to another EKS cluster in a different VPC with overlapping CIDR ranges. The sample sets up VPC-A with routable 192.168.16.0/20 + non-routable 100.64.0.0/16, and VPC-B with routable 192.168.32.0/20 + the *same* non-routable 100.64.0.0/16.

The earlier AWS Networking blog [How to solve Private IP exhaustion with Private NAT Solution](https://aws.amazon.com/blogs/networking-and-content-delivery/how-to-solve-private-ip-exhaustion-with-private-nat-solution/) (Sept 2021) frames the broader pattern that is the foundation for the EKS-specific blog: if a business unit in an organization wishes to deploy a workload that demands the use of thousands of IP addresses, the workload will be deployed on the non-routable IP address range. The non-routable IP space is used by many other business units and the overlapping nature of this space makes it non-routable. The workload will be assigned a small routable IP address range by the centralized IP Address Management (IPAM) team. This is exactly your mission-owner-A / mission-owner-B model.

## How AWS recommends splitting the address space

This is the architectural pattern you should put in front of your mission owners:

| Address space | Purpose | Mission-owner sharing |
|---|---|---|
| **Routable** (small slice of 10.0.0.0/8, e.g. /20 or /24 per VPC) | Nodes, NAT gateways, ALBs/NLBs, VPC endpoints — anything that needs to be reachable from outside the VPC | **Must be unique** — IPAM team allocates |
| **Non-routable** (100.64.0.0/10 or 198.19.0.0/16) | Pod IPs via CNI custom networking | **Can overlap** across mission owners |

AWS's framing in the [Cloud WAN service insertion blog](https://aws.amazon.com/blogs/networking-and-content-delivery/addressing-private-ipv4-exhaustion-with-aws-cloud-wan-service-insertion/) (June 2025) makes the design intent explicit: the approach is based on assigning a private IPv4 range that is routable only within your AWS environment and deploying centralized NAT and PrivateLink at the level rather than at the VPC level. They specifically suggest carving 100.64.0.0/10 into /12 slices per Region.

## What the data plane looks like

Concretely, per the AWS EKS Best Practices guide: the primary Elastic Network Interface (ENI) of the worker node still uses the primary VPC CIDR range (in this case 10.0.0.0/16) but the secondary ENIs use the secondary VPC CIDR Range (in this case 100.64.0.0/16). Now, in order to have the Pods use the 100.64.0.0/16 CIDR range, you must configure the CNI plugin to use custom networking.

For the cross-mission-owner communication piece, the [AWS multi-VPC whitepaper](https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/private-nat-gateway.html) describes the exact mechanic: a private NAT gateway is added to the routable subnet in VPC A with an IP address of 10.0.1.125. The private NAT gateway performs source network address translation on requests from instances in non-routable subnet of VPC A (100.64.0.10) as 10.0.1.125, the ENI of the private NAT gateway. Now traffic can be pointed to a routable IP address assigned to the Application Load Balancer (ALB) in VPC B (10.0.2.10), which has a target of 100.64.0.10. Traffic is routed through Transit Gateway. A pod in mission-owner-A's 100.64.x.x reaches mission-owner-B's pod by going through MO-A's private NAT GW (which translates the source to MO-A's routable IP), across TGW, into MO-B's routable subnet, and then to MO-B's ALB which fronts the pods. Both sides can reuse 100.64.0.0/16 because pod IPs never appear on the wire between VPCs.

One important caveat AWS calls out — custom networking alone doesn't solve cross-VPC overlap: consider utilizing the method described on this blog post to employ a private NAT gateway to overcome communication issues for the EKS workloads caused by overlapping CIDRs, a significant complaint expressed by our clients. Custom networking cannot address the overlapping CIDR difficulties on its own, and it adds to the configuration challenges. You need both pieces together for the multi-mission-owner story.

## The full reference list

| # | Document | What it gives you |
|---|---|---|
| 1 | [EKS Best Practices — Custom Networking](https://docs.aws.amazon.com/eks/latest/best-practices/custom-networking.html) | Why use 100.64, when not to use it, design considerations |
| 2 | [EKS User Guide — CNI custom network tutorial](https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network-tutorial.html) | Step-by-step: secondary CIDR, subnets, ENIConfig, env vars |
| 3 | [EKS User Guide — Deploy Pods in alternate subnets](https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network.html) | Reference doc for the feature |
| 4 | [AWS Containers Blog — Addressing IPv4 exhaustion using private NAT gateways](https://aws.amazon.com/blogs/containers/addressing-ipv4-address-exhaustion-in-amazon-eks-clusters-using-private-nat-gateways/) | The mission-owner-A ↔ mission-owner-B reuse pattern, end-to-end |
| 5 | [GitHub — aws-samples/eks-private-nat-gateway](https://github.com/aws-samples/eks-private-nat-gateway) | Working CloudFormation/scripts for the above |
| 6 | [AWS Networking Blog — Private IP exhaustion with Private NAT](https://aws.amazon.com/blogs/networking-and-content-delivery/how-to-solve-private-ip-exhaustion-with-private-nat-solution/) | The original "routable vs non-routable" framing for business units |
| 7 | [AWS Whitepaper — Multi-VPC network infrastructure: Private NAT Gateway](https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/private-nat-gateway.html) | Architectural reference for the overall pattern |
| 8 | [AWS Containers Blog — EKS routable IP conservation in hybrid networks](https://aws.amazon.com/blogs/containers/eks-vpc-routable-ip-address-conservation/) | The Shared Services VPC + dual-TGW variant for hybrid (on-prem) connectivity |

If you want to give mission owners a one-page architecture document, the **[Containers blog post (#4) plus the GitHub sample (#5)](https://aws.amazon.com/blogs/containers/addressing-ipv4-address-exhaustion-in-amazon-eks-clusters-using-private-nat-gateways/)** is the most direct match for what you described — workloads in two clusters with the same 100.64 pod range, communicating via private NAT + TGW, while only consuming small routable allocations from your 10.0.0.0/8.

Want me to sketch the IPAM allocation table (e.g. /22 routable per mission owner from 10.0.0.0/8, with 100.64.0.0/16 reusable as pod space) so you have something concrete to circulate?
