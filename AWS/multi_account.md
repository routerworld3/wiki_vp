# Multi Account OU White Paper Summary

Below is a typical recommended OU (organizational unit) and account hierarchy, showing how you might group your accounts under a single AWS Organization root and management account. You can adapt or expand it as needed for your specific requirements.

```
AWS Organization (Root)
└─ [Management (Payer) Account]
   ├─ Security OU
   │   ├─ Log Archive Account
   │   └─ Security Tooling (Audit) Account
   │
   ├─ Infrastructure OU
   │   ├─ Identity Account
   │   ├─ Network Account
   │   ├─ Backup Account
   │   ├─ Operations Tooling Account
   │   └─ Monitoring/Shared Services Account
   │
   ├─ Workloads OU
   │   ├─ Production
   │   │   ├─ Prod App Account #1
   │   │   ├─ Prod App Account #2
   │   │   └─ (Other production accounts)
   │   │
   │   └─ Non-Production
   │       ├─ Dev/Test Account #1
   │       ├─ Dev/Test Account #2
   │       └─ (Other non-prod accounts)
   │
   ├─ Sandbox OU
   │   └─ (Individual sandbox accounts for experimentation)
   │
   ├─ (Optional) Exceptions OU
   │   └─ (Accounts temporarily requiring non-standard policies)
   │
   ├─ (Optional) Transitional OU
   │   └─ (Inbound/outbound acquired accounts or to be divested)
   │
   ├─ (Optional) Policy Staging OU
   │   └─ (Accounts used to test new or updated org policies)
   │
   ├─ (Optional) Suspended OU
   │   └─ (Decommissioned or closed accounts for final processing)
   │
   ├─ (Optional) Deployments OU
   │   └─ (Central CI/CD or pipeline accounts, if separately managed)
   │
   ├─ (Optional) Business Continuity OU
   │   └─ (Accounts dedicated to DR or high-availability scenarios)
   │
   └─ (Optional) Individual Business Users OU
       └─ (Accounts for specific employees or departments)
```

### Notes on Usage

- **Management (Payer) Account**: Top-level account in the organization. It controls consolidated billing and holds the root for AWS Organizations. Do not place production workloads here.
- **Security OU**: Contains Log Archive and Security Tooling (Audit) accounts.  
  - **Log Archive**: Central store for CloudTrail, Config, security, and operational logs.  
  - **Security Tooling**: Central vantage point for AWS Security Hub, GuardDuty, Macie, etc.
- **Infrastructure OU**: Houses shared services and resources (networking, identity, backup, ops toolsets). Owned by infrastructure/ops teams.
- **Workloads OU**: Dedicated application accounts (separating Production and Non-Production). Each production account typically contains a single workload or a small group of related workloads.
- **Sandbox OU**: Highly permissive environment(s) for experimentation, with strict budget/quota guardrails. No sensitive data.
- **Procedural OUs** (Exceptions, Transitional, Policy Staging, Suspended) help handle temporary or edge cases, migration activities, policy testing, or decommissioned accounts.
- **Advanced/Optional OUs** (Deployments, Business Continuity, Individual Business Users) provide further logical separation if your organization has specific needs (CI/CD pipelines, specialized DR/HA setups, or personal departmental accounts).

Use this layout as a reference point for designing your own OU structure while keeping your environment’s security, governance, and operational requirements in mind.

Below is a concise summary of the key points and recommendations from **Organizing Your AWS Environment Using Multiple Accounts**, based on common best practices and patterns outlined in the whitepaper:

---

## 1. **Why Use Multiple AWS Accounts?**

1. **Security and Isolation**  
   - Each AWS account serves as an isolated boundary, helping minimize the blast radius of security or operational issues.
   - Sensitive data can be placed in separate accounts for stricter controls.
2. **Clearer Cost Management**  
   - Costs naturally roll up by account, simplifying billing, forecasting, and chargebacks to internal teams.
3. **Simplified Governance**  
   - Individual accounts allow you to apply targeted policies and compliance rules for different workloads or business units.

---

## 2. **AWS Organizations Basics**

1. **Organization Root & Management Account**  
   - You have a single root, and a management (payer) account owns and oversees all member accounts.
   - Policies applied at the root level affect every account in the organization.
2. **Member Accounts**  
   - Each member account is dedicated to a specific set of workloads or environments.
3. **Organizational Units (OUs)**  
   - OUs group accounts with common requirements (e.g., security, compliance).
   - Service Control Policies (SCPs) can be applied at the OU level to enforce guardrails.
   - Keep OU hierarchy shallow to avoid unnecessary complexity.

---

## 3. **Recommended OU Structure**

The whitepaper proposes a structured approach that often starts with these top-level OUs. You can add or simplify as needed:

1. **Security OU (Foundational)**  
   - *Log Archive account*: Consolidates audit logs (CloudTrail, AWS Config, etc.) in immutable storage for security and compliance.  
   - *Security Tooling (Audit) account*: Centrally manages security services (Security Hub, GuardDuty, Macie), incident response tools, threat detection, and vulnerability scans.
2. **Infrastructure OU (Foundational)**  
   - Houses shared infrastructure resources and related tooling:  
     - *Identity account*: Centralizes IAM Identity Center (federated access) or directories.  
     - *Network account*: Centralizes core networking services (VPC sharing, AWS Network Manager, etc.).  
     - *Operations/Monitoring Tooling account*: Manages operational and monitoring tools (for example, CI/CD, Amazon CloudWatch cross-account dashboards).  
     - *Backup account*: Centralizes AWS Backup, policies, and disaster recovery resources.
3. **Workloads OU**  
   - *Production and Non-Production accounts*: Keep production workloads segregated from dev/test environments for security and governance. Each account can hold a single workload or small group of workloads that share similar risk, compliance, or lifecycle requirements.
4. **Sandbox OU**  
   - For experimentation and builder innovation; typically enforces strict budget or quota controls and contains no sensitive data.
5. **Optional/Advanced OUs**  
   - *Exceptions OU*: Temporary home for accounts needing special approvals or non-standard policies.  
   - *Transitional OU*: Helps migrate external accounts into or out of your organization.  
   - *Policy Staging OU*: Used to test new or updated policies before broader rollout.  
   - *Suspended OU*: Where you park (or close) deprecated or decommissioned accounts.  
   - *Business Continuity OU*: Dedicated for high availability and disaster recovery accounts.  
   - *Deployments OU*: For CI/CD or specialized deployment pipelines, if you want them completely separate from normal workloads.  
   - *Individual Business Users OU*: In very large environments, used if employees require personal or departmental accounts.

---

## 4. **Security Considerations**

1. **Service Control Policies (SCPs)**  
   - Apply SCPs at appropriate OU levels to restrict AWS Regions, API actions, or services as needed.  
   - Use them as guardrails for compliance or to limit the usage of high-risk services.
2. **Federated Access**  
   - Minimize or eliminate long-term IAM users and access keys; use a central identity provider (IdP) (through IAM Identity Center or external SSO) for human user access.  
   - Implement multi-factor authentication (MFA) everywhere, especially on the root user in the management account.
3. **Centralized Logging & Monitoring**  
   - Forward logs from all member accounts to a *Log Archive account*.  
   - Enable AWS Security Hub, GuardDuty, Macie, and other security services in a dedicated *Security Tooling account* for aggregated threat detection.
4. **Backup & Disaster Recovery**  
   - Use a *Backup account* with AWS Backup to automate backups across all accounts.  
   - Consider cross-region or cross-account replication to protect data from region-level or account-level disruptions.

---

## 5. **Operational Best Practices**

1. **Least Privilege**  
   - SCPs, IAM roles, and permission boundaries should reflect least privilege principles.
2. **Automation**  
   - Use AWS CloudFormation StackSets or Infrastructure as Code for consistent account creation and baseline configuration (e.g., logging, compliance checks).
3. **Break Glass Access**  
   - Set up extremely limited, last-resort “break glass” credentials for the management account in case federated access or IdP is compromised or unavailable.
4. **Expand Gradually**  
   - Start with a minimal set of OUs and accounts. Evolve and add new OUs only if clear security, compliance, or operational requirements justify it.

---

## 6. **Key Takeaways**

1. **Simplify Your Hierarchy**  
   - Don’t overcomplicate your OU structure. Keep it shallow and intuitive.
2. **Segment Workloads**  
   - Isolate production from development/test, separate high-risk or sensitive workloads, and use dedicated accounts for logging, security, networking, and operations.
3. **Leverage AWS Organization Delegated Admin Features**  
   - Many AWS services support delegated administration so that day-to-day operations can happen outside the management account.
4. **Continuous Improvement**  
   - Regularly review your account structure, security guardrails, and governance controls. Adjust as your organization grows and compliance or business needs change.

---

### In Summary

**Organizing Your AWS Environment Using Multiple Accounts** advocates a structured, multi-account strategy that partitions workloads, infrastructure, and security functionalities into dedicated accounts within a centralized AWS Organization. This approach simplifies governance, clarifies cost allocation, and strengthens security boundaries. By starting with a foundational OU structure (Security and Infrastructure), then expanding to workload-specific and procedural OUs, you can adapt to evolving business and regulatory demands while maintaining robust isolation and control.
