The difference between **CAC authentication** and **Certificate-Based Authentication (CBA)** in AWS AppStream 2.0 primarily lies in **when and how** the authentication occurs.

### **1. CAC Authentication (Common Access Card)**
- Uses a physical **smart card (CAC)** for authentication.
- Typically employed by government and military users.
- **Types of CAC Authentication in AppStream 2.0:**
  - **Pre-Session CAC Authentication** (via SAML or ADFS)
    - Users authenticate **before launching the streaming session**.
    - This happens via **Identity Providers (IdPs)** like Active Directory Federation Services (ADFS).
    - No AppStream Client required; works via browser.
  - **In-Session CAC Authentication** (Requires AppStream Client)
    - Allows smart card authentication **inside the AppStream session**.
    - Used for applications that require **continuous CAC access** after login.
    - **Requires the AppStream Client** (not possible via browser).

### **2. Certificate-Based Authentication (CBA)**
- Uses **digital certificates** for authentication instead of a physical CAC.
- The client device presents an **X.509 certificate** issued by a trusted CA (Certificate Authority).
- Can be used with **SAML-based authentication** or Active Directory.
- Typically, this method does **not** require a physical CAC card.
- It can be implemented via **browser-based** access.

### **Key Differences**
| Feature | CAC Authentication | Certificate-Based Authentication (CBA) |
|---------|--------------------|--------------------------------------|
| Authentication Method | Physical **smart card (CAC)** | Digital **X.509 certificate** |
| Authentication Phase | Pre-Session and/or In-Session | Pre-Session |
| In-Session Access | Requires AppStream Client for smart card redirection | Usually not needed |
| Use Case | Military, government, CAC-dependent apps | General organizations using certificate-based access |
| Works via Browser | **Yes** (Pre-Session), **No** (In-Session) | **Yes** |

### **Which One to Use?**
- If your organization **requires continuous CAC use inside the session**, **In-Session CAC Authentication** is needed (requires the **AppStream Client**).
- If you only need **authentication at login** and do **not** require a CAC inside the session, then **Pre-Session CAC Authentication** or **Certificate-Based Authentication** via SAML/ADFS is sufficient.

Would you like help setting up either of these methods?
