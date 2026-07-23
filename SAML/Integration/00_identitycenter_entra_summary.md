# AWS Identity Center to Entra Integration 

## High level

Think of it as two products doing two different jobs, connected by two different protocols.

**Microsoft Entra ID is the identity source** — it's where your users and groups actually live, and it's what verifies who someone is (password, MFA, Conditional Access). **AWS IAM Identity Center is the access broker** — it decides which AWS accounts and permissions each identity gets, across your whole AWS Organization.

They connect over two protocols that are easy to confuse but do completely separate things:

- **SCIM 2.0 = provisioning.** Entra continuously *pushes* users and groups into Identity Center so those identities exist on the AWS side. Nothing to do with login.
- **SAML 2.0 = authentication.** At sign-in time, Entra *asserts* "this is user X" to Identity Center. Nothing to do with creating users.

Then inside Identity Center, access is a three-part binding: **group + permission set + AWS account**. That binding provisions a real IAM role into the target account, and when the user logs in they assume it for temporary credentials.

## Detail

**SAML (the sign-in path).** You configure Entra's "AWS IAM Identity Center" enterprise application as the IdP and Identity Center as the SP by exchanging metadata both ways — Entra's IdP metadata (login URL + signing certificate) goes into Identity Center, and Identity Center's SP metadata (ACS URL + entity/issuer ID) goes into the Entra app. At runtime: user hits the AWS access portal → redirected to Entra → Entra enforces MFA/Conditional Access and returns a signed SAML assertion → Identity Center validates the signature and reads the subject (NameID). Crucially, Identity Center then **looks that subject up against an already-provisioned user** — SAML authenticates but does *not* create the user. That's SCIM's job.

**SCIM (the provisioning path).** In Identity Center you enable automatic provisioning, which generates a **SCIM endpoint URL + a bearer token**. You paste both into Entra's provisioning tab. Entra then becomes the SCIM client and pushes, on a schedule (~40 min), every user and group that is *assigned to that enterprise app*: creates them, updates attribute changes, syncs group memberships, and — importantly — **deactivates** them in Identity Center when they're disabled or unassigned in Entra. This is what makes offboarding automatic. Two caveats worth knowing: Entra's SCIM provisions **direct** app assignments, so dynamic-group and deeply nested-group memberships don't always flow through transitively (assign the groups directly to the app), and only groups synced via SCIM can be used in AWS assignments.

**Groups → SSO permissions → accounts.** A **permission set** is a template — managed/inline policies, session duration, optional permissions boundary. It isn't access by itself. An **assignment** binds *(principal) + (permission set) + (AWS account)*. The moment you create that assignment, Identity Center reaches into the target account (via its organization service role) and **provisions an IAM role** named `AWSReservedSSO_<permset>_<hash>` whose trust policy points back to Identity Center. Best practice is to assign **groups, never individual users**: a user in a synced Entra group like `AWS-Prod-ReadOnly` inherits the access, and membership changes in Entra flow through SCIM automatically. A common convention is to name Entra groups to encode intent — `AWS-<account/env>-<role>` — and one group can be assigned to many accounts, while a user in several groups sees the union. At login the user picks an account+role from the portal and Identity Center calls STS to hand back temporary credentials for that role — same short-lived-credential principle as the pipeline OIDC in the CI/CD docs, just for humans instead of jobs.

## The dependency chain

This is the part that determines whether it works, and the order matters:

1. **AWS Organizations must exist first** — Identity Center is an org-level service, enabled in the management account (or a delegated admin account). No Organizations, no Identity Center.
2. **Set the identity source to "External identity provider"** and complete the **mutual SAML metadata exchange**. This enables *authentication* but, on its own, produces "user not found" at login because no users exist yet on the AWS side.
3. **Enable SCIM and configure it in Entra.** This is a hard dependency for SAML to be *useful*: the SAML subject must resolve to a provisioned user. Identity Center does **not** do just-in-time provisioning with an external IdP — so without SCIM (or manual creation), every login fails to match.
4. **Attribute match is the silent dependency.** The SCIM `userName` must equal what Entra sends as the SAML NameID/subject (typically `userPrincipalName` or email). If they don't match, authentication succeeds at Entra but Identity Center can't map the user — the single most common failure.
5. **Groups must be SCIM-synced before you can assign them.** Group-based assignment depends on those groups already existing in Identity Center's store.
6. **Assignments provision the IAM roles.** Only after an assignment exists does the role appear in the account — and this depends on Identity Center's trust into member accounts (the org service-linked role).

So the causal order is: **Organizations → Identity Center → SAML trust (auth) → SCIM (identities + groups exist) → attribute match (auth resolves to a user) → assignment (group + permset + account) → IAM role provisioned → user logs in and assumes it.**

Reading failure modes backward through that chain is the fastest way to debug: SAML works but "user not found" → SCIM not syncing or attribute mismatch (steps 3–4); login works but no accounts appear → no assignment for the user's groups, or the group never synced (steps 5–6); group change not reflected → SCIM sync delay or a dynamic/nested group that didn't provision; new account added to the org shows no access → assignments aren't automatic, you must create them (ideally in IaC).

Want me to turn this into **Doc 7** in the series (same markdown + Mermaid style, with the SAML and SCIM sequence flows and a troubleshooting matrix)? It's a natural companion — human SSO alongside the pipeline's machine OIDC.
