
# Dynamic Authorization

## Why SAML & OAuth Fail to Solve Fine-Grained Authorization

1. **OAuth is for Access Delegation, Not Authorization**:
   OAuth primarily focuses on **delegating access** to resources, rather than managing granular **authorization**. OAuth allows a user to grant a third-party application limited access to their resources (such as reading an email or accessing a file) without sharing their credentials. OAuth works by issuing access tokens that allow users to delegate permissions to another system for specific tasks, but it doesn't natively define what actions a user can **do** within an application beyond granting access.

   **Limitations of OAuth**:
   - **Lack of fine-grained control**: OAuth specifies what resources can be accessed, but it doesn’t go further to control what actions a user can perform on those resources. For example, OAuth can grant read or write access to a file, but it can't define if a user can delete the file or modify its content.
   - **Scope-based permissions**: OAuth defines permissions through scopes, which are essentially tags indicating the level of access granted. Scopes are coarse and do not define detailed or fine-grained actions like "can edit" or "can delete."

   OAuth is great for **access delegation**, but not for **fine-grained control** of user actions within an app.

2. **SAML and Fine-Grained Authorization**:
   SAML (Security Assertion Markup Language) is a **federated authentication** standard used for SSO (Single Sign-On). It’s mainly used for authenticating users and enabling access to applications without needing to re-enter credentials. While SAML helps determine **who the user is**, it doesn't directly manage **what the user can do** after authentication.

   **Limitations of SAML**:
   - **Authentication, not authorization**: SAML's primary focus is authentication (confirming the user's identity), not authorization (defining the user's permissions and roles). After authentication, SAML doesn't provide a mechanism to specify what actions the user can perform in an application, making it difficult to manage fine-grained access controls.
   - **Lack of dynamic authorization**: SAML assertions are static. Once the user is authenticated, the SAML assertion is processed, and access is granted, but the system doesn’t dynamically check for fine-grained permissions at each step (e.g., whether a user can edit a document, or only view it).

3. **Limitations of OAuth and SAML Tokens**:
   - **Limited Token Information**: OAuth and SAML tokens often provide limited context about the user's roles or permissions. These tokens generally only indicate authentication status or delegated access rights, and don't carry detailed information about what a user can or cannot do in an application. Fine-grained authorization requires deeper, contextual information about the user’s actions and the resources involved, which cannot be fully conveyed through OAuth or SAML tokens alone.
   - **Short-Lived Tokens**: OAuth tokens (such as access tokens) are often short-lived, which means they might need frequent refreshes. This can complicate authorization decisions since tokens may expire before authorization decisions can be made, necessitating constant re-evaluation.
   - **Lack of Policy Enforcement**: Neither OAuth nor SAML provides built-in mechanisms for policy enforcement; they depend on the system that interprets the token to manage what the user can actually do once authenticated. This leads to potential inconsistencies between systems, especially in complex environments with many services.

---

### Summary of ACL, RBAC, ABAC, and ReBAC

#### 1. **ACL (Access Control List)**

- **Definition**: ACL is a list of permissions attached to a resource (like a file or directory) specifying which users or groups can access it and what actions they can perform (e.g., read, write, execute).
- **Key Feature**: It directly ties access to specific users or groups, meaning that each resource maintains its own access control list.
- **Usage**: Commonly used in file systems or databases to control access to specific resources.
- **Identity-Centric**: ACL is identity-centric because access decisions are based on the identity of the user or group. Permissions are explicitly granted to individuals or groups, without considering broader context or attributes.

#### 2. **RBAC (Role-Based Access Control)**

- **Definition**: RBAC assigns permissions based on roles, rather than individual identities. Users are assigned to roles (e.g., Admin, Manager, Employee), and roles are associated with specific permissions.
- **Key Feature**: Simplifies access control by managing roles rather than individual user permissions. A user inherits permissions based on the role they are assigned.
- **Usage**: Widely used in enterprise environments for managing large user bases.
- **Identity-Centric**: RBAC is also identity-centric because users are granted access based on their assigned roles, and roles are linked to user identities. It focuses on **who** the user is and their role within the organization rather than dynamic attributes.

#### 3. **ABAC (Attribute-Based Access Control)**

- **Definition**: ABAC grants access based on attributes (user attributes, resource attributes, and environmental conditions). Access decisions are made based on a set of policies that combine these attributes.
- **Key Feature**: More flexible and dynamic than ACL or RBAC. It allows fine-grained control and can adapt to changing contexts (e.g., time of day, location, or device type).
- **Usage**: Suitable for complex systems where access policies need to take into account many factors.
- **Not Identity-Centric**: ABAC moves away from identity-centric controls and instead focuses on **attributes** of users, resources, and the environment. This allows policies to be more dynamic and context-sensitive, considering both the **who** (user) and the **what** (resource) attributes to determine access.

#### 4. **ReBAC (Relationship-Based Access Control)**

- **Definition**: ReBAC controls access based on the relationships between users and resources (or other entities). Access is granted based on the specific relationships users have with resources (e.g., a user can access a document if they are a collaborator on that document).
- **Key Feature**: Focuses on dynamic relationships, making it particularly useful in collaborative environments.
- **Usage**: Ideal for systems where access depends on users' associations (e.g., social networks, collaborative platforms, project management tools).
- **Not Identity-Centric**: ReBAC is also not identity-centric. Instead, it grants or denies access based on the relationships between users and resources, emphasizing the **who** (the user) and **what** (the resource) in the context of their **relationship**.

---

### Why ACL and RBAC are Identity-Centric vs. ABAC and ReBAC Consider Resource

- **Identity-Centric Access Control** (ACL and RBAC):
  - **ACL** and **RBAC** are considered **identity-centric** because the primary determinant for access control is the **identity of the user** or the **role assigned** to the user. These models focus on what the user (or user group) is **allowed to do** based on who they are (e.g., what role they hold, or which permissions are granted to them).
  - **ACL** specifies which users or groups can access which resources and the actions they can take. **RBAC** assigns roles to users, and each role has associated permissions, again focusing on what users can do based on their identity (e.g., "admin," "employee").
  
- **Resource-Centric Access Control** (ABAC and ReBAC):
  - **ABAC** and **ReBAC** consider **resources** in addition to users' identities. These models are not solely dependent on who the user is (identity) but on a broader set of factors such as the attributes of the user (e.g., department, clearance level), the attributes of the resource (e.g., file sensitivity), and the **contextual relationships** (e.g., a user is allowed access to a document because they are part of the project team).
  - **ABAC** evaluates policies based on a combination of attributes, where access is granted based on a dynamic evaluation of the context (e.g., the user’s department, role, time of day, resource sensitivity). In ABAC, access decisions are made considering **both** the user and the resource, with additional attributes affecting the decision.
  - **ReBAC** specifically focuses on the **relationship** between the user and the resource, meaning access control is granted based on whether the user has an appropriate relationship with the resource (e.g., collaborator, owner).

### Policy Enforcement Architecture: PEP, PDP, PAP, PIP

To achieve **centralized authorization**, modern systems often implement an architecture based on four main components:

1. **PEP (Policy Enforcement Point)**: The PEP is the component that enforces the authorization decision made by the PDP. It intercepts requests from users and verifies whether the user has permission to perform the requested action (based on policies).

2. **PDP (Policy Decision Point)**: The PDP is the central component that makes the decision regarding whether a user is authorized to perform a particular action based on the policies defined. It evaluates requests in real-time and makes access control decisions.

3. **PAP (Policy Administration Point)**: The PAP is responsible for managing and defining the policies that govern the authorization system. It is used by administrators to create, update, and delete policies, which are then used by the PDP to make authorization decisions.

4. **PIP (Policy Information Point)**: The PIP provides additional information needed by the PDP to make an authorization decision. This could include data about the user (such as roles, attributes, or relationships) or about the resource being accessed (such as its state or sensitivity level).

---

### Real-World Policy Engines and How They Map to General Architecture

Several modern policy engines have been developed to implement centralized authorization in real-world systems. These engines typically align with the components of PEP, PDP, PAP, and PIP:

1. **Cedar**:
   Cedar is a policy language developed by Amazon Web Services (AWS) designed for fine-grained access control in cloud environments. It supports complex authorization policies based on the relationships between users, resources, and contexts. In the architecture:
   - **PEP**: The service that handles the request for resource access (e.g., AWS service or application).
   - **PDP**: Cedar's policy evaluation engine, which evaluates policies in real-time and provides authorization decisions.
   - **PAP**: Administrators use the Cedar policy editor to create and manage access control policies.
   - **PIP**: The data source that provides contextual information (e.g., user roles, resource metadata) for policy evaluation.

2. **Zanzibar (by Google)**:
   Zanzibar is an authorization system developed by Google to provide consistent, scalable, and flexible access control across its services. It implements **relationship-based access control (ReBAC)** and leverages a distributed policy engine.
   - **PEP**: The service making the access request, such as an API or application.
   - **PDP**: The Zanzibar system, which evaluates the relationships between users and resources and returns an access decision.
   - **PAP**: Zanzibar's policy management interface, where policies are defined based on relationships, roles, and attributes.
   - **PIP**: Zanzibar’s internal systems that provide the contextual data required for policy evaluation (e.g., user roles, resource associations).

3. **OPA (Open Policy Agent)**:
   OPA is an open-source policy engine that provides a unified approach to access control across different systems. It is highly flexible and can integrate with a wide variety of systems, including cloud, Kubernetes, and microservices.
   - **PEP**: Any system that needs to enforce authorization decisions, such as an API gateway or microservice.
   - **PDP**: The OPA engine itself, which evaluates policies written in the Rego language.
   - **PAP**: OPA policies are managed and updated by administrators using the OPA CLI or integrated management tools.
   - **PIP**: External data sources or APIs that provide contextual information (e.g., external databases, user attributes).

4. **Topaz**:
   Topaz is another policy engine, particularly useful in securing Kubernetes and cloud-native applications. It enables fine-grained access control based on dynamic factors like user identity and resource attributes.
   - **PEP**: The services that need to enforce policies (e.g., Kubernetes API server).
   - **PDP**: Topaz’s policy evaluation engine, which makes decisions based on the policies defined by administrators.
   - **PAP**: Policy creation and administration tools provided by Topaz.
   - **PIP**: Topaz integrates with various sources to collect user attributes, roles, and resource details to inform policy decisions.

---

### Conclusion

Centralized authorization is crucial for managing consistent and secure access across multiple systems. While **OAuth** and **SAML** focus on authentication and access delegation, they fall short for **fine-grained authorization**. Systems like **ReBAC** (Relationship-Based Access Control) and policy engines (Cedar, Zanzibar, OPA, Topaz)
---

### **Policy as Code vs. Policy as Data: Extended View**

#### **Topaz**

Topaz, part of the **Permit.io** framework, is designed for fine-grained access control and implements principles from both **policy as code** and **policy as data**:

- **Policy as Code**: Topaz supports policies written in OPA’s **Rego** language, enabling logic-based policy definition and decision-making.
- **Policy as Data**: It integrates with structured datasets (e.g., relationships or user attributes) to simplify dynamic policy evaluation and scaling in distributed systems.

Topaz is notable for bridging **policy as code** and **policy as data** paradigms:

- Provides a developer-friendly interface for writing policy logic.
- Offers APIs for dynamic policy evaluation and relationship-based access control, akin to Zanzibar’s model.

---

### **Central Authorization Architecture: PEP, PDP, PE, PA**

A central authorization system typically consists of these components:

1. **Policy Enforcement Point (PEP)**:
   - **Role**: Intercepts user actions and sends authorization requests to the PDP.
   - **Relevance to Policy as Code**:
     - PEPs forward necessary context (user, resource, action) to the PDP for decision-making based on policies written as code or represented as data.
   - **Examples**:
     - OPA can act as a PEP by embedding policy evaluation logic directly in applications.
     - Topaz’s enforcement modules handle real-time requests and integrate with APIs.

2. **Policy Decision Point (PDP)**:
   - **Role**: Evaluates the policies and returns allow/deny decisions.
   - **Relevance to Policy as Code**:
     - The PDP interprets policy logic (e.g., Rego in OPA, Cedar’s DSL, Topaz policies) to make decisions.
   - **Examples**:
     - OPA acts as a PDP by evaluating Rego policies.
     - Zanzibar’s PDP evaluates tuple-based relationships.
     - Cedar combines DSL-defined policies with input data for decisions.

3. **Policy Engine (PE)**:
   - **Role**: Executes the underlying logic of policies.
   - **Relevance to Policy as Code**:
     - For **policy as code**, the PE interprets the logic defined in a DSL.
     - For **policy as data**, the PE resolves queries (e.g., evaluating relationships or attribute-based rules).
   - **Examples**:
     - Zanzibar’s graph-based traversal acts as a policy engine.
     - OPA’s Rego evaluation engine handles logic-driven policies.

4. **Policy Administration (PA)**:
   - **Role**: Manages, stores, and updates policies.
   - **Relevance to Policy as Code**:
     - For **policy as code**, administrators define and version control policies (e.g., Rego or Cedar files).
     - For **policy as data**, administrators manage relationship data (e.g., tuples in Zanzibar or Topaz’s database).
   - **Examples**:
     - OPA’s tooling integrates with CI/CD pipelines for policy updates.
     - Zanzibar uses a centralized datastore to manage relationships.

---

### **Policy as Code in Central Authorization Architecture**

#### How it Fits

1. **Authoring**:
   - Developers or administrators write policy logic using DSLs (e.g., Rego, Cedar).
   - Policies are version-controlled in source code repositories or managed via APIs (e.g., Topaz).

2. **Evaluation**:
   - The PDP and PE rely on the execution of the policy code during request evaluation.
   - Example: When a user requests access, the PDP evaluates the policy code based on provided attributes.

3. **Enforcement**:
   - PEPs act on decisions made by PDPs after evaluating the code.

#### Strengths of Policy as Code

- **Flexibility**: Supports highly complex, conditional logic.
- **Audibility**: Policies stored in code repositories are auditable and version-controlled.
- **Testing**: Policies can be unit-tested like any other code.

---

### **Hybrid Models in Practice**

**Topaz** bridges the gap between **policy as code** and **policy as data** by:

- Allowing policies to be written in Rego (code).
- Managing relationship-based data for scalable evaluation.

**Google Zanzibar** focuses heavily on **policy as data**, while **OPA** and **Cedar** are firmly in the **policy as code** camp.

In real-world architectures, combining these paradigms often leads to robust systems:

- **Policy as Code** is used for complex decision logic.
- **Policy as Data** handles relationships, attributes, and scalable, distributed data storage.

---

### Comparative Summary

| **Feature**         | **OPA**               | **Cedar**            | **Zanzibar**         | **Topaz**             |
|----------------------|-----------------------|----------------------|----------------------|-----------------------|
| **Primary Model**    | Policy as Code       | Policy as Code       | Policy as Data       | Hybrid (Code + Data)  |
| **Policy Language**  | Rego                 | Cedar DSL            | Tuple data           | Rego + APIs           |
| **Data Focus**       | Inputs for Rego      | Structured inputs    | Tuple relationships  | Relationship data     |
| **Use Cases**        | Fine-grained logic   | Authorization rules  | Large-scale RBAC     | Mixed use cases       |

In central authorization systems, integrating policy as code and policy as data maximizes flexibility, scalability, and maintainability.

## AWS Verified Permissions Architecture & Key Components

AWS Verified Permissions is a service designed to provide fine-grained access control for applications. It allows developers to externalize authorization logic from their applications, ensuring centralized, dynamic, and flexible access management. Below is an explanation of its architecture and key components:

---

## **Architecture**

The AWS Verified Permissions architecture includes the following major components:

1. **Policy Store:**
   - A central repository for policies that define access rules.
   - Stores information about:
     - Resources (what needs protection).
     - Actions (what users or services want to do).
     - Conditions (contextual factors like time or location).

2. **Access Decision API:**
   - A service API used by applications to query for access decisions.
   - Evaluates policies in real-time based on:
     - The user’s attributes.
     - The requested action.
     - The resource involved.
   - Ensures that access decisions are always up-to-date and consistent.

3. **Schema:**
   - Defines the structure of resources, actions, and attributes in the system.
   - Acts as a blueprint for creating consistent policies across the application.

4. **Policy Authoring:**
   - Policies can be written in JSON or a domain-specific language (DSL).
   - These policies may follow various access control models:
     - **RBAC (Role-Based Access Control):** Based on roles assigned to users.
     - **ABAC (Attribute-Based Access Control):** Based on attributes such as user department, time, or location.
     - **Custom Models:** Tailored to application-specific requirements.

5. **Identity Providers (IdPs):**
   - Integrates with external identity providers like:
     - AWS IAM Identity Center.
     - AWS Cognito.
     - Third-party IdPs (e.g., Okta, Azure AD).
   - Provides identity and attribute data for access decisions.

6. **Event Logging and Monitoring:**
   - Tracks authorization decisions for auditing and compliance.
   - Integrates with AWS services like CloudTrail and CloudWatch for real-time monitoring.

---

### **Key Components**

1. **Policy Store:**
   - Central hub for managing and storing policies.
   - Policies define the "who, what, and when" of access control.

2. **Access Decisions API:**
   - Provides dynamic, real-time decision-making.
   - Can evaluate complex conditions and integrate application-specific logic.

3. **Identity Providers:**
   - Supplies user attributes for evaluation (e.g., role, group, or department).
   - Ensures seamless authentication and identity management.

4. **Schema:**
   - Provides a structured approach to modeling resources and actions.
   - Ensures consistent definitions across policies.

5. **Policy Management Console/SDK:**
   - Enables developers or administrators to create, test, and manage policies.
   - Provides tools for version control and policy validation.

6. **Fine-Grained Policies:**
   - Policies can handle highly specific use cases:
     - Conditional access based on user attributes or resource states.
     - Temporary access using time-bound conditions.
   - Supports ABAC, RBAC, or hybrid models.

---

### **How It Works**

1. **Policy Authoring:**
   - Define policies in the policy store using JSON or DSL.
   - Policies include information about:
     - Users or roles.
     - Resources.
     - Actions and conditions.

2. **Application Integration:**
   - Applications use the Access Decisions API to query whether a user is authorized to perform an action on a resource.

3. **Decision Evaluation:**
   - When an access request is made, the API evaluates policies based on:
     - User attributes from the IdP.
     - The resource and requested action.
     - Additional conditions (e.g., time of day or IP address).

4. **Real-Time Enforcement:**
   - The API returns a decision (`ALLOW` or `DENY`), which the application enforces.

5. **Auditing and Monitoring:**
   - Decisions are logged for compliance and debugging purposes.
   - Logs provide insight into why a decision was made.

---

### **Example Use Cases**

1. **Multi-Tenant SaaS Applications:**
   - Define tenant-specific policies to ensure data isolation and appropriate access control.

2. **Dynamic Access Control:**
   - Allow temporary access based on a specific event (e.g., approval workflow or incident response).

3. **Compliance and Auditing:**
   - Use fine-grained policies to enforce compliance requirements like GDPR or HIPAA.

4. **Attribute-Based Access Control (ABAC):**
   - Restrict access to resources based on dynamic attributes like user department, geographical location, or project assignment.

---

### **Benefits of AWS Verified Permissions**

1. **Centralized Management:**
   - Policies are managed and stored in a single location, simplifying updates and ensuring consistency.

2. **Dynamic and Flexible:**
   - Policies can be updated and evaluated in real-time, adapting to changing business requirements.

3. **Fine-Grained Access:**
   - Supports advanced use cases like ABAC and multi-tenant applications.

4. **Seamless Integration:**
   - Works with existing AWS and third-party identity systems, making implementation straightforward.

5. **Enhanced Security:**
   - Eliminates hard-coded access control logic in applications, reducing the risk of errors or inconsistencies.

AWS Verified Permissions empowers developers to externalize and centralize authorization, enabling secure, scalable, and highly flexible access control for modern applications.

### **Integrating AWS Verified Permissions with Existing Enterprise Applications**

AWS Verified Permissions can be seamlessly integrated with existing enterprise applications to enhance their access control capabilities. This is particularly valuable for enterprises seeking centralized, fine-grained access control across multiple applications while leveraging existing infrastructure like identity providers (IdPs), schemas, and logging frameworks. Here's how this integration works:

---

### **1. Key Integration Steps**

#### **Step 1: Assess Current Access Control Model**

- Evaluate how access control is currently implemented in the enterprise application:
  - Is it role-based, attribute-based, or hybrid?
  - Are there hard-coded permissions in the application?
- Identify pain points (e.g., inconsistent policies, manual updates, lack of auditing).

#### **Step 2: Integrate with Identity Provider (IdP)**

- **Requirement:** The existing application must authenticate users via an IdP.
- **Action:**
  - Connect AWS Verified Permissions to the enterprise IdP (e.g., AWS IAM Identity Center, Okta, Azure AD).
  - Use the IdP to provide user attributes like roles, groups, or departments for policy evaluation.
- **Outcome:** User identity and attributes become available for dynamic access control.

#### **Step 3: Define Schema for Resources and Actions**

- **Requirement:** Map application-specific resources and actions to a schema.
- **Action:**
  - Create a schema in AWS Verified Permissions that models application entities.
  - Example: For an HR application, resources might include "employee records," and actions might include "read," "update," or "delete."
- **Outcome:** Ensures that policies are structured consistently across the enterprise.

#### **Step 4: Migrate or Create Policies**

- **Requirement:** Rewrite existing access control rules as Verified Permissions policies.
- **Action:**
  - If policies are scattered across the application, centralize them in the AWS Verified Permissions policy store.
  - Use a hybrid approach where existing coarse-grained roles are combined with fine-grained Verified Permissions policies for specific actions.
- **Outcome:** Policies are easier to manage, audit, and modify centrally.

#### **Step 5: Integrate Access Decision API**

- **Requirement:** Replace hard-coded access control checks with Verified Permissions API calls.
- **Action:**
  - Modify application code to query the AWS Verified Permissions **Access Decision API** for authorization decisions at runtime.
  - Example: Instead of checking `user.role === 'admin'`, call the API to check if the user has the required permission to perform the action.
- **Outcome:** The application externalizes its access control logic and adheres to centralized policies.

#### **Step 6: Enable Logging and Monitoring**

- **Requirement:** Integrate with enterprise monitoring tools for auditing and compliance.
- **Action:**
  - Use AWS CloudTrail and CloudWatch to track authorization decisions.
  - Correlate these logs with existing enterprise monitoring tools.
- **Outcome:** Authorization decisions are auditable and comply with regulatory standards.

---

### **2. Benefits of Integration**

1. **Centralized Policy Management:**
   - Avoid fragmented and inconsistent access control rules across multiple applications.
   - Simplify updates and audits through a single policy store.

2. **Dynamic and Fine-Grained Access Control:**
   - Replace static, hard-coded roles with policies that consider real-time attributes like location, time, and user roles.

3. **Scalability:**
   - Manage complex, multi-tenant environments with ease.
   - Support enterprise applications running at scale across multiple regions or teams.

4. **Reduced Development Overhead:**
   - Offload the complexity of access control logic to AWS Verified Permissions.
   - Developers can focus on building core application features.

5. **Improved Security and Compliance:**
   - Enforce least-privilege access dynamically.
   - Ensure adherence to compliance standards like GDPR, HIPAA, or SOC 2.

---

### **Real-World Scenarios**

#### **Scenario 1: Employee Management System**

- **Current Setup:** Hard-coded roles (e.g., admin, HR, manager) with limited flexibility.
- **Integration Steps:**
  - Define resources (e.g., employee records) and actions (e.g., view, update).
  - Use the Access Decision API to enforce fine-grained permissions like "managers can only view employees in their department."
- **Outcome:** The system supports dynamic, attribute-based access without code changes for every new requirement.

#### **Scenario 2: Financial Services Application**

- **Current Setup:** A hybrid access model using RBAC and custom scripts.
- **Integration Steps:**
  - Replace custom scripts with Verified Permissions policies.
  - Use the IdP to supply attributes like "user clearance level" or "account type."
  - Enforce time-based access for sensitive actions like wire transfers.
- **Outcome:** A more secure and auditable access control system.

#### **Scenario 3: SaaS Application with Multi-Tenancy**

- **Current Setup:** Access control is implemented per tenant, leading to redundant code.
- **Integration Steps:**
  - Define tenants as a resource attribute in the schema.
  - Centralize policies to enforce tenant isolation and cross-tenant restrictions.
- **Outcome:** Simplified policy management and consistent enforcement across all tenants.

---

### **Pre-Requisites for Enterprises**

To effectively integrate AWS Verified Permissions into existing enterprise applications:

1. **Modernized Infrastructure:**
   - Applications should support API-based integrations.
   - Adopt microservices for modular access control implementation.
2. **Comprehensive Identity Management:**
   - Ensure a robust identity provider (IdP) system is in place.
3. **Policy Migration Plan:**
   - Develop a strategy to migrate or rewrite existing access control rules.
4. **Team Enablement:**
   - Train developers and administrators on Verified Permissions features and policy authoring.

---

## Policy Engines OPA,Cedar,Topaz Showdown

Here's an extended explanation incorporating **Topaz** and how "Policy as Code" fits into a central authorization architecture that includes **PEP (Policy Enforcement Point)**, **PDP (Policy Decision Point)**, **PE (Policy Engine)**, and **PA (Policy Administration)**.

---

### **Policy as Code vs. Policy as Data: Extended View**

#### **Topaz**

Topaz, part of the **Permit.io** framework, is designed for fine-grained access control and implements principles from both **policy as code** and **policy as data**:

- **Policy as Code**: Topaz supports policies written in OPA’s **Rego** language, enabling logic-based policy definition and decision-making.
- **Policy as Data**: It integrates with structured datasets (e.g., relationships or user attributes) to simplify dynamic policy evaluation and scaling in distributed systems.

Topaz is notable for bridging **policy as code** and **policy as data** paradigms:

- Provides a developer-friendly interface for writing policy logic.
- Offers APIs for dynamic policy evaluation and relationship-based access control, akin to Zanzibar’s model.

---

### **Central Authorization Architecture: PEP, PDP, PE, PA**

A central authorization system typically consists of these components:

1. **Policy Enforcement Point (PEP)**:
   - **Role**: Intercepts user actions and sends authorization requests to the PDP.
   - **Relevance to Policy as Code**:
     - PEPs forward necessary context (user, resource, action) to the PDP for decision-making based on policies written as code or represented as data.
   - **Examples**:
     - OPA can act as a PEP by embedding policy evaluation logic directly in applications.
     - Topaz’s enforcement modules handle real-time requests and integrate with APIs.

2. **Policy Decision Point (PDP)**:
   - **Role**: Evaluates the policies and returns allow/deny decisions.
   - **Relevance to Policy as Code**:
     - The PDP interprets policy logic (e.g., Rego in OPA, Cedar’s DSL, Topaz policies) to make decisions.
   - **Examples**:
     - OPA acts as a PDP by evaluating Rego policies.
     - Zanzibar’s PDP evaluates tuple-based relationships.
     - Cedar combines DSL-defined policies with input data for decisions.

3. **Policy Engine (PE)**:
   - **Role**: Executes the underlying logic of policies.
   - **Relevance to Policy as Code**:
     - For **policy as code**, the PE interprets the logic defined in a DSL.
     - For **policy as data**, the PE resolves queries (e.g., evaluating relationships or attribute-based rules).
   - **Examples**:
     - Zanzibar’s graph-based traversal acts as a policy engine.
     - OPA’s Rego evaluation engine handles logic-driven policies.

4. **Policy Administration (PA)**:
   - **Role**: Manages, stores, and updates policies.
   - **Relevance to Policy as Code**:
     - For **policy as code**, administrators define and version control policies (e.g., Rego or Cedar files).
     - For **policy as data**, administrators manage relationship data (e.g., tuples in Zanzibar or Topaz’s database).
   - **Examples**:
     - OPA’s tooling integrates with CI/CD pipelines for policy updates.
     - Zanzibar uses a centralized datastore to manage relationships.

---

### **Policy as Code in Central Authorization Architecture**

#### How it Fits

1. **Authoring**:
   - Developers or administrators write policy logic using DSLs (e.g., Rego, Cedar).
   - Policies are version-controlled in source code repositories or managed via APIs (e.g., Topaz).

2. **Evaluation**:
   - The PDP and PE rely on the execution of the policy code during request evaluation.
   - Example: When a user requests access, the PDP evaluates the policy code based on provided attributes.

3. **Enforcement**:
   - PEPs act on decisions made by PDPs after evaluating the code.

#### Strengths of Policy as Code

- **Flexibility**: Supports highly complex, conditional logic.
- **Audibility**: Policies stored in code repositories are auditable and version-controlled.
- **Testing**: Policies can be unit-tested like any other code.

---

### **Hybrid Models in Practice**

**Topaz** bridges the gap between **policy as code** and **policy as data** by:

- Allowing policies to be written in Rego (code).
- Managing relationship-based data for scalable evaluation.

**Google Zanzibar** focuses heavily on **policy as data**, while **OPA** and **Cedar** are firmly in the **policy as code** camp.

In real-world architectures, combining these paradigms often leads to robust systems:

- **Policy as Code** is used for complex decision logic.
- **Policy as Data** handles relationships, attributes, and scalable, distributed data storage.

---

### Comparative Summary

| **Feature**         | **OPA**               | **Cedar**            | **Zanzibar**         | **Topaz**             |
|----------------------|-----------------------|----------------------|----------------------|-----------------------|
| **Primary Model**    | Policy as Code       | Policy as Code       | Policy as Data       | Hybrid (Code + Data)  |
| **Policy Language**  | Rego                 | Cedar DSL            | Tuple data           | Rego + APIs           |
| **Data Focus**       | Inputs for Rego      | Structured inputs    | Tuple relationships  | Relationship data     |
| **Use Cases**        | Fine-grained logic   | Authorization rules  | Large-scale RBAC     | Mixed use cases       |

In central authorization systems, integrating policy as code and policy as data maximizes flexibility, scalability, and maintainability.
