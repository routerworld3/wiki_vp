ails

github_enterprise_server (1).md
TJ Long
Yesterday at 1:11 PM
Private file

---
date: 2024-06-10
title: "ADR - GitHub Enterprise Server Deployment"
---
<!-- This is a mandatory element, update the Status/date/# and Author columns appropriately -->
!!! info inline end "Metadata"
​
    | Status  | Proposed :fontawesome-solid-code-branch:        |
    | ------- | -------------------------------------------     |
    | Date    | 2024-06-10                                    |
    | Author  | [TJ Long](mailto:timothy.long@mantech.com)        |    
​
​
## Context and Problem Statement
​
This Architectural Decision Record (ADR) addresses the decision of whether to deploy, host and maintain our own instance of GitHub Enterprise (GitHub Enterprise Server), or continue to operate under GitHub Enterprise Cloud. Security management, cost allocation, operational control, and data governance compliance are considered in this decision.
​
GitHub Enterprise Cloud is posing some issues for us when it comes to hosting CUI information. This leads to challenges from an Administrative, Cyber, and engineering perspective where we have to use extreme caution when pushing code and documentation to our repositories. 
​
# Self-Hosted GitHub Enterprise Server
​
## Status
​
- Proposed
​
## Technical Questions
​
The Solution should fit the following criteria
​
- Technical: Not hinder engineering abilities
- Technical: Allow for GitHub Actions and Workflows to run
- Security: Allow NMMES, Stigian and Subcontractors access to our GitHub Enterprise as required
    - IE: Not being locked behind FlankSpeed or NMCI/NNPI VPNs.
- Security: Be IL4 or IL5 compliant
    - Capabilities to hold CUI
- Cost: What is the cost difference between licenses for Server vs Cloud?
- Cost: With Self-Hosting, what is an estimated cost of AWS resources?
​
## Considered Options
- GitHub Enterprise Cloud (GitHub.Com)
- Flank Speed Azure GitHub (Navy Owned GHES Deployment)
- GitHub Enterprise Server (Sef Hosted on AWS)
​
​
## GitHub Enterprise Cloud
​
GitHub Enterprise cloud is GitHub's SaaS offering of GitHub Enterprise. It is hosted at GitHub.com and it's the system we currently use. The backend is maintained by GitHub and the usage is very straight forward.
​
GitHub Enterprise Cloud was FedRAMP Certified in 2018, but only for Impact Level **LI-SaaS**, [FedRAMP Marketplace](https://marketplace.fedramp.gov/products/FR1812058188). This poses a huge challenge for us not being able to maintain CUI within our issues, projects, or repositories, and when building out Infrastructure as Code (IaC), this becomes problematic when things like IP Addresses and System Hostnames are considered CUI.
​
## GitHub Enterprise Server
​
GitHub Enterprise Server is a self-hosted solution that provides a vast majority of the features GitHub.com offers, albeit a little bit slower in terms of pacing (usually several months behind).
​
Being a self hosted solution, it comes with benefits of data ownership and control. We would be in full control of the AWS account the information is housed within, therefore the limitations of said data are much more open as long as the account meets the requirements of IL4/IL5 and CUI.
​
However, GitHub Enterprise Server comes with a hefty cost. Both from a financial and engineering standpoint.
​
### Cost
​
A self-hosted GitHub Enterprise Server deployment license is the same cost as the GitHub.com variant at $21/Month per use. GitHub Advanced Security tacks another $49/Month. This mirrors what we are paying now.
​
However, the self-hosted variant also comes with a slew of AWS costs for infrastructure. Below is a real basic cost estimate for the big ticket items (Compute and Storage) for running our own High Availability GHES setup is us-gov-west-1.
​
EC2 (Dedicated Tenacy):
- r6i.2xlarge w/ 600GB of gp3 - 2,044.64 (GHES Node 1)
- r6i.2xlarge w/ 600GB of gp3 - 2,044.64 (GHES Node 2)
- c5.large w/ 60GB of gp3 - 794.20 (RHEL Bastion)
- c5.xlarge w/ 60GB of gp3 - 811.72 (Windows Bastion)
​
EC2 (Default Tenancy on Demand):
- r6i.2xlarge w/ 600GB of gp3 - 540.52 (GHES Node 1)
- r6i.2xlarge w/ 600GB of gp3 - 540.52 (GHES Node 2)
- c5.large w/ 60GB of gp3 - 40.11 (RHEL Bastion)
- c5.xlarge w/ 60GB of gp3 - 77.34 (Windows Bastion)
​
Note: The Bastion Servers are assuming a 50% utilization each month. As bastion hosts, they only need to be online when performing administrative and backend GHES tasks.
​
There are a slew of other costs to consider for an AWS account (LoadBalancer, Snapshots, S3 etc.), but the bulk of the cost will come from EC2 instances. There is also an unknown cost for GitHub Action Runners as there is a lot of questions surrounding them, but we should assume 2-5 instances of c5.large capacity that need to exist in the account 100% of the time.
​
### Ports & Protocols
​
GHES requires a handful of ports and protocols.
​
#### Inbound Traffic
​
| Source                | Destination               | Protocol        |
| --------------------- | ------------------------- | --------------- |
| End Users | Load Balancer Front End | 443/TCP - HTTPS for Web Interface |
| End Users | Load Balancer Front End | 80/TCP - HTTP which is redirected to 443 |
| End Users | Load Balancer Front End | 22/TCP - Git via SSH |
| End Users | Load Balancer Front End | 25/TCP - SMTP with STARTTLS encryption support |
​
#### GitHub Enterprise Servers
​
| Ports (TCP/UDP)* | Protocols | Services | Purpose | Used By | Remark |
|------------------|-----------|----------|---------|---------|--------|
| 122/TCP          | SSH        | SSH from Bastion host       | Bastion Host SG           |                   | |
| 80/TCP           | HTTP       | Web Application             | HTTP from Bastion hosts   | Bastion Host SG   | |
| 443/TCP          | HTTPS      | Web Application             | HTTPS from Bastion hosts  | Bastion Host SG   | |
| 8080/TCP         | HTTP       | Web Application             | HTTP from Bastion hosts   | Bastion Host SG   | GHES Web Admin Panel |
| 8443/TCP         | HTTPS      | Web Application             | HTTPS from Bastion hosts  | Bastion Host SG   | GHES Web Admin Panel |
| 161/UDP          |            | Network Protocol Monitoring | Cluster Communication     | Self - GHES Nodes | |
| 122/TCP          | SSH        | SSH                         | Cluster Communication     | Self - GHES Nodes | |
| 1194/UDP         |            | Replication Network Tunnel  | Cluster Replication       | Self - GHES Nodes | Encrypted with WireGuard |
| *                | *          | ELB                         | ELB Ingress               | GHES Nodes        | Ingress from  filtered ELB SG |
​
### Questions & Risks
​
There is a plethora of engineering questions that will need to be answered or have work done regarding. This ADR breaks down questions into several categories and addressed the big questions that have come up so far.
​
---
​
#### Basic Engineering
​
 - **Is GHES Deployable via IaC**
​
    Mostly. GHES has a handful of manual installation steps, but GitHub provides AMIs to deploy GHES based on AWS region. We can use this to deploy the initial EC2 instances that we will then manually configure as we need. Terraform has been written for a private 2-node deployment of GHES with bastion hosts in a commercial setting testing in us-west-2. Reconfiguring it for us-gov-west-1 should not be too heavy of a lift.
​
    Note: GHES also requires Elastic IP Addresses to be attached to the instance during initialization (even in a private subnet), but it can be removed/deleted after TLS certificates are attached to the instance. This can also be handled by Terraform by commenting out the resource.
​
    _Status: Tested and Works_
​
​
 - **Will GHES be highly available?**
​
    Yes. GHES supports high availability (HA) configuration as laid out in their documentation [here](https://docs.github.com/en/enterprise-server@3.13/admin/monitoring-managing-and-updating-your-instance/configuring-high-availability/creating-a-high-availability-replica). A 2 node HA cluster was set up via Terraform with planned failover to the replica and recovery of the primary having been tested.
​
    _Status: Tested and Works_
​
​
 - **Where will GHES preside?**
​
    We need to collectively figure out where we would deploy the GHES infrastructure. IE: An AWS account connection to CHE-Core and within the NTA organization, or something separate and outside. It is worth nothing that our GitHub.com resources were immune to the NTA incident, whereas if our GHES instance was deployed in an NTA controlled account, it would have been at-risk.
​
    _Status: Unanswered Risk_
​
---
​
#### Cyber & Security Questions
​
 - **GHES and STIG/ACAS Compliance**
​
    This is an unknown. GitHub Enterprise Server is a "self-contained virtual appliance" built upon Ubuntu. GitHub also states that `Installing third-party software or making changes to the underlying operating system is not supported for GitHub Enterprise Server.`. This means that we would not be authorized to apply any open STIG or ACAS item to the GHES instances.
​
    _Status: Unanswered Risk_
​
 - **GHES & ssm-agent Access**
​
    Based on the above comment about 3rd party software not being supported. This means that the AWS SSM agent for Fleet Manager is not allowed. This means in order to access the instance terminals, we have to use a bastion host for SSH. The Terraform proof-of-concept for this deployment creates the SSH key pair and places it in secrets manager to use from the RHEL box to initiate the session to the GHES servers.
​
    _Status: Tested and Works_
​
    * Note: It is possible that we could talk to GitHub support and find out ssm-agent is authorized. However, a force installation has been tested, and while it does work for connecting to the instance. The session does NOT work properly with ghe administrative commands.
​
---
​
#### Application Access
​
 - **How will our GHES instance be reachable?**
​
    For the sake of our subcontractors, and for the sanity of the engineers, we should be able to commit, push and pull code from out ManTech laptops. We do not want our GHES instance to be locked behind the NMCI/NNPI VPN or FlankSpeed VDI.
​
    This is probably one of the biggest questions/concerns to have since GitHub.com is easily available to all NMMES support staff.
​
    We can implement CaC authentication to satisfy MFA requirements, however this will exclude some subcontractors from being able to access the code repositories. There are two primary paths here for authentication:
      1. CaC authentication only
      2. CaC authentication + ECA (External Certification Authority) for subcontractors.
​
    _Status: Unanswered Risk_
​
​
 - **How will end-users authenticate to GHES**
​
    This is a big unknown. We are currently trying to migrate to using Entra ID for SSO, and GitHub Enterprise Server does [officially support](https://docs.github.com/en/enterprise-server@3.13/admin/managing-iam/using-saml-for-enterprise-iam/configuring-saml-single-sign-on-for-your-enterprise#supported-identity-providers) SAML based authentication with Entra ID. However we still have to work out how access with our subcontractors and other entities would authenticate with the instance.
​
    _Status: Unanswered Risk_
​
​
 - **How will we administer our GHES from the Web Interface privately?**
​
    There are a handful of administrative tasks that can be done only via the Web Interface. These administrative ports (8080 and 8443) will **not** be exposed to the Network Load Balancer and will only be reachable via a RHEL and Windows Bastion host from within the AWS Account and VPC.
​
    _Status: Tested and Works_
​
---
​
#### GitHub Actions & Automation
​
 - **Can GHES use GitHub Actions?**
​
    Yes, however we would need to deal with the challenge of dealing with self-hosted runners. Some initial testing was done with deploying 1 persistent RHEL9 EC2 instance to act as a GitHub Action runner that would exist is perpetuity. However this method is not very cost-effective since the server will be up 100% of the time. We would likely want to deploy something that could scale up and down dynamically as demand warranted. Even better if we can do something with spot instances to save money.
​
    _Status: Tested and Works with a caveat below*_
​
   ...
