
---

## **✅ How to Restrict Microsoft Graph API Permissions to a Specific Group**
### **🔹 Option 1: Use App Role Assignments with Microsoft Graph API**
1. **Register an App in Entra ID**
   - Go to **Entra ID** → **App Registrations** → **New Registration**.
   - Assign **Graph API permissions** (`Group.ReadWrite.All`).
   - Click **Grant Admin Consent**.

2. **Create a Custom Role to Restrict Access to Specific Groups**
   - Navigate to **Microsoft Entra ID** → **Roles and Administrators**.
   - Click **+ New Custom Role**.
   - Define **Granular Access**:
     - Assign **Graph API permissions** (e.g., `Group.ReadWrite`).
     - Assign only to a **specific group**.

3. **Assign the Role to the Service Principal (App)**
   - Go to **App Registrations** → Your App.
   - Under **Roles and Administrators**, assign the custom role to a specific group.

---

### **🔹 Option 2: Use Conditional Access to Restrict API Access**
1. **Go to Microsoft Entra ID** → **Security** → **Conditional Access**.
2. **Create a new policy**:
   - **Target:** Select your registered **App Registration**.
   - **Condition:** Limit access only to **specific groups**.
   - **Control:** Allow only selected API scopes (`Group.ReadWrite.All`).
3. **Enable the policy**.

---

### **🔹 Option 3: Use Graph API Query with Filters to Restrict to Specific Groups**
Even if `Group.ReadWrite.All` is granted, **you can enforce filtering at the API level**:

```http
GET https://graph.microsoft.com/v1.0/groups?$filter=id eq 'SPECIFIC-GROUP-ID'
```

This ensures that only **specific group(s)** are accessible programmatically.

---

### **🚀 Summary**
| Restriction Method | Works for Graph API? | GUI Support? | Best Use Case |
|--------------------|--------------------|--------------|--------------|
| **Application Access Policies (`New-ApplicationAccessPolicy`)** | ❌ No (Exchange Only) | ❌ No | Not applicable for Graph API |
| **App Role Assignments** | ✅ Yes | ✅ Yes | Restricting Graph API access per app |
| **Conditional Access Policies** | ✅ Yes | ✅ Yes | Enforcing security & API access control |
| **Graph API Filtering (`$filter` Queries)** | ✅ Yes | ❌ No (Only via API) | Programmatically limiting access |

---
### **🎯 Best Approach**
- If you need **organization-wide enforcement**, use **Conditional Access**.
- If you need **app-specific API access control**, use **App Role Assignments**.
- If your app can enforce its own restrictions, use **Graph API Filtering**.

Would you like help setting up a **step-by-step implementation** for any of these? 🚀
