Yes, you're exactly right — and your understanding is on point. The **SP Configuration** in Mendix's SAML module is where you define how **your Mendix app (the Service Provider)** identifies itself to the **Identity Provider (Azure Entra ID)**, and those fields like `Organization Name`, `Display Name`, and `Contact Person` are indeed part of the **SP Metadata XML** that Mendix auto-generates.

---

### 🧩 Clarifying the Configuration Flow

#### ✅ 1. **Start with SP Configuration in Mendix**
Yes — you should **start with the SP Configuration** in Mendix first. Why?

Because it:
- Defines how your app will present itself to Azure AD (your IdP)
- Generates the **SP Metadata XML** that you can give to Azure when setting up SSO

#### Fields like:
- **Organization Name**: Name of the organization operating the SP (your org)
- **Display Name**: Friendly name shown in metadata
- **Contact Person**: Useful for debugging or support (Name, email, contact type: technical/support)
- **Entity ID**: Critical – Azure uses this to trust your SP
- **ACS (Assertion Consumer Service) URL**: Where Azure posts the SAML response (usually `/SSO/assertion`)

These get baked into the **SP Metadata**, which is downloadable after you save the SP config.

---

#### ✅ 2. **Then Configure IdP (Azure Entra ID)**

Once the SP configuration is complete:
- Download the SP metadata from Mendix `/SSO/` page
- Go to **Azure Entra ID** → **Enterprise Apps** → Your SAML App → **Single sign-on**
- Use the **SP metadata** to configure Azure (especially ACS URL, Entity ID, etc.)

---

#### ✅ 3. **Import IdP Metadata into Mendix**

After Azure config is complete:
- Download the **Azure Federation Metadata XML**
- Upload it into Mendix in the **IdP Configuration** section

This auto-fills fields like:
- IdP SSO URL
- IdP Entity ID
- X.509 Signing Certificate

---

### 🧭 Quick Order of Operations

| Step | Task                                     | Purpose                                                  |
|------|------------------------------------------|----------------------------------------------------------|
| 1    | Configure SP in Mendix (`/SSO/`)         | Define how your app identifies itself                    |
| 2    | Download SP Metadata                     | Use this in Azure setup                                  |
| 3    | Configure SAML App in Azure Entra ID     | Tell Azure how to talk to your app                       |
| 4    | Download Azure IdP Metadata              | Needed for Mendix to validate SAML assertions            |
| 5    | Import IdP Metadata into Mendix          | Completes the trust setup from Mendix side               |
| 6    | Map claims and test                      | Validate login, map user attributes, enable provisioning |

---

### 📘 Reference: Mendix Docs
You're also correct that Mendix explains this in their [official documentation here](https://docs.mendix.com/appstore/modules/saml/). Specifically:

> *“All of the fields in the SP configuration tab are used when the SP Metadata is generated. This metadata can be used to set up the SAML configuration in the IdP.”*

So yes — that’s confirmation from the source that these fields like `Organization`, `Display Name`, and `Contact` are embedded in the metadata XML and are **not just cosmetic**.

---

Let me know if you want help filling in any specific field or mapping Azure claims to Mendix user attributes — I can provide example configs or microflows too!
