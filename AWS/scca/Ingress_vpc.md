Below is the updated table without the “Routing/Inspection Flow” column. Each pattern shows a common Central Ingress approach where public-facing load balancers (ALB/NLB) reside in a central (Ingress) VPC/subnet, and the actual workloads run in the mission-owner VPC. 

---------------------------------------------------------------------------------------------------------
| Pattern No. | Ingress VPC Components                                     | Mission Owner Target Options                              | Notes                                                   |
|-------------|------------------------------------------------------------|-----------------------------------------------------------|---------------------------------------------------------|
| **1**       | • Public ALB in Central Ingress VPC (public subnets,       | • EC2 instance(s) in private subnets                      | • ALB in public subnets for external traffic.           |
|             |   internet gateway)                                        | • ECS/Fargate services (containers)                       | • Targets use IP-based (or ALB/NLB) target groups.      |
|             |                                                            | • Private ALB or NLB in the mission VPC                   | • Often combined with optional inspection in another VPC. |
| **2**       | • Public ALB in Central Ingress VPC (public subnets)       | • Amazon EKS workloads (containers)                       | • Targets can be any IP-based backend in the mission    |
|             |                                                            | • Self-managed Kubernetes cluster                         |   VPC. ALB target groups point to private subnets.      |
|             |                                                            | • Private ALB or NLB bridging services                    |                                                         |
| **3**       | • Public ALB in Central Ingress VPC with HTTP/HTTPS        | • Containers behind NLB (layer 4)                         | • Common when a second load balancer (private ALB/NLB)  |
|             |   listeners                                                | • EC2 instances behind ALB or NLB                         |   in the mission VPC handles internal routing or TLS.   |
| **4**       | • Public NLB in Central Ingress VPC (less common than ALB) | • EC2 or containers (layer 4 traffic)                     | • Useful for TCP/UDP-based services that do not require |
|             |                                                            |                                                           |   HTTP-specific features.                               |
| **5**       | • Public ALB (HTTPS termination) in Central Ingress VPC    | • EC2 or ECS tasks with TLS termination, or pass-through  | • ALB offloads SSL cert. Can re-encrypt traffic to the   |
|             |                                                            | • Private ALB or NLB in the mission VPC                   |   mission-owner VPC.                                   |
---------------------------------------------------------------------------------------------------------


How It Works at a High Level (With “Routing/Inspection Flow” Removed):
- A **public ALB/NLB** is deployed in the **central ingress VPC** (public subnets) to handle internet-facing traffic.  
- The load balancer’s **target group** references private resources in the **mission-owner VPC** (EC2 instances, container services, or even a secondary ALB/NLB).  
- **Optional**: Traffic can be inspected by AWS Network Firewall or a similar service in a dedicated inspection VPC before reaching the mission VPC.  

These patterns allow you to keep public-facing endpoints in a single central location while isolating the workloads in separate VPCs/accounts. citeturn0file0
