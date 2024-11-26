# **Summary of NIST SP 800-207: Zero Trust Architecture**

**Introduction:**

- **Zero Trust (ZT)** is a cybersecurity paradigm focused on the principle of never implicitly trusting users, devices, or systems inside or outside the network.
- **Zero Trust Architecture (ZTA)** emphasizes continual authentication and authorization for access requests, minimizing risk and limiting lateral movement within networks.
- It shifts from traditional perimeter-based security to a resource-centric approach.

---

## **Key Tenets of Zero Trust:**

1. **Treat all data and services as resources:** Securely manage access to all enterprise assets.
2. **Secure communication:** Encrypt and authenticate all communications, regardless of location.
3. **Per-session access:** Authorize access dynamically for every session, without assuming prior trust.
4. **Dynamic policy enforcement:** Base access decisions on a combination of user identity, device state, and contextual factors (e.g., time, location).
5. **Continuous monitoring:** Evaluate security posture continuously and apply mitigations dynamically.
6. **Dynamic authentication and authorization:** Enforce strict access rules based on changing security states.
7. **Comprehensive data collection:** Use network and endpoint telemetry to refine security policies.

---

### **Logical Components of ZTA:**

- **Policy Decision Point (PDP):** Determines whether access should be granted.
- **Policy Enforcement Point (PEP):** Implements PDP’s decisions, controlling access to resources.
- **Policy Engine (PE):** Subcomponent of PDP, evaluates policies to make access decisions.
- **Policy Administrator (PA):** Configures PEPs to enforce decisions made by PE.
- **Policy Information Point (PIP):** Supplies context such as device status or threat intelligence.

---

### **Deployment Models:**

1. **Agent/Gateway Model:** Agents on devices interact with gateways for controlled resource access.
2. **Enclave Model:** Entire enclaves of resources are shielded behind a gateway.
3. **Resource Portal Model:** Centralized access portal manages user requests for multiple resources.
4. **Application Sandboxing:** Isolated environments for applications limit risks of host compromise.

### **Zero Trust Architecture (ZTA) Deployment Models**

ZTA deployment models define how Zero Trust principles are operationalized within an organization. These models depend on the organization's infrastructure, resource types, and security goals. Below are detailed descriptions of the primary deployment models, their key components, and their unique characteristics.

---

#### **1. Device Agent/Gateway-Based Deployment**

- **Description:** 
  - In this model, the Policy Enforcement Point (PEP) is divided into two components: 
    - **Device Agent:** Installed on the user’s device to facilitate secure communication and access control.
    - **Resource Gateway:** Positioned in front of resources to manage access requests.
  - The device agent ensures secure traffic routing, while the resource gateway enforces access decisions from the Policy Administrator (PA).
- **Key Components:**
  - **Device Agent:** Coordinates with the gateway and ensures endpoint compliance.
  - **Resource Gateway:** Acts as a proxy to secure resource access.
  - **Policy Engine (PE):** Makes access decisions.
  - **Policy Administrator (PA):** Configures resource access based on PE decisions.
- **Use Cases:**
  - Enterprises with tightly controlled devices and resources.
  - Organizations without a Bring-Your-Own-Device (BYOD) policy.
- **Example Technologies:** VPN agents, Appgate SDP.

---

#### **2. Enclave-Based Deployment**

- **Description:**
  - Instead of securing individual resources, this model groups multiple resources into **enclaves** or isolated zones protected by a single gateway.
  - Commonly used for legacy systems or systems that cannot interact with modern gateways.
- **Key Components:**
  - **Enclave Gateway:** Positioned at the boundary of the enclave to manage access.
  - **Policy Engine and Administrator:** Handle granular access policies for all resources within the enclave.
- **Advantages:**
  - Simplifies management for large collections of interdependent resources.
  - Ideal for legacy systems that lack modern authentication mechanisms.
- **Use Cases:**
  - Data centers or private clouds with multiple interdependent systems.
  - Environments requiring microservices for business functions.
- **Example Technologies:** Palo Alto Prisma Access (for enclave segmentation).

---

#### **3. Resource Portal-Based Deployment**

- **Description:**
  - Access to resources is mediated by a centralized **portal** that serves as the single point of entry.
  - Users authenticate at the portal, which forwards validated requests to the resources.
- **Key Components:**
  - **Portal Gateway (PEP):** Acts as the single enforcement mechanism.
  - **Authentication Service:** Ensures users and devices are authenticated.
  - **Policy Engine:** Makes decisions based on access requests and contextual information.
- **Advantages:**
  - Simplifies access management for BYOD and collaboration scenarios.
  - Ideal for environments where installing agents on every device is not feasible.
- **Challenges:**
  - Limited visibility and control over devices not owned by the enterprise.
- **Use Cases:**
  - Collaboration between organizations or with external partners.
  - Public-facing services or customer portals.
- **Example Technologies:** Microsoft Azure AD Application Proxy, Akamai EAA.

---

#### **4. Device Application Sandboxing**

- **Description:**
  - Applications run in isolated, sandboxed environments on the user’s device, reducing risks from compromised hosts.
  - The sandbox communicates with resources through the Policy Enforcement Point (PEP).
- **Key Components:**
  - **Application Sandbox:** Protects sensitive workflows within an isolated environment.
  - **Policy Enforcement Point:** Ensures secure communication between the sandbox and enterprise resources.
  - **Policy Engine and Administrator:** Manage and enforce granular access.
- **Advantages:**
  - Reduces risk from compromised or non-compliant host devices.
  - Prevents malware from accessing sensitive applications.
- **Use Cases:**
  - Environments requiring high security for critical applications.
  - Scenarios involving unmanaged or semi-managed devices.
- **Example Technologies:** VMware Workspace ONE, Citrix Secure Browser.

---

### **Summary of Key Characteristics**

| **Deployment Model**          | **Key Feature**                                  | **Best Fit For**                        | **Example Technologies**                         |
|--------------------------------|-------------------------------------------------|-----------------------------------------|-------------------------------------------------|
| Device Agent/Gateway-Based     | Device agents secure traffic to resource gateways. | Controlled devices and managed networks.| Appgate SDP, Cisco AnyConnect.                  |
| Enclave-Based Deployment       | Groups resources behind a gateway.              | Legacy systems, data centers.           | Palo Alto Prisma Access, Fortinet FortiGate.    |
| Resource Portal-Based          | Centralized portal manages all access.          | BYOD, external collaboration.           | Azure AD Application Proxy, Akamai EAA.         |
| Device Application Sandboxing  | Isolated environments protect applications.      | High-security workflows.                | VMware Workspace ONE, Citrix Secure Browser.    |

Each deployment model can be customized to an organization's unique needs, combining ZTA principles with the existing infrastructure for optimal security and usability. Let me know if you’d like further details!

The NIST SP 800-207 document identifies **three main architecture approaches** for implementing Zero Trust Architecture (ZTA). These approaches emphasize different strategies for managing access to enterprise resources based on identity, micro-segmentation, and network infrastructure. Below are the key points and examples for each approach:

---

### **1. Enhanced Identity Governance Approach**

- **Key Points:**
  - Focuses on **identity** as the primary factor for defining access policies.
  - Resources are protected by assigning access privileges based on **user attributes**, roles, and observed behavior.
  - Devices and context, such as security posture and location, can adjust access decisions dynamically.
  - Relies heavily on Identity, Credential, and Access Management (ICAM) systems.
- **Strengths:**
  - Works well in environments where identity is tightly managed and federated (e.g., Single Sign-On systems).
  - Ideal for SaaS and cloud-based applications where direct network control isn't feasible.
- **Examples:**
  - **Microsoft Azure Active Directory Conditional Access:** Uses user identity and device compliance to enforce dynamic access policies.
  - **Okta Identity Engine:** Provides flexible policy creation based on user and device attributes.

---

### **2. Micro-Segmentation Approach**

- **Key Points:**
  - Uses **network segmentation** to divide resources into small, secure zones (or enclaves).
  - Each zone is protected by a **Policy Enforcement Point (PEP)**, such as a next-generation firewall or a gateway.
  - Access to zones is controlled dynamically by evaluating the security posture and context of the request.
  - Can include host-based segmentation using software agents on devices.
- **Strengths:**
  - Offers granular control of network traffic and limits lateral movement.
  - Effective for protecting legacy systems and on-premises data centers.
- **Examples:**
  - **VMware NSX:** Implements micro-segmentation at the network level to isolate workloads.
  - **Palo Alto Prisma Access:** Uses segmentation to provide secure access to resources across hybrid environments.

---

### **3. Network Infrastructure and Software-Defined Perimeter (SDP) Approach**

- **Key Points:**
  - Builds on concepts like **Software-Defined Networking (SDN)** and **Intent-Based Networking (IBN)** to enforce ZTA principles.
  - Policies are enforced at the network infrastructure layer, using controllers and programmable overlays.
  - Often relies on a central **Policy Administrator (PA)** to dynamically reconfigure the network based on access requests.
- **Strengths:**
  - Ideal for large-scale, dynamic environments such as multi-cloud architectures.
  - Supports flexible and scalable access control for modern network designs.
- **Examples:**
  - **Appgate SDP:** Secures access to resources using software-defined perimeter principles.
  - **Cisco SD-WAN:** Applies intent-based networking to enforce access controls dynamically across distributed environments.

---

### **Use Case Matching**

| **Approach**                | **Best Fit**                                                                             |
|-----------------------------|-----------------------------------------------------------------------------------------|
| Enhanced Identity Governance | Environments with strong identity management systems and cloud/SaaS-heavy workloads.    |
| Micro-Segmentation          | Data centers, hybrid environments, or legacy systems requiring controlled segmentation.  |
| Network Infrastructure & SDP| Distributed enterprises needing scalable, dynamic resource access across multiple clouds.|

These approaches are often combined in real-world implementations to address the unique needs of the organization. Let me know if you'd like a detailed example or further clarification!

Here are detailed examples of how each Zero Trust Architecture (ZTA) approach can be implemented, with practical use cases and solutions:

---

### **1. Enhanced Identity Governance Approach**

#### **Description:**
This approach uses identity as the central factor for access decisions. It integrates identity governance with contextual data (e.g., device posture, location, and behavior analytics) to determine the level of access. Policies dynamically adapt to real-time identity information.

#### **Example Implementation:**
- **Scenario:** A financial institution managing remote access to sensitive financial records via cloud services.
- **Components:**
  - **Identity Provider (IdP):** Azure Active Directory (AAD) provides user authentication.
  - **Conditional Access Policies:** Azure AD Conditional Access evaluates real-time signals (e.g., device compliance, user location, and risk scores) to grant or deny access.
  - **Multi-Factor Authentication (MFA):** Enforced for high-risk access attempts (e.g., accessing financial data from a new location).
  - **Device Compliance:** Microsoft Intune ensures only managed and compliant devices access sensitive systems.
- **Workflow:**
  1. A remote user attempts to access financial records in Microsoft SharePoint Online.
  2. AAD evaluates the user's identity, device compliance, and location.
  3. Access is granted only if all conditions meet pre-defined policies.

#### **Key Vendors:**
- **Microsoft:** Azure AD, Intune.
- **Okta:** Identity governance and MFA integration.
- **Ping Identity:** Federated access control and dynamic policies.

---

### **2. Micro-Segmentation Approach**

#### **Description:**
This approach isolates resources into small segments, each protected by its own security controls. Micro-segmentation limits lateral movement, even if one segment is compromised.

#### **Example Implementation:**
- **Scenario:** A healthcare organization protecting sensitive patient data stored in a hybrid cloud environment.
- **Components:**
  - **Software-Defined Networking (SDN):** VMware NSX enables micro-segmentation of workloads in the data center.
  - **Firewall Rules:** Segment traffic to restrict unauthorized east-west movement between workloads.
  - **Access Policies:** Palo Alto Networks Prisma Access manages user access to cloud-hosted patient records.
  - **Agent-Based Enforcement:** Endpoint agents enforce access rules on devices connecting to workloads.
- **Workflow:**
  1. A clinician accesses a patient management application hosted in a private cloud.
  2. NSX enforces segmentation, ensuring the clinician can only access the required application.
  3. Attempts to move laterally (e.g., to a billing system) are blocked.
- **Advanced Features:**
  - Integration with threat detection systems for real-time policy updates.
  - Logging and monitoring of all traffic for audit compliance.

#### **Key Vendors:**
- **VMware:** NSX for micro-segmentation.
- **Cisco:** Secure Workload (formerly Tetration) for workload segmentation.
- **Palo Alto Networks:** Prisma Access for cloud-based segmentation.

---

### **3. Network Infrastructure and Software-Defined Perimeter (SDP) Approach**

#### **Description:**
This approach uses an overlay network or software-defined perimeter to enforce access controls. It is particularly useful for environments with dynamic infrastructure, such as multi-cloud deployments.

#### **Example Implementation:**
- **Scenario:** A global enterprise ensuring secure collaboration between distributed teams and contractors.
- **Components:**
  - **Software-Defined Perimeter (SDP):** Appgate SDP creates secure, encrypted tunnels between users and resources.
  - **Cloud Security:** Cisco SD-WAN provides dynamic routing and segmentation for cloud and on-premise workloads.
  - **Intent-Based Networking:** Cisco DNA Center adjusts network policies based on access intent.
  - **Centralized Controller:** A Policy Administrator configures access based on Policy Engine decisions.
- **Workflow:**
  1. A contractor requests access to a design application hosted in AWS.
  2. Appgate SDP authenticates the contractor and creates a secure session to the specific application, bypassing public exposure.
  3. Cisco SD-WAN ensures optimal, secure routing of traffic between regions.
- **Advanced Features:**
  - Integration with threat feeds to block access in case of suspicious activity.
  - Seamless scalability to handle fluctuating workloads.

#### **Key Vendors:**
- **Appgate:** SDP for secure, dynamic access.
- **Cisco:** DNA Center and SD-WAN.
- **Zscaler:** Zero Trust Exchange for multi-cloud environments.

---

### **Comparison Table:**

| **Approach**                | **Best Fit**                                          | **Example Technologies**                     |
|-----------------------------|------------------------------------------------------|---------------------------------------------|
| Enhanced Identity Governance | Cloud-heavy environments, SaaS-based applications.  | Azure AD, Okta, Ping Identity.              |
| Micro-Segmentation          | Legacy systems, hybrid cloud, data centers.         | VMware NSX, Cisco Secure Workload.         |
| Network Infra. & SDP         | Dynamic, multi-cloud deployments.                   | Appgate SDP, Cisco DNA Center, Zscaler.    |

These examples demonstrate how ZTA principles can be tailored to specific organizational needs, leveraging diverse technologies for robust security. Let me know if you'd like additional details or another use case!

---

### **Use Cases:**

- Enterprises with remote employees or satellite offices.
- Multi-cloud and hybrid environments.
- Collaboration across enterprise boundaries.
- Organizations with public-facing services.

---

### **Threats Addressed by ZTA:**

- Insider threats and stolen credentials.
- Subversion of decision-making processes.
- Lateral movement within networks.
- Denial-of-Service (DoS) attacks on resources.

---

### **Steps to Migrate to Zero Trust Architecture:**

1. **Identify actors and assets:** Map all users, devices, and workflows.
2. **Assess risks:** Evaluate vulnerabilities and risks in current operations.
3. **Formulate policies:** Define access rules based on least privilege.
4. **Deploy ZTA incrementally:** Start with critical workflows and expand.
5. **Continuous monitoring and adaptation:** Adjust policies based on evolving threats.

---

### **Interactions with Existing Federal Guidance:**

- Aligns with frameworks like FISMA, NIST RMF, and Trusted Internet Connections (TIC) 3.0.
- Supports Identity, Credential, and Access Management (ICAM) initiatives.
- Complements cloud strategies such as **Cloud Smart**.

For a full exploration of ZTA principles, scenarios, and implementation guidelines, see the [NIST SP 800-207 document](https://doi.org/10.6028/NIST.SP.800-207)

## Summary of Key Points from NIST SP 1800-35: Implementing a Zero Trust Architecture (ZTA)

The NIST Special Publication 1800-35 provides a practical guide for implementing a Zero Trust Architecture (ZTA). Below are the key takeaways from the document:

<https://www.nccoe.nist.gov/sites/default/files/2024-07/zta-nist-sp-1800-35-preliminary-draft-4.pdf>
---

## **1. ZTA Overview**

- **Definition:** ZTA eliminates implicit trust by continuously verifying access requests to enterprise resources based on user, device, and context.
- **Goals:**
  - Protect data and resources across on-premises and cloud environments.
  - Support secure access for diverse users, including employees, contractors, and partners.
  - Enable hybrid and remote workforces securely.

---

### **2. Core ZTA Principles**

- **Risk-Based Access:** Continuous verification of users, devices, and requests ensures dynamic risk assessments.
- **Least Privilege Access:** Access is granted with minimal permissions based on necessity and context.
- **Continuous Monitoring:** Real-time monitoring and logging of access requests to identify and mitigate risks.
- **Explicit Verification:** Every access request requires validation, even from within the network.

---

### **3. Reference Architectures and Phases**

- **General ZTA Reference Architecture:**
  - Core Components:
    - **Policy Engine (PE):** Makes access decisions based on policies and risk.
    - **Policy Administrator (PA):** Configures and enforces the decisions.
    - **Policy Enforcement Point (PEP):** Implements access controls.
  - Supporting Components:
    - Identity, Credential, and Access Management (ICAM), endpoint security, security analytics, and data security.
  - Includes Policy Information Points (PIPs) for real-time data feeding into decision-making.

- **Implementation Phases:**
  1. **EIG Crawl Phase:** Initial phase focusing on basic identity governance.
  2. **EIG Run Phase:** Builds on the crawl phase by incorporating cloud capabilities and advanced device discovery.
  3. **Advanced Phases:** Utilize microsegmentation, Software-Defined Perimeter (SDP), and Secure Access Service Edge (SASE).

---

### **4. Functional Demonstrations and Use Cases**

- Demonstrations covered various use cases like:
  - Resource discovery and secure access.
  - Role-based and federated identity access.
  - Service-to-service interactions.
  - Data-level security policies.
- **Example Scenarios:** Ensuring secure access for remote workers using managed/unmanaged devices, federated identity for partners, and dynamic policy enforcement.

---

### **5. Challenges in ZTA Implementation**

- **Organizational Challenges:**
  - Misconception that ZTA is only suitable for large enterprises.
  - Lack of organizational buy-in and adequate resource allocation.
- **Technical Challenges:**
  - Integrating diverse technologies and legacy systems.
  - Addressing gaps in existing policies and inventory management.
  - Lack of interoperability among tools and platforms.

---

### **6. ZTA Deployment Findings**

- Use of existing tools (e.g., ICAM, SIEM) is critical for incremental adoption.
- Gradual deployment enables organizations to manage costs and risks effectively.
- No "one-size-fits-all" approach; ZTA must align with organizational requirements.

---

### **7. Collaborator Contributions**

- NIST collaborated with 24 industry leaders, including Microsoft, Amazon Web Services, Cisco, and IBM, to create 17 example implementations.
- Demonstrations showcased interoperable solutions using out-of-the-box capabilities.

---

### **8. Recommendations for Organizations**

1. **Start with an Inventory:**
   - Identify existing resources, users, and security capabilities.
2. **Define Policies:**
   - Develop access policies based on business needs and regulatory requirements.
3. **Adopt Incrementally:**
   - Begin with foundational components like identity management and endpoint security.
4. **Leverage Existing Investments:**
   - Use current tools and platforms to transition smoothly.
5. **Continuously Evolve:**
   - Adapt to new threats, technologies, and regulations.

---

### **9. Benefits of ZTA**

- Reduces the impact of insider threats and lateral movement during attacks.
- Enhances regulatory compliance and simplifies audit processes.
- Improves visibility into user and device behavior through continuous monitoring.

---

### **10. ZTA in Operation**

- Key Processes:
  1. **Resource Management:** Authenticate resources and verify health periodically.
  2. **Session Initiation:** Verify subjects and approve/deny access.
  3. **Session Management:** Continuously monitor and re-evaluate session validity.
- Policies are dynamically enforced and updated based on real-time inputs.

---

### Zero Trust Architecutre Components

In the Zero Trust Architecture (ZTA) context, the roles of PDP, PIP, PEP, PA, and PE are central to enforcing access control policies dynamically. Based on the insights from NIST SP 1800-35 and industry examples, here's a detailed breakdown, including updated examples with vendors like Appgate, as referenced in the NCCoE publication.

### **Definitions:**

1. **Policy Decision Point (PDP):**
   - Evaluates access requests against defined security policies.
   - Integrates data from PIPs to make decisions.
   - Example: Appgate SDP Controller, Okta Identity Engine.

2. **Policy Information Point (PIP):**
   - Provides contextual information required by the PDP for decision-making (e.g., user attributes, device status).
   - Example: Appgate Insight (for user and device context), Microsoft Intune (device compliance).

3. **Policy Enforcement Point (PEP):**
   - Enforces the decisions made by the PDP, typically on network traffic or application access.
   - Example: Appgate SDP Gateway, Palo Alto Networks Prisma Access.

4. **Policy Administrator (PA):**
   - Facilitates communication between PDP and PEP, ensuring enforcement actions align with decisions.
   - Example: Cisco DNA Center, VMware NSX.

5. **Policy Engine (PE):**
   - Subcomponent of PDP that applies logical policies to incoming data.
   - Example: Zscaler ZIA, IBM Security Verify.

---

Here's the table including examples of **Microsoft components** in a Zero Trust Architecture (ZTA) context, alongside other vendor solutions:

---

| **Component**  | **Description**                             | **Microsoft Examples**                                    | **Other Vendor Examples**                                               |
|-----------------|---------------------------------------------|----------------------------------------------------------|--------------------------------------------------------------------------|
| **PDP**        | Central decision-making system for access. | **Microsoft Conditional Access** (within Azure AD).      | Appgate SDP Controller, Okta Identity Engine, Zscaler ZIA.              |
| **PIP**        | Supplies contextual data to the PDP.        | **Microsoft Intune** (device compliance data), Azure AD. | Appgate Insight, CrowdStrike Falcon, Lookout CASB.                      |
| **PEP**        | Enforces access decisions from the PDP.     | **Azure AD Application Proxy**, Microsoft Defender.      | Appgate SDP Gateway, Akamai EAA, Cisco Secure Workload.                 |
| **PA**         | Administers policy deployment to PEPs.      | **Microsoft Endpoint Manager (MEM)**.                   | VMware NSX, Cisco DNA Center.                                           |
| **PE**         | Applies logic to evaluate policies.         | **Azure Policy**, Conditional Access policies in Azure.  | Appgate SDP, Zscaler ZIA, Palo Alto Prisma Access.                      |

---

### **Detailed Example Using Microsoft Tools:**

If a remote user tries to access sensitive corporate resources:

1. **PIP:** Microsoft Intune checks the user's device compliance (e.g., patched OS, secure configuration).
2. **PDP:** Azure AD Conditional Access evaluates the user's context (identity, device compliance, location) and determines access permissions.
3. **PEP:** Azure AD Application Proxy allows or blocks resource access based on the decision.
4. **PA:** Microsoft Endpoint Manager ensures the enforcement mechanisms are configured on endpoint devices.

Microsoft's ecosystem integrates tightly with Azure Active Directory, Intune, and Defender for comprehensive Zero Trust implementation. Let me know if you need further details on integration!
