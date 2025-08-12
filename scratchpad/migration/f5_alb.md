https://community.f5.com/kb/technicalarticles/ssl-orchestrator-advanced-use-cases-client-certificate-constrained-delegation-c3/286005

# What F5 “C3D” actually does

**Client Certificate Constrained Delegation (C3D)** lets an F5 (BIG-IP / SSL Orchestrator) *terminate* the client’s mTLS, then open a **new** TLS connection to the backend **presenting a freshly minted (“forged”) client certificate** that F5 generates on the fly from a CA you control. It copies key identity attributes from the real client cert (subject, issuer, serial, etc.), can enforce OCSP, and keeps end-to-end encryption even while you inspect traffic. In short: the backend still *sees* a client cert handshake, but it’s a delegated cert issued by F5’s CA, not the user’s original cert. ([F5 Cloud Docs][1])
F5’s docs explicitly describe generating a client cert on receipt of a backend “CertificateRequest”, and even allow iRule hooks to inject SAN/fields into the forged cert for the server-side handshake. ([F5 Cloud Docs][1], [techdocs.f5.com][2])

# Does AWS ALB do the same?

**No — ALB does not implement C3D.**
ALB’s mTLS feature operates at the **client→ALB** leg only, with two modes:

* **Verify mode:** ALB validates the client cert against a trust store and then forwards certificate details to the target via `X-Amzn-Mtls-*` headers. ([AWS Documentation][3])
* **Passthrough mode:** ALB accepts the TLS connection and **forwards the entire client certificate chain to targets in HTTP headers** for the application to validate. ([AWS Documentation][3], [Amazon Web Services, Inc.][4])

In both modes, ALB **does not present a client certificate to your backends** (no “client-auth” from ALB to target, no forging/minting a cert on behalf of the user). The official docs describe header propagation to targets, not downstream client-auth; there’s no configuration to supply a per-request client certificate for ALB→target TLS. ([AWS Documentation][5])

# Side-by-side (1-minute read)

| Capability                                                          | F5 C3D                                                                            | AWS ALB mTLS                                                                                                                             |
| ------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Validates client cert at the edge                                   | Yes                                                                               | Yes (verify mode) ([AWS Documentation][3])                                                                                               |
| Forwards client cert *data* to app                                  | Optional (headers or iRules)                                                      | Yes (`X-Amzn-Mtls-*` headers; whole chain in passthrough) ([AWS Documentation][5])                                                       |
| **Presents a client cert to backend (downstream mTLS client-auth)** | **Yes — F5 forges a cert from your CA and uses it to authenticate to the server** | **No — not supported; ALB does not do downstream client-auth** ([F5 Cloud Docs][1], [techdocs.f5.com][2], [AWS Documentation][5])        |
| OCSP/CRL handling at the edge                                       | Supported in F5 SSLO (incl. local OCSP options)                                   | ALB supports trust stores and CRL checks; apps can also self-validate in passthrough mode ([F5 Cloud Docs][1], [AWS re\:Invent 2025][6]) |

# What to do in your SCCA design

* If the **MO backend requires client-auth (expects a client certificate in the handshake)**, ALB alone won’t satisfy that. Options:

  1. Keep an **intermediate proxy that can do C3D-like behavior** (e.g., F5/Envoy with custom logic) between ALB and the app.
  2. **Drop the downstream client-auth requirement** and rely on **ALB mTLS (verify)** + the `X-Amzn-Mtls-*` headers (and sign/verify a context header) for app-side authorization. ([AWS Documentation][5])
* If you simply need the app to know the **client’s cert identity**, ALB already gives you detailed headers (subject, issuer, serial, validity, full leaf/chain) and you can enforce WAF rules and Conditional Access up front. ([AWS Documentation][5])


[1]: https://clouddocs.f5.com/sslo-deployment-guide/sslo-11/chapter4/page4.19.html "4.19. Implementing C3D Integration"
[2]: https://techdocs.f5.com/kb/en-us/products/ssl-orchestrator/releasenotes/product/relnote-ssl-orchestrator-16-1-3-iapp-9-3.html?utm_source=chatgpt.com "F5 SSL Orchestrator Release Notes version 16.1.3-9.3"
[3]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/mutual-authentication.html?utm_source=chatgpt.com "Mutual authentication with TLS in Application Load Balancer"
[4]: https://aws.amazon.com/blogs/networking-and-content-delivery/introducing-mtls-for-application-load-balancer/?utm_source=chatgpt.com "Introducing mTLS for Application Load Balancer"
[5]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/header-modification.html?utm_source=chatgpt.com "HTTP header modification for your Application Load Balancer"
[6]: https://reinvent.awsevents.com/content/dam/reinvent/2024/slides/net/NET310_Simplify-secure-communication-A-guide-to-mutual-TLS-on-AWS.pdf?utm_source=chatgpt.com "A guide to mutual TLS on AWS"
