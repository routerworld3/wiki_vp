 VDSS and Traffic Inspection Architecture
How will east-west traffic between mission owner VPCs be routed through the VDSS for centralized inspection without creating asymmetric paths or latency bottlenecks?

What inspection models will be used (North-South, East-West, or Combined), and how will they scale to support 10,000+ VPC attachments?

Will each Mission Owner use a dedicated TGW or share a centralized TGW per security domain, and how will routing domains (TGW route tables) be managed?

How will traffic from on-prem to cloud (via DXGW → VGW) be forced through the VDSS VPC before reaching mission applications?

Is TGW appliance mode enabled on the VDSS TGW attachment to maintain flow symmetry for inspection?

🌐 IP Address Management & Public IP Advertisement
How is IP address space segmented for each Mission Owner across their 100–200 VPCs, and what mechanisms prevent IP overlap or collisions?

How are public IP workloads advertised to the DoD Information Network (DoDIN) through DXGW?

Are DoD-assigned public IPs brought into AWS and associated with ALBs in a central ingress VPC?

Is BGP advertisement via Public VIF or Private VIF configured to route traffic from DoDIN to AWS public endpoints?

What safeguards are in place to prevent unauthorized advertisement of DoD IP prefixes into the AWS backbone?

How will routing of public IPs over DXGW be handled: via VGW route tables, custom BGP communities, or service-specific peering?

Are route filters and prefix limits enforced to avoid route leaks and to maintain CAP (Cloud Access Point) boundary control?

📈 Scalability and Multi-Tenancy
How is multi-tenancy handled across Mission Owners to logically separate and secure traffic while using shared VDSS and inspection infrastructure?

What is the strategy for scaling AWS Network Firewall throughput and endpoint deployments across multiple AZs per mission VPC?

Will each Mission Owner use their own firewall rule groups or inherit from a central baseline (e.g., Firewall Manager policies)?

How are inspection logs for 10,000+ VPCs stored and made queryable for DoD CND (Computer Network Defense) teams?

How will logging, monitoring, and alerting be centralized to meet IL5 requirements while maintaining per-tenant isolation?

📦 Automation, Governance, and Compliance
How will VPC onboarding (for new Mission Owners or VPCs) be automated to ensure consistent routing through VDSS?

Are there mechanisms in place (like AWS Config rules or Control Tower guardrails) to prevent bypassing of the inspection path?

How are network policies, security rules, and flow logs audited and version-controlled across such a large environment?

What role will AWS Firewall Manager play in managing firewall policies across thousands of inspection points?

How are changes to routing, inspection, or NAT configurations approved and tracked under CM and STIG processes?

Would you like these questions organized into a review template or shared as a checklist spreadsheet for stakeholders? I can also generate Terraform blueprints or architectural diagrams if you’re working through design implementation.
