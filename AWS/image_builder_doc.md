# AWS Image Builder Overview

---

## Image Builder Componets Diagram 

```plaintext
AWS Image Builder
├── Image Pipeline
│   ├── Scheduling & Triggers
│   └── Contains Image Recipe(s)
│         └── Image Recipe
│              ├── Base Image
│              └── Components (Ordered Steps)
│                    ├── Component 1
│                    ├── Component 2
│                    └── ... (additional components)
├── Infrastructure Configuration
│   ├── Instance Type & Network Settings
│   ├── Subnet, Security Groups, IAM Role
│   └── Defines the Build Environment
├── Testing Configuration (Optional)
│   ├── Automated Quality & Security Tests
│   └── Ensures Compliance before Distribution
└── Distribution Configuration
    ├── Target Regions & Accounts
    ├── Permissions and Sharing Settings
    └── Tagging & Versioning for Image Management
```


### 1. Image Pipeline

- **Definition:**  
  The Image Pipeline orchestrates the complete image creation process.
- **Key Points:**
  - **Scheduling & Triggers:**  
    Allows you to run the pipeline on a schedule (daily, weekly, etc.) or on-demand.
  - **Orchestration:**  
    Combines all components of the image creation process from start to finish.
  - **Containment of Recipes:**  
    The pipeline includes one or more Image Recipes, each defining how to build a particular image.

---

### 2. Image Recipe

- **Definition:**  
  A blueprint that details how to construct your final image.
- **Key Points:**
  - **Base Image:**  
    Serves as the foundation (e.g., RHEL image or Windows Server image).
  - **Components:**  
    A series of ordered steps that apply changes to the base image. These may include software installations, configuration changes, security patches, or custom scripts.
  - **Customization & Reusability:**  
    Recipes can be parameterized for customization and reused across different pipelines or environments.

---

### 3. Components

- **Definition:**  
  The individual building blocks executed as part of an image recipe.
- **Key Points:**
  - **Modular & Versioned:**  
    Components are independent, version-controlled scripts or configuration steps that can be reused across recipes.
  - **Ordered Execution:**  
    They run in a specified order to ensure that changes are applied consistently.
  - **Actions Performed:**  
    May include installing software, applying updates, configuring settings, and other custom actions.

---

### 4. Infrastructure Configuration

- **Definition:**  
  Specifies the environment settings used during the image build.
- **Key Points:**
  - **Compute & Network Settings:**  
    Defines the instance type, subnet, and security groups.
  - **Security:**  
    Uses IAM roles to securely manage the build process.
  - **Consistency:**  
    Ensures every build is run in a predictable, controlled environment.

---

### 5. Testing Configuration (Optional)

- **Definition:**  
  Optional automated testing applied to the built image.
- **Key Points:**
  - **Automated Testing:**  
    Runs tests to verify the image meets quality, security, and compliance standards.
  - **Quality Assurance:**  
    Ensures that only images passing all tests are distributed.
  - **Safety Net:**  
    Helps catch configuration errors or vulnerabilities before the image is used in production.

---

### 6. Distribution Configuration

- **Definition:**  
  Governs how the final, validated image is distributed and shared.
- **Key Points:**
  - **Targeting:**  
    Specifies the AWS regions and accounts where the image will be available.
  - **Permissions & Sharing:**  
    Controls who can access or launch the image through IAM policies and sharing settings.
  - **Tagging & Versioning:**  
    Helps manage and track images across different environments, ensuring easy identification and updates.

---

## In Summary

- **AWS Image Builder** automates and standardizes the image creation process, reducing manual intervention.
- **Hierarchy Overview:**  
  The **Image Pipeline** houses one or more **Image Recipes**. Each recipe starts with a **Base Image** and applies a series of **Components** to create the final image.
- **Supporting Configurations:**  
  **Infrastructure Configuration** defines the build environment, **Testing Configuration** (if used) ensures quality and compliance, and **Distribution Configuration** handles image dissemination.
- **Key Benefits:**
  - **Automation & Consistency:**  
    Automated pipelines and controlled environments ensure images are consistently built and up to date.
  - **Modularity & Reusability:**  
    Reusable components and customizable recipes make it easy to maintain and update images.
  - **Security & Compliance:**  
    Built-in testing and controlled distribution maintain a strong security posture.
  - **Scalability:**  
    The pipeline can be scaled and scheduled to produce images across multiple regions and accounts effortlessly.

Based on the provided Terraform code, here are the recipes and components for RHEL8 and RHEL9 builds:

### RHEL8 Build

#### Image Recipe
- **Base Image**: RHEL8 Base Image
- **Components**:
  1. `aws_imagebuilder_component.rhel8_baseline_components` (version 8.10.0)
  2. `aws_imagebuilder_component.rhel8_baseline_stig` (version 8.10.0)
  3. `aws_imagebuilder_component.rhel8_baseline_stig_ansible` (version 8.10.0)
  4. `aws_imagebuilder_component.rhel8_eks_worker` (version 8.0.0)
  5. AWS CLI v2 Update Component
  6. Powershell for Linux - via Yum
  7. Reboot During Build Phase
  8. Reboot During Test Phase

#### EKS Worker Image Recipe
- **Base Image**: RHEL8 Base Image
- **Components**:
  1. `aws_imagebuilder_component.rhel8_baseline_components` (version 8.10.0)
  2. `aws_imagebuilder_component.rhel8_baseline_stig` (version 8.10.0)
  3. `aws_imagebuilder_component.rhel8_baseline_stig_ansible` (version 8.10.0)
  4. `aws_imagebuilder_component.rhel8_eks_worker` (version 8.0.0)
  5. AWS CLI v2 Update Component
  6. Powershell for Linux - via Yum
  7. Reboot During Build Phase
  8. Reboot During Test Phase

### RHEL9 Build

#### Image Recipe
- **Base Image**: RHEL9 Base Image
- **Components**:
  1. `aws_imagebuilder_component.rhel9_baseline_components` (version 9.0.0)
  2. `aws_imagebuilder_component.rhel9_baseline_stig` (version 9.0.0)
  3. `aws_imagebuilder_component.rhel9_baseline_stig_ansible` (version 9.0.0)
  4. AWS CLI v2 Update Component
  5. Powershell for Linux - via Yum
  6. Reboot During Build Phase
  7. Reboot During Test Phase

#### EKS Worker Image Recipe
- **Base Image**: RHEL9 Base Image
- **Components**:
  1. `aws_imagebuilder_component.rhel9_baseline_components` (version 9.0.0)
  2. `aws_imagebuilder_component.rhel9_baseline_stig` (version 9.0.0)
  3. `aws_imagebuilder_component.rhel9_baseline_stig_ansible` (version 9.0.0)
  4. `aws_imagebuilder_component.rhel9_eks_worker` (version 9.0.0)
  5. AWS CLI v2 Update Component
  6. Powershell for Linux - via Yum
  7. Reboot During Build Phase
  8. Reboot During Test Phase

### Additional Components (AWS Provided)
- AWS CLI Installer
- STIG High
- Powershell Linux (yum)
- Powershell Linux 7.2.13
- Reboot TEST

Ensure to update the version strings in the Terraform code to match the version of RHEL (8.0.X or 9.0.X) and the specific revisions as needed.

Certainly! Here is the updated table format with an additional column for notes and a larger width for the comments column:

### RHEL8 Build

#### Image Recipe

| Component Name                          | Version  | Notes                                                                                   |
|-----------------------------------------|----------|-----------------------------------------------------------------------------------------|
| RHEL8 Base Image                        | N/A      |                                                                                         |
| rhel8_baseline_components               | 8.10.0   |                                                                                         |
| rhel8_baseline_stig                     | 8.10.0   |                                                                                         |
| rhel8_baseline_stig_ansible             | 8.10.0   |                                                                                         |
| AWS CLI v2 Update Component             | x.x.x    | Update to the latest version                                                            |
| Powershell for Linux - via Yum          | x.x.x    | Update to the latest version                                                            |
| Reboot During Build Phase               | x.x.x    | Update to the latest version                                                            |
| Reboot During Test Phase                | x.x.x    | Update to the latest version                                                            |

#### EKS Worker Image Recipe

| Component Name                          | Version  | Notes                                                                                   |
|-----------------------------------------|----------|-----------------------------------------------------------------------------------------|
| RHEL8 Base Image                        | N/A      |                                                                                         |
| rhel8_baseline_components               | 8.10.0   |                                                                                         |
| rhel8_baseline_stig                     | 8.10.0   |                                                                                         |
| rhel8_baseline_stig_ansible             | 8.10.0   |                                                                                         |
| rhel8_eks_worker                        | 8.0.0    |                                                                                         |
| AWS CLI v2 Update Component             | x.x.x    | Update to the latest version                                                            |
| Powershell for Linux - via Yum          | x.x.x    | Update to the latest version                                                            |
| Reboot During Build Phase               | x.x.x    | Update to the latest version                                                            |
| Reboot During Test Phase                | x.x.x    | Update to the latest version                                                            |

### RHEL9 Build

#### Image Recipe

| Component Name                          | Version  | Notes                                                                                   |
|-----------------------------------------|----------|-----------------------------------------------------------------------------------------|
| RHEL9 Base Image                        | N/A      |                                                                                         |
| rhel9_baseline_components               | 9.0.0    |                                                                                         |
| rhel9_baseline_stig                     | 9.0.0    |                                                                                         |
| rhel9_baseline_stig_ansible             | 9.0.0    |                                                                                         |
| AWS CLI v2 Update Component             | x.x.x    | Update to the latest version                                                            |
| Powershell for Linux - via Yum          | x.x.x    | Update to the latest version                                                            |
| Reboot During Build Phase               | x.x.x    | Update to the latest version                                                            |
| Reboot During Test Phase                | x.x.x    | Update to the latest version                                                            |

#### EKS Worker Image Recipe

| Component Name                          | Version  | Notes                                                                                   |
|-----------------------------------------|----------|-----------------------------------------------------------------------------------------|
| RHEL9 Base Image                        | N/A      |                                                                                         |
| rhel9_baseline_components               | 9.0.0    |                                                                                         |
| rhel9_baseline_stig                     | 9.0.0    |                                                                                         |
| rhel9_baseline_stig_ansible             | 9.0.0    |                                                                                         |
| rhel9_eks_worker                        | 9.0.0    |                                                                                         |
| AWS CLI v2 Update Component             | x.x.x    | Update to the latest version                                                            |
| Powershell for Linux - via Yum          | x.x.x    | Update to the latest version                                                            |
| Reboot During Build Phase               | x.x.x    | Update to the latest version                                                            |
| Reboot During Test Phase                | x.x.x    | Update to the latest version                                                            |

### Additional Components (AWS Provided)

| Component Name                          | Version  | Notes                                                                                   |
|-----------------------------------------|----------|-----------------------------------------------------------------------------------------|
| AWS CLI Installer                       | 1.0.4    |                                                                                         |
| STIG High                               | 2023.2.2 |                                                                                         |
| Powershell Linux (yum)                  | 1.0.0    |                                                                                         |
| Powershell Linux 7.2.13                 | 7.2.13   |                                                                                         |
| Reboot TEST                             | 1.0.0    |                                                                                         |

Please ensure to update the version strings (`x.x.x`) in the Terraform code to match the appropriate versions and revisions as needed.
