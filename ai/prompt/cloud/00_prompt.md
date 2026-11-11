BLUF
Use a reusable prompt contract plus purpose-built prompts for common cloud-security architecture tasks. The prompts below default to Markdown, require cited current sources when trends are requested, distinguish facts from assumptions, and produce decision-ready architecture artifacts.

Current cloud-security architecture work should account for zero trust, secure-by-design practices, runtime-aware cloud defense, software supply-chain risk, and AI workload governance. NIST frames zero trust around protecting resources through continual evaluation of identities, devices, and access rather than relying on network location; CISA emphasizes security as a core product and engineering requirement; and NIST provides AI-risk guidance applicable across the generative-AI lifecycle.

1. Reusable Cloud Security Architecture Prompt Contract
Paste this block at the end of any of the specialized prompts below.

## Working Instructions

**Role:** Act as a senior Cloud Security Architect and security-focused enterprise architect.

**Mission context:** This work supports an unclassified enterprise cloud-security architecture decision. Use only information provided in this prompt and publicly available, unclassified sources.

**Objective:** Produce a practical, decision-ready deliverable—not generic security guidance.

**Audience:** [Select: CISO / CIO / CTO / Chief Architect / security engineering team / application team / executive steering committee / nontechnical leadership].

**Environment:** 
- Cloud provider(s): [AWS / Azure / GCP / multi-cloud / hybrid]
- Workload type: [SaaS / PaaS / IaaS / Kubernetes / serverless / data platform / AI/ML / enterprise application]
- Data sensitivity: [describe without adding markings]
- Constraints: [budget / timeline / legacy systems / staffing / compliance / tool constraints]
- Scope boundary: [in scope / out of scope]

**Required approach:**
1. Start with a 2–4 sentence BLUF.
2. Separate **facts**, **assumptions**, **risks**, **recommendations**, and **open questions**.
3. Use recognized architecture principles where relevant, including zero trust, least privilege, defense in depth, secure by design, policy-as-code, observability, resilience, and automation.
4. Do not assume a specific vendor product is required unless specified.
5. Provide at least two viable options when a decision is needed.
6. Identify tradeoffs across security, cost, operational burden, scalability, resilience, and delivery speed.
7. If current trends or external claims are included, use current primary or authoritative sources, provide publication dates, and cite each material claim.
8. Clearly label emerging practices, vendor claims, and unverified assumptions.
9. If information is insufficient, identify the minimum additional information needed rather than inventing details.

**Output format:** Markdown by default. Use clear headings, tables where useful, and Mermaid diagrams only if requested.

**Desired level of detail:** [Executive / moderate / detailed implementation-ready].

**Length target:** [e.g., 800–1,200 words, 2 pages, or briefing-ready].
2. Prompt Library
A. Architecture Pattern Selection
Use this when you need to identify the right high-level security pattern before designing a solution.

Develop a cloud-security architecture pattern recommendation for the following problem:

[Describe the business, mission, technical, and security problem.]

Evaluate at least three patterns, such as:
- Centralized security services with distributed workloads
- Federated platform engineering with centralized guardrails
- Hub-and-spoke or transit-based network segmentation
- Zero-trust, identity-centric access
- Multi-account or multi-subscription landing-zone architecture
- Shared services with delegated administration

For each pattern, provide:
1. Pattern description
2. Best-fit conditions
3. Core security controls
4. Benefits
5. Limitations and failure modes
6. Operational ownership model
7. Technology-agnostic implementation considerations
8. A simple logical architecture diagram
9. Decision criteria and scoring matrix

End with:
- Recommended pattern
- Why it is preferred
- Key assumptions
- Phased adoption roadmap for 30, 90, and 180 days
- Executive decision required

Apply the Working Instructions below.
B. Current Cloud Security Trend Scan
Use this when you need cited, current trends—not just general opinions.

Create a current cloud-security architecture trend assessment for [organization, sector, or workload type].

Research only publicly available, unclassified sources published or updated within the last [12/18/24] months.

Assess trends across:
1. Cloud identity and non-human identity security
2. Zero-trust architecture
3. Cloud-native application protection and runtime security
4. Kubernetes and container security
5. Software supply-chain security
6. Data security posture management
7. AI/GenAI platform security
8. Security automation, policy-as-code, and agentic operations
9. Cloud resilience and ransomware recovery
10. Multi-cloud and hybrid-cloud governance

For each trend, provide a table with:
- Trend
- Evidence and source date
- Maturity level: established / maturing / emerging
- Architectural impact
- Security opportunity
- Primary risk or limitation
- Recommended action for the next 12 months

Separate:
- Durable architectural practices
- Emerging practices that warrant pilots
- Vendor-driven claims that require validation

Conclude with the top five architecture implications for a Cloud Security Architecture function.

Apply the Working Instructions below.
C. Cloud Security Reference Architecture
Use this to create a target-state architecture for a platform, application estate, or cloud program.

Design a vendor-neutral cloud-security reference architecture for:

- Business or mission capability: [capability]
- Workload types: [workloads]
- Cloud environment: [provider(s)]
- Users: [employees / partners / administrators / workloads / APIs]
- Data categories: [general description]
- Primary threats or concerns: [threats]
- Constraints: [constraints]

Include the following architecture domains:
1. Identity, authentication, authorization, and privileged access
2. Network segmentation and private connectivity
3. Workload, VM, container, Kubernetes, and serverless security
4. Application and API security
5. Data protection, encryption, secrets, and key management
6. Logging, detection, incident response, and forensic readiness
7. Vulnerability management and configuration management
8. DevSecOps, CI/CD, infrastructure-as-code, and software supply chain
9. Governance, risk, compliance, and policy-as-code
10. Resilience, backup, recovery, and continuity

Deliver:
- BLUF
- Architecture principles
- Logical architecture diagram
- Control-by-domain table
- Trust boundaries and major data flows
- Shared-responsibility considerations
- Key design decisions
- Risks and compensating controls
- Implementation roadmap
- Architecture decision records required

Apply the Working Instructions below.
D. Secure Cloud Landing Zone Design
Use this for a new cloud tenant, account structure, subscription model, or foundational platform.

Create a secure cloud landing-zone design for [AWS / Azure / GCP / multi-cloud].

Context:
- Number of business units: [number]
- Expected accounts/subscriptions/projects: [number]
- Workload types: [types]
- Connectivity model: [internet-facing / private / hybrid]
- Central security services available: [services]
- Regulatory or policy drivers: [drivers]

Design the landing zone with recommendations for:
1. Organizational hierarchy and account/subscription/project structure
2. Identity federation and administrative access
3. Break-glass access
4. Network topology and segmentation
5. Centralized logging and security monitoring
6. Encryption, key management, and secrets management
7. Guardrails, policy-as-code, and preventive controls
8. Exception management and risk acceptance workflow
9. Baseline workload onboarding requirements
10. Cost, tagging, inventory, and asset ownership controls
11. Central versus delegated security responsibilities
12. Recovery, backup, and audit evidence retention

Provide:
- A logical landing-zone diagram
- A responsibility matrix
- Mandatory guardrails versus recommended guardrails
- A minimum viable landing zone and an enterprise target state
- A phased implementation plan
- Top design risks and mitigations

Apply the Working Instructions below.
E. Zero Trust Architecture for Cloud
NIST describes zero trust as resource-focused and based on continuously evaluated access decisions rather than implicit trust based on network location.

Develop a zero-trust architecture strategy for [environment or mission capability].

Current state:
[Describe identity systems, networks, cloud services, endpoints, workloads, APIs, and known gaps.]

Create a cloud-focused zero-trust design organized around:
1. Identity: workforce, privileged, workload, service, and non-human identities
2. Devices and endpoint posture
3. Applications, APIs, and service-to-service access
4. Data access and protection
5. Network and connectivity controls
6. Visibility, analytics, and continuous evaluation
7. Automation and adaptive response

For each pillar, identify:
- Desired security outcome
- Current-state gap
- Target-state capability
- Example policy decision
- Required telemetry
- Implementation dependencies
- Metrics that show improvement

Include:
- A logical policy-enforcement architecture
- Recommended sequence of implementation
- 12-month roadmap
- Risks of over-engineering or disrupting operations
- Decisions requiring executive sponsorship

Apply the Working Instructions below.
F. Identity and Non-Human Identity Architecture
Create an identity-security architecture for a cloud environment with emphasis on workforce identities, privileged identities, and non-human identities.

Environment:
[Describe cloud providers, SaaS, CI/CD systems, APIs, workloads, Kubernetes, service accounts, and automation.]

Address:
1. Identity lifecycle management
2. Federation and single sign-on
3. Multi-factor authentication and conditional access
4. Privileged access management
5. Just-in-time and just-enough access
6. Workload identities and service accounts
7. Secrets, certificates, API keys, and token management
8. Machine-to-machine authentication
9. Identity governance and access reviews
10. Detection of risky identity behavior
11. Emergency and break-glass access
12. Segregation of duties

Deliver:
- Identity architecture principles
- Target-state logical diagram
- Identity classification model
- Control matrix by identity type
- Top 10 identity risks and mitigations
- Prioritized remediation backlog
- Metrics for measuring reduction in identity risk

Apply the Working Instructions below.
G. Kubernetes and Container Security Architecture
Design a Kubernetes and container security architecture for [platform/workload].

Assume the environment includes:
- [Managed Kubernetes / self-managed Kubernetes]
- [CI/CD platform]
- [Container registry]
- [Ingress/API gateway]
- [Service mesh, if applicable]
- [Cloud provider(s)]

Address security across the full lifecycle:
1. Secure developer workstation and source-control practices
2. Dependency and software bill of materials management
3. Container image hardening and signing
4. CI/CD security gates
5. Registry controls
6. Infrastructure-as-code scanning
7. Cluster access and Kubernetes RBAC
8. Namespace and workload isolation
9. Admission control and policy-as-code
10. Secrets management
11. Network policies and service-to-service security
12. Runtime detection and response
13. Logging and auditability
14. Backup and recovery

Deliver:
- Threat model
- Reference architecture diagram
- Required controls by lifecycle stage
- Minimum security baseline
- Exceptions process
- Detection use cases
- Implementation roadmap
- Measures of effectiveness

Apply the Working Instructions below.
H. DevSecOps and Software Supply-Chain Architecture
CISA’s secure-by-design guidance emphasizes treating security as a core business and engineering requirement, rather than an optional technical add-on.

Create a DevSecOps and software supply-chain security architecture for [software delivery organization or application portfolio].

Current delivery model:
[Describe source control, CI/CD, artifact repositories, cloud environments, developer workflow, and release process.]

Design controls for:
1. Source-code protection and branch governance
2. Dependency management
3. Secrets detection and prevention
4. Software composition analysis
5. Static and dynamic application security testing
6. Infrastructure-as-code scanning
7. Build integrity and build-environment hardening
8. Artifact signing and provenance
9. Software bill of materials generation and management
10. Deployment approvals and change control
11. Runtime security feedback into development
12. Vulnerability remediation service-level objectives

Provide:
- Secure software delivery reference architecture
- Control-to-pipeline-stage matrix
- Required versus optional pipeline gates
- Developer-experience considerations
- Exception and risk-acceptance process
- Metrics for security, speed, and reliability
- 90-day implementation plan

Apply the Working Instructions below.
I. CNAPP, Runtime Security, and Detection Architecture
Develop a cloud-native security architecture that integrates posture management, identity entitlement analysis, workload protection, application security, and runtime detection.

Environment:
[Describe cloud providers, workload types, security tools, SOC model, and telemetry sources.]

Analyze:
1. Asset inventory and cloud-resource discovery
2. Misconfiguration and posture management
3. Identity entitlement management
4. Vulnerability and exposure prioritization
5. Container, serverless, and VM workload protection
6. Runtime behavior monitoring
7. Cloud threat detection
8. Application and API visibility
9. Investigation and forensic evidence preservation
10. Security orchestration and response automation

Deliver:
- Target operating model
- Logical data-flow diagram from cloud telemetry to detection and response
- Priority use cases for the SOC
- Signal-to-noise reduction strategy
- Risk-prioritization model
- Tool rationalization considerations
- 30/60/90-day implementation plan

Distinguish clearly between preventive controls, detective controls, and response capabilities.

Apply the Working Instructions below.
J. Data Security Architecture
Design a cloud data-security architecture for [data platform, application portfolio, or enterprise cloud environment].

Data types and use cases:
[Describe data at a high level, users, workflows, sharing patterns, and analytics/AI usage.]

Address:
1. Data inventory and classification approach
2. Data ownership and stewardship
3. Access control and entitlement governance
4. Encryption in transit and at rest
5. Key management and key ownership
6. Tokenization, masking, and anonymization where appropriate
7. Data-loss prevention and exfiltration controls
8. Database, object storage, file storage, and data-lake security
9. Cross-account, cross-tenant, and external sharing
10. Data access logging and monitoring
11. Backup, retention, and deletion
12. Data use in AI/ML and generative-AI workflows

Deliver:
- Data-security reference architecture
- Data lifecycle control matrix
- Trust-boundary diagram
- Top risks and mitigations
- Minimum viable controls
- Target-state controls
- Implementation priorities

Apply the Working Instructions below.
K. Secure Generative AI / AI Platform Architecture
NIST’s Generative AI Profile is designed to help organizations manage AI risk across stages of the generative-AI lifecycle in alignment with organizational risk tolerance and requirements.

Develop a secure generative-AI platform architecture for [internal assistant / retrieval-augmented generation application / model-hosting platform / AI-enabled business process].

Context:
- Intended users: [users]
- Models: [commercial API / self-hosted / open-weight / multiple]
- Data sources: [high-level description]
- Hosting: [cloud / hybrid / on-premises]
- Security constraints: [constraints]

Address:
1. User and administrator identity controls
2. Model access and authorization
3. Prompt, retrieval, and tool-use security
4. Data ingestion and connector security
5. Retrieval-augmented generation architecture
6. Data isolation and tenant separation
7. Sensitive-data minimization and output controls
8. Model and dependency supply-chain risk
9. Prompt injection and indirect prompt injection
10. Data poisoning and retrieval integrity
11. Logging, monitoring, evaluation, and red-teaming
12. Human oversight and incident response
13. Model lifecycle, versioning, and rollback
14. Third-party model and API risk

Deliver:
- Threat model
- Reference architecture diagram
- Control matrix mapped to major risks
- Security test plan
- Governance and operating model
- Go/no-go criteria for pilot deployment
- Residual risks requiring leadership decision

Apply the Working Instructions below.
L. Threat Model for a Cloud Solution
Perform a threat model for the following cloud solution:

[Paste the architecture description, workflow, components, trust boundaries, users, data flows, and integrations.]

Use a structured method based on:
- Assets
- Actors
- Trust boundaries
- Entry points
- Threat scenarios
- Likelihood
- Impact
- Existing controls
- Recommended mitigations
- Residual risk

Evaluate at minimum:
1. Identity compromise
2. Privilege escalation
3. Misconfiguration
4. API abuse
5. Data exposure or exfiltration
6. Secrets compromise
7. Supply-chain compromise
8. Lateral movement
9. Insider risk
10. Denial of service
11. Logging or monitoring gaps
12. Third-party dependency risk

Deliver:
- BLUF
- System and trust-boundary overview
- Threat table prioritized by risk
- Attack paths worthy of validation
- Mitigation backlog
- Items requiring architecture change
- Security test cases
- Assumptions and unresolved questions

Apply the Working Instructions below.
M. Security Architecture Review / Design Review
Conduct a cloud-security architecture review of the following proposed design:

[Paste design, architecture diagram description, requirements, or solution document.]

Evaluate the design against:
1. Identity and access management
2. Network security
3. Application and API security
4. Data protection
5. Encryption and key management
6. Logging, monitoring, and detection
7. Vulnerability and patch management
8. Cloud configuration and policy compliance
9. DevSecOps and supply-chain security
10. Resilience and recovery
11. Third-party integration risk
12. Operational ownership and supportability

Return the review in this structure:
- Executive assessment: approve / approve with conditions / revise and resubmit
- Strengths
- Findings by severity: critical / high / moderate / low
- Risk statement for each finding
- Evidence from the design
- Recommended remediation
- Compensating controls, if applicable
- Decision required
- Open questions
- Architecture-review checklist

Do not create findings without a stated architectural basis. Clearly distinguish missing information from an actual design weakness.

Apply the Working Instructions below.
N. Architecture Decision Record (ADR)
Draft an Architecture Decision Record for this cloud-security decision:

**Decision title:** [title]  
**Decision needed:** [decision]  
**Background:** [context]  
**Options under consideration:** [options]  
**Constraints:** [constraints]  
**Decision owner:** [role]  
**Decision deadline:** [date]  

Use this format:

# ADR: [Title]
## Status
## Decision
## Context
## Drivers
## Assumptions
## Options Considered
## Evaluation Criteria
## Decision Rationale
## Consequences
### Positive Consequences
### Negative Consequences
### Risks and Mitigations
## Implementation Considerations
## Security and Compliance Considerations
## Dependencies
## Rollback or Exit Strategy
## Open Questions
## References

Provide a concise recommendation, but preserve enough technical and risk detail for architecture governance.

Apply the Working Instructions below.
O. Executive Cloud Security Strategy Brief
Prepare an executive-ready cloud-security architecture briefing for [CISO/CIO/CTO/executive steering committee].

Topic:
[Describe the decision, risk, investment proposal, or transformation initiative.]

The audience has limited time and mixed technical depth.

Provide:
1. BLUF: no more than 150 words
2. Why this matters now
3. Current-state risk or capability gap
4. Recommended target state
5. Strategic options and tradeoffs
6. Investment and resource considerations
7. Implementation timeline
8. Key decisions requested from leadership
9. Top risks if no action is taken
10. Measures of success

Use plain language. Avoid tool-specific detail unless necessary for a decision. Include a one-page summary table and optional speaker notes.

Apply the Working Instructions below.
3. Quick Output-Format Switches
Add one of these lines to any prompt.

Output as a Markdown technical design document with headings, tables, and a Mermaid diagram.
Output as a one-page executive read-ahead with no more than 750 words.
Output as a briefing outline with slide titles and three to five bullets per slide.
Output as an architecture decision record.
Output as a risk register with columns for risk, likelihood, impact, owner, mitigation, residual risk, and due date.
Output as a control matrix with columns for domain, requirement, control objective, implementation approach, evidence, owner, and maturity.
Output as a backlog of epics, features, and security stories with priority and acceptance criteria.
4. Recommended “Accuracy and Trend” Add-On
For any trend-sensitive or vendor-evaluation prompt, add this exact block:

## Research and Validation Requirements

Use current, authoritative, publicly available sources. Prefer standards bodies, government cybersecurity agencies, cloud-provider technical documentation, peer-reviewed research, and reputable industry research.

For every material external claim:
- Provide a citation and publication date.
- Distinguish fact from analysis or recommendation.
- Identify whether the practice is established, maturing, or emerging.
- Do not treat vendor marketing as independent validation.
- If sources disagree, summarize the disagreement.
- If evidence is insufficient, say so explicitly.
This is especially useful for CNAPP, AI security, zero trust, identity security, Kubernetes runtime security, and cloud security platform evaluations.
