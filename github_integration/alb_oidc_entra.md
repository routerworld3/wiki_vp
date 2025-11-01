
---

# ALB + Microsoft Entra (OIDC) — Implementation & Troubleshooting Guide

## 1) Overview (What & Why)

**Goal:** Put an AWS **Application Load Balancer (ALB)** in front of **App-A**, enforce **OIDC** sign-in with **Microsoft Entra ID (Tenant-A)**, then pass identity to the app via headers.

**Key idea:** The **ALB is the OIDC client/RP**. It redirects the user to Entra, validates tokens, manages the session cookie, and forwards the request (with identity headers) to App-A.

---

## 2) Architecture at a Glance

**Actors:** User Browser → **ALB (authenticate-oidc)** → **Entra (Tenant-A)** → **App-A (targets)**

**Legend:**

* `302` = HTTP redirect
* ✓ = success point
* ⚠ = common failure point

---

## 3) Components

* **User**: Signed into **Tenant-A** (home tenant).
* **App-A**: Web app behind the AWS **ALB**.
* **ALB**: Has a listener rule with `authenticate-oidc` (issuer = Entra).
* **Microsoft Entra ID**: OIDC Identity Provider (IdP).

---

## 4) End-to-End Authentication Flow (Code Flow)

1. **Browser → ALB**: `GET https://app-a.example.com`
   ALB sees no session → **OIDC required**.

2. **ALB → Browser (302)** to Entra **/authorize** with:

   * `client_id=<App Registration ID>`
   * `response_type=code`
   * `scope=openid+profile+email`
   * `redirect_uri=https://app-a.example.com/oauth2/idpresponse` (**must match exactly**)
   * `state`, `nonce`

3. **Browser → Entra**: `GET /authorize`
   User authenticates (CAC/MFA/PRT/WAM). ✓

4. **Entra → Browser (302)** back to `redirect_uri` with `?code=<auth_code>&state=<opaque>`.

5. **Browser → ALB**: `GET /oauth2/idpresponse?code&state`
   ALB does **back-channel** `POST /token` with `code`, `client_id`, `client_secret`, `redirect_uri`.

6. **Entra → ALB**: `200 { id_token (+access_token optional) }`
   ALB **validates** ID token (issuer, audience, nonce, signature via JWKS). ✓

7. **ALB → Browser**: `Set-Cookie: AWSELBAuthSession` (secure, signed).

8. **ALB → App-A**: Forwards original request + **identity headers** → App responds; ALB returns 200 to browser.

---

## 5) What App-A Receives (Identity Headers)

* `x-amzn-oidc-identity`  → e.g., `sub` or UPN/email (depending on Entra token config)
* `x-amzn-oidc-data`      → Base64-encoded ID token (JWT)
* `x-amzn-oidc-accesstoken` (optional)

> If you need **groups/roles/UPN/email**, add them in **Entra → App Registration → Token configuration** so they appear in the **ID token**.

---

## 6) Minimal Known-Good ALB OIDC (Terraform Shape)

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.acm_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "authenticate-oidc"
    authenticate_oidc {
      issuer                   = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
      authorization_endpoint   = "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/authorize"
      token_endpoint           = "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token"
      user_info_endpoint       = "https://graph.microsoft.com/oidc/userinfo"
      client_id                = var.client_id
      client_secret            = var.client_secret
      scope                    = "openid profile email"
      on_unauthenticated_request = "authenticate"
      session_cookie_name      = "ALBAuthSession"
    }
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

---

## 7) Configuration Checklist (Copy/Paste)

* [ ] **Azure App Registration** type = **Web**
* [ ] **Redirect URI** = `https://app-a.example.com/oauth2/idpresponse` (**exact**; no trailing `/`)
* [ ] Use **tenant-specific v2.0** endpoints (not `/common`)
* [ ] `client_id` = **Application (client) ID**; `client_secret` valid & not expired
* [ ] `scope` includes **`openid`** (add `profile email` if needed)
* [ ] Optional claims (UPN/email/groups) added in **Token configuration**
* [ ] ALB Access Logs enabled (S3/Kinesis), CloudWatch metrics visible

---

## 8) Troubleshooting (Triage First, Then Deep-Dive)

### Phase-Based Triage

* **Phase 1 — Browser → Entra (/authorize)**
  You see the Entra login prompt → Phase 1 good.
* **Phase 2 — Entra authenticates**
  Check **Entra Sign-in logs** for your App Registration: **Status = Success** (interactive). If failure → CA/CBA/MFA/device policy issue.
* **Phase 3 — ALB code exchange / token validation / session**
  Most 500s happen here (redirect URI mismatch, wrong tenant/issuer, bad secret, JWKS, nonce/state, clock skew).

### Prove Exactly Where It Breaks (5-Minute Checks)

**A) Entra side (did auth succeed?)**

* **Entra → Sign-in logs** filtered by **Application** and **User**.

  * Success → Entra authenticated. Move to ALB checks.
  * Failure → fix CA/MFA/CBA/device/compliance.

**B) ALB side (did code exchange/validate?)**

* **ALB Access Logs** (S3/Kinesis):

  * `elb_status_code=500`, `target_status_code=-` → failed **before** App-A.
  * Look at `actions_executed` and `error_reason`:
    `OIDCRedirectURIError`, `OIDCInvalidClientSecret`, `OIDCTokenEndpointError`,
    `OIDCInvalidIssuer`, `OIDCJWKSFetchError`, `OIDCNonceMismatch`, etc.
* **CloudWatch metrics**: ALB 5XX > 0 while **Target 5XX = 0** → OIDC stage failure.
* **Browser DevTools**: `GET /oauth2/idpresponse?code=...` → 500 right there = code exchange/validation.

### Quick Isolation (No Backend Needed)

Replace the forward action with a **fixed 200** after `authenticate-oidc`.

* If still **500** → OIDC exchange/validation is broken (ALB/Entra side).
* If **200 “Auth OK”** → OIDC fine; issue is in App-A (header parsing, authz, upstream errors).

```hcl
# Probe rule: authenticate-oidc, then fixed 200 (no forward)
action { type = "authenticate-oidc" ... }
action {
  type = "fixed-response"
  fixed_response { content_type = "text/plain" status_code = "200" message_body = "Auth OK: ALB OIDC succeeded" }
}
```

---

## 9) Common Root Causes → Exact Fixes

1. **Redirect URI mismatch**
   **Fix:** In App Registration → Authentication → Web, set **exactly**
   `https://app-a.example.com/oauth2/idpresponse` (scheme/host/case match; no trailing `/`).

2. **Wrong issuer/endpoints**
   **Fix:** Use tenant-specific **v2.0** URLs:
   Issuer `https://login.microsoftonline.com/<TenantID>/v2.0`
   Auth `.../oauth2/v2.0/authorize` Token `.../oauth2/v2.0/token`.

3. **Bad/expired client secret**
   **Fix:** Rotate secret; update ALB/TF; redeploy.

4. **Conditional Access / CBA blocks token**
   **Fix:** Review **Sign-in logs** + **CA Insights**; allow the app/flow (device, location, CBA mappings).

5. **JWKS/Signature/Issuer mismatch**
   **Fix:** Ensure issuer is correct (no `/common`), and ALB can reach `login.microsoftonline.com`. Retry if transient.

6. **Nonce/State mismatch**
   **Fix:** Single clean tab/session; avoid long delays; check clock skew.

7. **Audience mismatch**
   **Fix:** ALB `client_id` must equal **Application (client) ID** (not Object ID).

8. **UserInfo endpoint oddities**
   **Fix:** Use `https://graph.microsoft.com/oidc/userinfo` or omit (ID token alone is fine for ALB).

---

## 10) After Auth Works (What to Verify in App-A)

* Log/dump the incoming identity headers once (in non-prod) to confirm expected values.
* Map claims → your authorization model (roles, groups, UPN/email).
* Ensure App-A only accepts traffic from the ALB SG/NLB, not directly.

---

## 11) Logical Flow (One-screen Summary)

1. User → ALB
2. ALB → Entra `/authorize`
3. Entra authenticates user (CAC/SSO)
4. Entra → ALB with `code`
5. ALB ↔ Entra `/token` → **ID token**
6. ALB validates token, sets **session cookie**
7. ALB → App-A with identity headers
8. App-A responds; ALB returns 200

---

## 12) OIDC Flow 

```mermaid
sequenceDiagram
    participant Browser as User Browser
    participant ALB as AWS ALB (authenticate-oidc)
    participant Entra as Microsoft Entra ID (Tenant-A)
    participant App as App-A (targets)

    Browser->>ALB: GET https://app-a.example.com
    ALB-->>Browser: 302 to Entra /oauth2/v2.0/authorize (client_id, scope, redirect_uri, state, nonce)

    Browser->>Entra: GET /oauth2/v2.0/authorize
    Entra-->>Browser: 302 redirect_uri?code&state

    Browser->>ALB: GET /oauth2/idpresponse?code&state
    ALB->>Entra: POST /oauth2/v2.0/token (code, client_id, client_secret, redirect_uri)
    Entra-->>ALB: 200 { id_token (+access_token) }

    ALB->>Entra: GET OIDC config & JWKS
    Entra-->>ALB: issuer, jwks
    ALB->>ALB: Validate id_token (issuer, aud, nonce, signature)

    ALB-->>Browser: Set-Cookie: AWSELBAuthSession
    ALB->>App: Forward + headers (x-amzn-oidc-identity, x-amzn-oidc-data)
    App-->>ALB: 200 OK
    ALB-->>Browser: 200 OK
```
## 13) Detail OIDC Flow 

 🔹 Authentication Flow

### 1. User/browser Requests the App Hosted on AWS ALB

* User opens **`https://app-a.example.com`** (fronted by ALB).
* ALB has a listener rule with `authenticate-oidc` → so before routing traffic to App-A, ALB enforces OIDC.

---

### 2. ALB Redirects to Entra ID/IDP

* ALB sees no valid session cookie → it sends an **OIDC Authorization Request** redirect:

  ```
  https://login.microsoftonline.com/<Tenant-A-ID>/oauth2/v2.0/authorize
    ?client_id=<App-Registration-ID>
    &response_type=code
    &scope=openid+profile+email
    &redirect_uri=https://app-a.example.com/oauth2/idpresponse
    &state=<opaque>
    &nonce=<random>
  ```

* Key: **redirect\_uri** points back to ALB, not the app.

---

### 3. Entra ID/IDP Authenticates the User

* User’s browser goes to Entra ID login page.
* If user is already signed in (e.g. via CAC, smartcard, or PRT/WAM), no prompt.
* Otherwise, they authenticate (CAC PIN, username/password, MFA, etc.).

---

### 4. Entra ID Issues Authorization Code

* After authentication, Entra ID redirects the browser back to ALB’s `redirect_uri`:

  ```
  https://app-a.example.com/oauth2/idpresponse?code=<auth_code>&state=<opaque>
  ```

---

### 5. ALB Exchanges Code for Tokens with Entra ID/IDP

* ALB takes the `auth_code` and makes a **back-channel HTTPS request** to Entra ID’s **Token Endpoint**:

  ```
  POST https://login.microsoftonline.com/<Tenant-A-ID>/oauth2/v2.0/token
  grant_type=authorization_code
  code=<auth_code>
  client_id=<App-Registration-ID>
  client_secret=<App-Secret>   # if confidential client
  redirect_uri=https://app-a.example.com/oauth2/idpresponse
  ```

* Entra ID returns an **ID Token (JWT)**, plus (optionally) an **access\_token** + **refresh\_token**.

---

### 6. ALB Validates Token

* ALB validates the **ID Token** signature against Entra’s OIDC JWKS endpoint.
* If valid, ALB sets a secure **session cookie** for the user.

---

### 7. Request Forwarded to App-A

* Once authenticated, ALB forwards the request to the backend target (App-A).
* ALB can inject **OIDC claims** into HTTP headers (e.g., `x-amzn-oidc-data`, `x-amzn-oidc-identity`).
* App-A can read these headers to know who the user is (e.g., UPN, email, groups if mapped).

---

### 8. Session Management

* For subsequent requests, ALB checks the session cookie.
* As long as it’s valid, traffic goes straight to App-A without forcing another OIDC redirect.


---

### TL;DR

* **ALB is the OIDC client** (not App-A).
* Most 500s occur at **code exchange / token validation**.
* Use **sign-in logs** (Entra) + **ALB access logs** + **fixed-200 probe** to isolate in minutes.
* Enforce exact **redirect URI**, correct **tenant v2.0 issuer**, valid **client secret**, and **CA/CBA** policies.
