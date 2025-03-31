# Appstream Elastic Fleet and On-Demand/Always-On Fleet

This overview should clarify which Amazon AppStream 2.0 fleet type is suitable for your scenarios and what implications each has for managing and securing your applications.

---

##  **Fleet Types Comparison**

| Feature                              | Elastic Fleets                                   | On-Demand Fleets                                | Always-On Fleets                             |
|--------------------------------------|-------------------------------------------------|---------------------------------------------------|-----------------------------------------------|
| **Capacity Management**              | Fully managed by AWS (no customer management required) | Customer-managed via scaling policies           | Customer-managed via scaling policies         |
| **Instance Lifecycle**               | Managed by AWS (ephemeral)                | Instances remain in standby (stopped) until user connects | Instances always running (standby or active) |
| **Active Directory Domain Join**     | Not supported                             |  Supported                                  |  Supported                                 |
| **Application Delivery Method**      | Portable applications (VHD uploaded to S3) | Custom image (installed apps)                | Custom image (installed apps)                |
| **Application Portability Required** |  Yes (must support portability)          |  Not required                               |  Not required                              |
| **Domain Join (Active Directory)**   |  No                                      |  Yes                                         | yes
