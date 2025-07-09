Here’s a clear explanation of how **BGP route advertisements** work in an **AWS Direct Connect Gateway (DXGW) + Transit Gateway (TGW)** setup across US West and East with **redundant BGP sessions** at each location:

---

## 🔁 BGP Route Advertisements in AWS Direct Connect + TGW + DXGW Architecture

### 🧩 Key Components Recap

* **DXGW**: Global AWS construct; terminates BGP sessions from on-prem routers.
* **Transit VIF**: BGP peering point to on-prem via DXGW.
* **TGW**: Regionally scoped routing hub; attached to DXGW.
* **Customer Routers (East/West)**: Establish **two BGP sessions each** (total four) via **redundant DX connections per location**.

---

### 📥 BGP: On-Prem ➝ AWS Route Advertisement Flow

1. **Customer routers (East and West)** advertise their internal prefixes via BGP over Transit VIFs.
2. **Each Transit VIF** forms a BGP session with AWS at its DX location.
3. Prefixes advertised are received by the **Direct Connect Gateway**.
4. DXGW propagates the received routes to all **attached Transit Gateways**.
5. Each TGW receives **identical prefixes from both locations**, enabling **Active/Active** or **Active/Passive** routing depending on BGP attributes:

   * **Active/Active**:

     * Same **prefix**, **Local Pref**, **AS Path**, and **MED**.
     * AWS uses ECMP to load-balance across available BGP paths.

   * **Active/Passive**:

     * Use **AS Path prepending**, lower **Local Pref**, or higher **MED** on backup paths to make one location less preferred.

---

### 📤 BGP: AWS ➝ On-Prem Route Advertisement Flow

1. AWS TGW propagates VPC CIDRs to the DXGW.
2. DXGW advertises these prefixes via **all active BGP sessions** to the customer router.
3. If same prefixes are advertised from both TGWs:

   * Use **same AS path, local pref, MED** → **Active/Active**
   * Use **prepended AS path, different local pref** → **Active/Passive**
4. On-prem routers select best path based on:

   * **Local Preference**
   * **AS Path Length**
   * **MED** (if all else is equal)

---

### ✅ Best Practices for Your Dual Region, Redundant Setup

| Factor           | Active/Active (Load-Sharing)                   | Active/Passive (Failover)                  |
| ---------------- | ---------------------------------------------- | ------------------------------------------ |
| Prefixes         | Same on both BGP sessions                      | Same or more specific on preferred side    |
| Local Preference | Equal (default or 7224:7300)                   | Higher on preferred side (e.g., 7224:7300) |
| AS Path          | Same (no prepending)                           | Prepend on backup side                     |
| MED              | Same                                           | Higher on backup side                      |
| BGP Sessions     | 2 per location, terminate on different routers | Same                                       |
| DXGW Attachments | Attach **both TGWs (East and West)**           | Same                                       |

Ref: \[19†Active/Active and Active/Passive Configurations in AWS Direct Connect]

---

Would you like a **Mermaid diagram** or a **Terraform BGP prefix policy snippet** to show how Local Pref/AS Path is influenced across Transit VIFs?
