
# Appstream Elastic Fleet and On-Demand/Always-On Fleet

This overview should clarify which Amazon AppStream 2.0 fleet type is suitable for your scenarios and what implications each has for managing and securing your applications.

---

## **Fleet Types Comparison**

| Feature                              | Elastic Fleets                                   | On-Demand Fleets                                | Always-On Fleets                             |
|--------------------------------------|-------------------------------------------------|---------------------------------------------------|-----------------------------------------------|
| **Capacity Management**              | Fully managed by AWS (no customer management required) | Customer-managed via scaling policies           | Customer-managed via scaling policies         |
| **Instance Lifecycle**               | Managed by AWS (ephemeral)                | Instances remain in standby (stopped) until user connects | Instances always running (standby or active) |
| **Active Directory Domain Join**     | Not supported                             |  Supported                                  |  Supported                                 |
| **Application Delivery Method**      | Portable applications (VHD uploaded to S3) | Custom image (installed apps)                | Custom image (installed apps)                |
| **Application Portability Required** |  Yes (must support portability)          |  Not required                               |  Not required                              |
| **Domain Join (Active Directory)**   |  No                                      |  Yes                                        |  Yes                                       |
| **Capacity Management**              | AWS managed entirely                      | Customer-managed via scaling policies        | Customer-managed via scaling policies        |
| **Maintenance Overhead**             | Lowest (no image management)              | Moderate (periodic image updates)            | Moderate (periodic image updates)            |

---

## **Key Points Explained**

### **Elastic Fleets**

- **Fully Managed by AWS:**  
  - No need to manage scaling or predict capacity.
- **Application Delivery**:  
  - Delivered via Virtual Hard Disks (VHDs) uploaded to Amazon S3.
  - Applications must support portability (similar to apps running from USB drives).
- **Use Case Consideration**:  
  - AppBlocks are ideal for applications that require local authentication only.
  - **AppBlocks do not support domain join or Active Directory**, so CAC authentication cannot be used end-to-end.
  - Ideal for standalone apps that do not require centralized identity management.

**Ideal for**:

- SaaSifying traditional applications without major rewrites.
- Temporary or short-lived use cases like demos, trials, or training.
- Lightweight apps with no AD dependencies.

### Example Applications

- Lightweigt desktop apps with no CAC Auth Requirements like DBA Tools
- Non-domain integrated applications
- Standalone or local-login-only applications

---

### **On-Demand Fleets**

- Users wait about 2 minutes to launch sessions (instances in standby mode).
- Managed via customer-defined auto-scaling policies.
- Suitable for regular usage patterns, balancing quick availability and cost-efficiency.
- Supports domain-joined scenarios.

### Example Applications

- Line-of-business applications needing domain integration
- CAC-authenticated apps (via Active Directory)

---

### **Always-On Fleets:**

- Provides instant application launch.
- Ideal for frequent, critical use-cases where instant availability is key.
- Higher cost due to running instances continuously.
- Supports Active Directory and Group Policy integration.

### Example Applications

- Mission-critical business applications
- Continuous daily applications for production environments, CAD/CAM, etc.

---

## **Image Management Differences:**

- **Elastic Fleets**:  
  - No traditional image management; applications packaged on a VHD file.
  - Very low administrative overhead.
  - Use AppBlocks to package and stream applications.

- **On-Demand & Always-On Fleets**:  
  - Require custom images created via the AppStream image builder.
  - Periodic updates needed (e.g., OS patches, application updates).

---

## **How to Verify Fleet Type Configuration:**

- **AWS Console**:
  - Navigate to **Amazon AppStream 2.0** console.
  - Select the **Fleets** tab to clearly see the fleet type labeled (**Elastic**, **Always-On**, or **On-Demand**).

---
