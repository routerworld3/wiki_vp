In a modern enterprise architecture, **SailPoint**, **Radiant Logic**, and an **IdP** (Microsoft Entra or Ping) form what is often called the "Identity Trinity." They are not competitors; rather, they solve three distinct problems: **Data Messiness**, **Compliance/Governance**, and **Access Friction**.

---

## 1. The Roles: Who Does What?

To understand the integration, it helps to see them as three layers of a house:

| Component | Layer | Primary Goal |
| :--- | :--- | :--- |
| **Radiant Logic** | **The Foundation (Data)** | Cleans, correlates, and unifies "messy" identity data from HR, AD forests, and databases into one source of truth. |
| **SailPoint** | **The Walls (Governance)** | Manages the lifecycle (Joiner/Mover/Leaver) and asks: *"Should this person have this access?"* (Compliance). |
| **IdP (Entra/Ping)** | **The Front Door (Access)** | Handles the actual login, MFA, and Single Sign-On (SSO). It asks: *"Is this person who they say they are right now?"* |

---

## 2. How They Integrate Together

The most common architectural flow works in a "pipeline" from data to access:

### Step A: Radiant Logic → SailPoint (Data Feeder)
SailPoint needs to know who exists in the company. Instead of connecting SailPoint to 50 different "dirty" sources (old LDAP, 5 different Active Directory forests, SQL databases), **Radiant Logic** virtualizes them. 
*   **The Integration:** Radiant Logic presents a single, clean **LDAP or SCIM** view to SailPoint. 
*   **The Problem Solved:** **Identity Sprawl.** It eliminates the need for SailPoint to build and maintain dozens of complex connectors to legacy systems.

### Step B: SailPoint ↔ IdP (Provisioning & Sync)
Once SailPoint decides a user needs access, it must "tell" the IdP to allow it.
*   **The Integration:** SailPoint uses the **Microsoft Graph API** (for Entra) or **SCIM/APIs** (for Ping) to create accounts, assign licenses, and move users into security groups.
*   **The Problem Solved:** **Ghost Accounts.** It ensures that when an employee leaves, their access is killed in the IdP immediately and automatically.

### Step C: Radiant Logic → IdP (Authentication Support)
If your company has 10 different Active Directory forests (common after mergers), Microsoft Entra or Ping might struggle to find which "John Smith" is trying to log in.
*   **The Integration:** Radiant Logic acts as a **Single Virtual Directory (SVD)**. The IdP points to Radiant Logic as its primary "user store."
*   **The Problem Solved:** **Authentication Complexity.** The IdP only has to check one place (Radiant) to authenticate users across the entire global infrastructure.

---

## 3. The Specific Problems They Solve

By combining these three, you solve critical enterprise "pain points" that a single tool cannot handle alone:

### **Problem 1: The "Messy Middle" (Mergers & Acquisitions)**
*   **Scenario:** You just bought a company with its own AD and HR system.
*   **The Solution:** **Radiant Logic** merges the two directories instantly without a "domain migration." **SailPoint** then maps the new employees to your existing roles. **Entra/Ping** lets them log in to your apps using their old credentials via federation.

### **Problem 2: The "Over-Privileged" Employee**
*   **Scenario:** A developer moves to Marketing but keeps their production database access.
*   **The Solution:** **SailPoint** detects the "Mover" event from the HR data (provided by Radiant Logic) and automatically triggers a "revocation" command to **Entra/Ping** to remove those specific permissions.

### **Problem 3: The "Login Friction"**
*   **Scenario:** Users have to remember 5 passwords for 5 different legacy systems.
*   **The Solution:** **Radiant Logic** maps all those legacy IDs to one profile. **Ping/Entra** provides one SSO portal. **SailPoint** ensures the user only sees the apps they are legally allowed to use based on their job title.

---

## 4. Summary Table: Integration Synergy

| Integration Point | Benefit |
| :--- | :--- |
| **Radiant + SailPoint** | Faster IGA deployment; SailPoint doesn't have to deal with "dirty" data. |
| **Radiant + Ping/Entra** | Seamless SSO across fragmented directories and legacy LDAP. |
| **SailPoint + Ping/Entra** | Automated lifecycle (Joiner/Leaver) and "Closed-Loop" remediation (SailPoint finds a risk, Entra kills the session). |

> **Note** In 2026, many organizations are moving toward **Identity Threat Detection and Response (ITDR)**. In this setup, Radiant Logic observes data "drift," SailPoint analyzes the risk, and Entra/Ping enforces a "Conditional Access" block if the risk is too high.
