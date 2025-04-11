Below is an example of how you might lay out the Transit Gateway route tables, as well as the VPC (subnet) route tables, in a central-inspection design where:

• Each Spoke VPC is attached to the Transit Gateway (TGW) and associated to a **Pre-Inspection** route table.  
• The **Inspection VPC** has a TGW attachment in “appliance mode,” with subnets containing AWS Network Firewall endpoints.  
• Traffic approved by the firewall is returned to the Transit Gateway via a **Post-Inspection** route table, which then forwards to the Egress VPC for internet-bound flows.  
• Inbound flows from the internet come back from the Egress VPC through a “Pre-Inspection-Egress” route table so that the inspection can occur in both directions.

Below is one representative example in a “Route Table / Destination / Target or Attachment” style, along with the typical subnet/VPC associations. Adapt as needed for your exact CIDRs and naming.

---

## 1) Spoke VPC Route Tables

Each Spoke VPC typically has at least one private route table used by application subnets. The key routes look like this:

**Spoke VPC (e.g. Spoke-A) - Private Route Table**

- **Destination**: 10.10.0.0/16 (Spoke-A CIDR)  
  **Target**: local  
- **Destination**: 0.0.0.0/0  
  **Target**: Transit Gateway attachment (associated to Pre-Inspection TGW route table)  
- *(Optional if you want direct inter-subnet references)* More-specific routes for local subnets also point to local.

All traffic not local to the Spoke VPC is sent to the TGW (0.0.0.0/0 → TGW). East–west traffic (Spoke-A to Spoke-B) will stay within the transit gateway but avoid the firewall if the **Pre-Inspection** route table has direct routes between Spokes.

You will repeat something similar in **Spoke-B**, **Spoke-C**, etc.

---

## 2) Pre-Inspection TGW Route Table

All **Spoke VPC attachments** are associated to this table. It enforces that:

- Any traffic **bound for the internet** (0.0.0.0/0) goes to the Inspection VPC.
- Traffic **bound for another Spoke** VPC stays internal (so it does not go via firewall).

**Pre-Inspection TGW Route Table**  

- **Destination**: 10.10.0.0/16 (Spoke-A CIDR)  
  **Attachment**: Spoke-A VPC attachment  
- **Destination**: 10.20.0.0/16 (Spoke-B CIDR)  
  **Attachment**: Spoke-B VPC attachment  
- *(Repeat for however many spokes)*  
- **Destination**: 0.0.0.0/0  
  **Attachment**: Inspection VPC attachment  

This ensures that:

- Spoke-to-spoke traffic uses the direct routes (no firewall).
- Any default or internet-bound traffic goes to the Inspection VPC.

---

## 3) Inspection VPC Route Tables

Inside the Inspection VPC, you have subnets for the Transit Gateway attachment (TGW ENIs) and subnets for the AWS Network Firewall endpoints. Typically you will have at least two route tables:

### 3a) TGW Subnet Route Table (in Inspection VPC)

This is the route table associated to the subnets containing the **Transit Gateway** ENIs in the Inspection VPC. Here, any traffic arriving from the TGW will be forwarded to the firewall endpoints. For example:

**Inspection VPC – TGW Subnet Route Table**

- **Destination**: 100.64.0.0/16 (Inspection VPC CIDR, example)  
  **Target**: local  
- **Destination**: 0.0.0.0/0  
  **Target**: AWS Network Firewall endpoint (i.e. the firewall’s ENI)  

Depending on your exact subnets, you might also add more-specific internal routes. But the key is that the default route sends all traffic to the firewall endpoint for inspection.

### 3b) Firewall Endpoint Subnet Route Table (in Inspection VPC)

In an appliance-mode design, when traffic leaves the firewall’s ENI, you can send it **back to the TGW** on a different TGW route table (the Post-Inspection table), or to other local resources if needed. For strict north-south inspection, you often simply route everything back to the Transit Gateway, which then uses the **Post-Inspection** table.

**Inspection VPC – Firewall Subnet Route Table**

- **Destination**: 100.64.0.0/16 (Inspection VPC CIDR)  
  **Target**: local  
- **Destination**: 0.0.0.0/0  
  **Target**: Transit Gateway attachment (associated to Post-Inspection TGW route table)  

Thus, “clean” traffic that passes firewall rules is returned to the Transit Gateway via the Post-Inspection route table.

---

## 4) Post-Inspection TGW Route Table

This table receives traffic from the firewall, after inspection. It then must decide where to send it next. For **internet-bound** traffic, we typically send it to the Egress VPC. For “return” traffic heading back to the Spokes, we have routes that send the relevant Spoke CIDRs to the correct Spoke attachments.

**Post-Inspection TGW Route Table**  

- **Destination**: 10.10.0.0/16 (Spoke-A CIDR)  
  **Attachment**: Spoke-A VPC attachment  
- **Destination**: 10.20.0.0/16 (Spoke-B CIDR)  
  **Attachment**: Spoke-B VPC attachment  
- *(Etc. for all internal subnets)*  
- **Destination**: 0.0.0.0/0  
  **Attachment**: Egress VPC attachment  

---

## 5) Egress VPC Route Tables

In the Egress VPC, you typically have:

1. **Private subnets** hosting your NAT Gateways.
2. **NAT Gateway route table** (the “public” subnets for the NAT itself).
3. Possibly a TGW subnet for the Egress VPC attachment back to the Transit Gateway.

An example arrangement:

### 5a) Egress VPC – Private Subnet Route Table (where your instances or appliances run, if any)

- **Destination**: 10.10.0.0/16, 10.20.0.0/16, etc.  
  **Target**: Transit Gateway (post-inspection table)  
- **Destination**: 0.0.0.0/0  
  **Target**: NAT Gateway  

### 5b) Egress VPC – NAT Gateway Subnet Route Table

- **Destination**: 10.0.0.0/8 (or all of your internal CIDRs)  
  **Target**: Transit Gateway (post-inspection table), if you also want return traffic going back to TGW  
- **Destination**: 0.0.0.0/0  
  **Target**: Internet Gateway  

That allows outbound internet traffic to be translated by NAT, then out the IGW. Return traffic from the internet arrives on the IGW, hits the NAT Gateway’s subnet route table, and if it’s going to an internal IP, it’s routed to the Transit Gateway.  

If you want the returning traffic to be re-inspected, you may also associate the Egress VPC attachment to a “Pre-Inspection-Egress” TGW route table that sends inbound flows back to the **Inspection VPC**. That typically looks like:

**Pre-Inspection-Egress TGW Route Table**

- **Destination**: 0.0.0.0/0  
  **Attachment**: Inspection VPC  
- **Destination**: 10.x.x.x/16 (Egress VPC CIDR)  
  **Attachment**: Egress VPC (local route)  

---

## Putting It All Together

Below is a concise summary table showing the main route tables (one row per route). Adjust the CIDRs and names to match your environment exactly.  

```
---------------------------------------------------------------------------------
SPOKE VPCs – “Private” RT
---------------------------------------------------------------------------------
Destination       | Target
------------------|----------------------------------
Spoke CIDR        | local
0.0.0.0/0         | TGW Attachment (assoc. Pre-Inspection RT)

---------------------------------------------------------------------------------
TGW: “Pre-Inspection” Route Table
---------------------------------------------------------------------------------
Destination       | Attachment
------------------|----------------------------------
Spoke-A CIDR      | Spoke-A
Spoke-B CIDR      | Spoke-B
...               | ...
0.0.0.0/0         | Inspection VPC

---------------------------------------------------------------------------------
Inspection VPC – “TGW Subnet” RT
---------------------------------------------------------------------------------
Destination       | Target
------------------|----------------------------------
Inspection CIDR   | local
0.0.0.0/0         | Firewall Endpoint ENI

---------------------------------------------------------------------------------
Inspection VPC – “Firewall Subnet” RT
---------------------------------------------------------------------------------
Destination       | Target
------------------|----------------------------------
Inspection CIDR   | local
0.0.0.0/0         | TGW Attachment (assoc. Post-Inspection RT)

---------------------------------------------------------------------------------
TGW: “Post-Inspection” Route Table
---------------------------------------------------------------------------------
Destination       | Attachment
------------------|----------------------------------
Spoke-A CIDR      | Spoke-A
Spoke-B CIDR      | Spoke-B
...               | ...
0.0.0.0/0         | Egress VPC

---------------------------------------------------------------------------------
Egress VPC – “Private” RT
---------------------------------------------------------------------------------
Destination       | Target
------------------|----------------------------------
Egress VPC CIDR   | local
All Internal CIDRs| TGW Attachment (assoc. Post-Inspection RT)
0.0.0.0/0         | NAT Gateway

---------------------------------------------------------------------------------
Egress VPC – “NAT Gateway Subnet” RT
---------------------------------------------------------------------------------
Destination       | Target
------------------|----------------------------------
Egress VPC CIDR   | local
All Internal CIDRs| TGW Attachment (assoc. ???)
0.0.0.0/0         | Internet Gateway

---------------------------------------------------------------------------------
TGW: “Pre-Inspection-Egress” RT (for inbound flows returning from IGW)
---------------------------------------------------------------------------------
Destination       | Attachment
------------------|----------------------------------
Egress VPC CIDR   | Egress VPC
0.0.0.0/0         | Inspection VPC
---------------------------------------------------------------------------------
```

You may not need every one of these route tables exactly as shown (for instance, some designs collapse the egress logic into one table). But this illustrates the key idea:

1. **Spokes** → (Pre-Inspection TGW RT) → **Inspection** → (Post-Inspection TGW RT) → **Egress**  
2. **Inbound** from internet → Egress VPC → (Pre-Inspection-Egress RT) → Inspection VPC → (Post-Inspection RT) → Spokes.

This ensures that all north–south flows (to/from the internet) are inspected, while east–west traffic among spokes can bypass the firewall if desired. Adjust the CIDRs, route targets, and route table names per your exact environment.
