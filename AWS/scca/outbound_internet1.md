Below is an updated version of the example, which explicitly shows which Transit Gateway (TGW) attachments are associated with which TGW route tables. This is a common pattern for a “central inspection” design using AWS Network Firewall and multiple VPCs.

Use the following as a reference and adapt to your exact CIDRs, naming conventions, and whether you have additional VPC attachments (for example, on-premises VPN, Direct Connect, or additional spoke VPCs).

Overview of TGW Route Table Associations
Pre-Inspection Route Table

Associations: All Spoke VPC attachments (e.g., Spoke-A, Spoke-B, etc.)
Purpose: For any traffic leaving a spoke that must go to the internet or other external networks, routes direct the traffic to the Inspection VPC. Spoke-to-spoke traffic can bypass the firewall if desired.
Post-Inspection Route Table

Associations: Inspection VPC attachment (in “appliance mode” if needed)
Purpose: Traffic returning from the firewall flows into this route table. Based on the destination, the traffic either goes back to the relevant spoke VPC or proceeds to the Egress VPC for internet egress.
Pre-Inspection-Egress Route Table (optional, used for symmetrical return inspection from the internet)

Associations: Egress VPC attachment
Purpose: Inbound traffic from the internet that arrives in the Egress VPC is sent back to the Inspection VPC for inspection before being forwarded on to the spokes.
In some simpler designs, you might merge “Pre-Inspection-Egress” logic into the same Post-Inspection table or skip it entirely if inbound traffic inspection is not required. But below is a more explicit version that handles both inbound and outbound inspection.

1) Spoke VPCs: Route Tables & TGW Attachment Associations
A. Spoke VPC Route Table
For each Spoke VPC (e.g., “Spoke-A,” “Spoke-B”), the typical private subnets use a route table such as:

Spoke-A (Private Subnet Route Table)
Destination         | Target
--------------------|-----------------------------------------
10.10.0.0/16        | local        (Spoke-A’s own CIDR)
0.0.0.0/0           | tgw-attach-A (associated with Pre-Inspection RT)
The TGW attachment for Spoke-A is associated with the Pre-Inspection route table on the Transit Gateway.
You will repeat a similar pattern for Spoke-B, Spoke-C, etc.

2) TGW: “Pre-Inspection” Route Table
Associated Attachments:

Spoke-A
Spoke-B
(Any other Spoke VPCs)
Potentially VPN or Direct Connect attachments if those also need to be inspected.
Routes (example):

Pre-Inspection TGW Route Table
Destination         | Attachment
--------------------|-----------------------------------------
10.10.0.0/16        | Spoke-A (local route for that VPC)
10.20.0.0/16        | Spoke-B
... (other spokes)  | ...
0.0.0.0/0           | Inspection VPC Attachment
This means:

Traffic destined for another spoke (e.g., 10.20.0.0/16) goes directly to Spoke-B’s attachment (east–west).
Traffic destined for the internet (0.0.0.0/0) is forwarded to the Inspection VPC.
3) Inspection VPC Route Tables
Within the Inspection VPC, there are typically two sets of subnets (and thus two route tables):

3A. “TGW Subnet” Route Table (Inspection VPC)
This route table is attached to the subnets where the Transit Gateway ENIs live (the “TGW attachment subnets”).
When traffic arrives from the Transit Gateway, we want it to go to the firewall endpoint.
Inspection VPC – TGW Subnet Route Table
Destination         | Target
--------------------|-----------------------------------------
100.64.0.0/16       | local   (example: the Inspection VPC CIDR)
0.0.0.0/0           | Firewall Endpoint ENI
3B. “Firewall Subnet” Route Table (Inspection VPC)
This route table is attached to the subnets where the AWS Network Firewall endpoints live.
After traffic is inspected, it is sent back to the Transit Gateway (but on the Post-Inspection route table).
Inspection VPC – Firewall Subnet Route Table
Destination         | Target
--------------------|-----------------------------------------
100.64.0.0/16       | local
0.0.0.0/0           | TGW Attachment (associated with Post-Inspection RT)
4) TGW: “Post-Inspection” Route Table
Associated Attachment: Inspection VPC (in appliance mode if needed).
Routes (example):
Post-Inspection TGW Route Table
Destination         | Attachment
--------------------|-----------------------------------------
10.10.0.0/16        | Spoke-A
10.20.0.0/16        | Spoke-B
... (other spokes)  | ...
0.0.0.0/0           | Egress VPC
This means that any traffic that has passed the firewall and is bound for the internet (0.0.0.0/0) is forwarded to the Egress VPC. Traffic returning to spokes is forwarded to the respective spoke attachments.

5) Egress VPC Route Tables & TGW Attachment
For north–south flows, you typically have:

Private subnets (where you might place additional resources or route your egress traffic to NAT Gateways).
Subnets hosting NAT Gateways (the “public” side with an IGW).
A Transit Gateway attachment subnet (optional if you keep them separate).
Below is a common pattern:

5A. Egress VPC – Private Subnet Route Table
Egress VPC – Private Subnet RT
Destination         | Target
--------------------|-----------------------------------------
10.0.0.0/8          | tgw-attach-egress (assoc. w/ Pre-Inspection-Egress or Post-Inspection RT)
(Or your internal 
  supernet range)  
0.0.0.0/0           | NAT Gateway
5B. Egress VPC – NAT Gateway Subnet Route Table
Egress VPC – NAT GW Subnet RT
Destination         | Target
--------------------|-----------------------------------------
10.0.0.0/8          | tgw-attach-egress
0.0.0.0/0           | IGW
The IGW does source NAT for outbound traffic, so the return traffic from the internet hits the NAT Gateway’s ENI first. The route table on that subnet routes return traffic back to the Transit Gateway if the destination is internal.

5C. TGW: “Pre-Inspection-Egress” Route Table (Optional)
Associated Attachment: Egress VPC
Routes might look like:
Pre-Inspection-Egress TGW Route Table
Destination         | Attachment
--------------------|-----------------------------------------
(Egress VPC CIDR)   | Egress VPC
0.0.0.0/0           | Inspection VPC
Inbound traffic from the internet that hits the Egress VPC then routes to the Transit Gateway. The Transit Gateway sees that the Egress VPC attachment is associated with Pre-Inspection-Egress. Because the default route (0.0.0.0/0) in that table points to the Inspection VPC, inbound flows go into the firewall for inspection. Traffic that passes inspection is then returned to the Post-Inspection route table to reach the Spokes.

Final Summary of TGW Attachments and Associations
Here is a concise reference of which VPC attachment is associated with which TGW route table:

Spoke-A, Spoke-B, …
Associated: Pre-Inspection TGW Route Table
Inspection VPC
Associated: Post-Inspection TGW Route Table (and set attachment to “appliance mode” if your design requires symmetric flows)
Egress VPC
Associated: Pre-Inspection-Egress TGW Route Table (for inbound flows returning from IGW; optional if you need symmetrical inbound inspection)
Depending on your exact design, you might collapse the egress logic into just the Post-Inspection table, or you may have separate route tables for inbound vs. outbound flows. The above layout is a common and explicit approach that clearly separates “pre-inspection” spokes, “post-inspection” firewall routes, and “pre-inspection-egress” inbound routing.
