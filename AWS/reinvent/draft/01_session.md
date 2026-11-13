**Yes—AI-assisted troubleshooting and CloudWatch deserve a larger place in your schedule.** For your work, I would prioritize tools that can investigate routing failures, correlate security logs, explain incidents, and enforce safe access across accounts.

There are three distinct areas worth learning:

| Area | What you want to accomplish |
|---|---|
| **AI for defense** | Investigate alerts, correlate attack activity, validate vulnerabilities, and recommend responses. |
| **Defense for AI** | Secure agents against prompt injection, unauthorized tool use, excessive permissions, and data exfiltration. |
| **AI for operations** | Diagnose failures using logs, metrics, traces, configuration, code, and deployment history. |

The session details below come from reinvent_2026_all_sessions.xlsx[your exported catalog](sandbox:/workspace/scratch/970331cd1314/outputs/daily_sessions/reinvent_2026_all_sessions.xlsx). **Times are Las Vegas local time, PST; these are options to choose among, with conflicts noted.**

**My highest-priority AI troubleshooting sessions**

| Priority | Session | When / where | Why I recommend it for you |
|---|---|---|---|
| **1** | **COP317-R — Hands-on with AWS DevOps agent** · Workshop | **Monday, 3:30–5:30 PM** · Wynn/Encore | Inject failures, investigate root causes, evaluate mitigation plans, connect custom MCP tools, and approve fixes. The best practical introduction to AI-assisted operations. |
| **2** | **SEC371-R1 — Stop troubleshooting your AWS network from memory and stale diagrams** · Chalk talk | **Wednesday, 4:30–5:30 PM** · Caesars Palace | Closest match to your TGW, routing, inspection-path, and connectivity troubleshooting work. The abstract promises live-environment mapping and traffic-path analysis. |
| **3** | **SEC335-R — AI-assisted incident response: preparing for AI-assisted offensive** · Chalk talk | **Monday, 10:30–11:30 AM** · Wynn/Encore | AWS CIRT leaders demonstrate an investigation pipeline and discuss trust, feedback, and securing the investigation tools themselves. |
| **4** | **COP354-R — Diagnose Complex Workloads with AWS DevOps Agent** · Code talk | **Wednesday, 11:30 AM–12:30 PM** · MGM Grand | Follows an application symptom through infrastructure layers and correlates telemetry to identify likely causes. Useful for your intermittent connection-reset investigations. |

**Changes I would make to your earlier plan:** replace Monday’s health-check session with **SEC335-R**, and replace the late-afternoon PrivateLink session with **COP317-R**. These offer more exposure to capabilities outside your existing networking expertise.

COP317 also repeats **Wednesday, noon–2 PM, as COP317-R1**. That repeat overlaps COP354, so choose the workshop or demonstration.

**CloudWatch sessions most useful to you**

Several strong CloudWatch sessions have broader observability titles.

| Priority | Session | When / where | What you should learn |
|---|---|---|---|
| **1** | **COP339 — Logging strategy for agentic investigations** · Chalk talk | **Thursday, 1–2 PM** · Wynn/Encore | Centralized CloudWatch logging, enrichment, ingest transformations, and hot-storage decisions. **This directly matches your CloudWatch vs. S3 vs. Security Lake/Splunk questions.** |
| **2** | **COP305-R1 — Turn security logs into actionable intelligence** · Builders’ session | **Wednesday, 2:30–3:30 PM** · Wynn/Encore | Query CloudTrail, S3 access logs, and VPC flow logs for credential misuse, suspicious access, and exfiltration. |
| **3** | **COP336 — Elevate your observability with OpenTelemetry on AWS** · Breakout | **Wednesday, 2:30–3:30 PM** · Wynn/Encore | Learn the collection architecture for metrics, logs, and traces, including CloudWatch’s OpenTelemetry capabilities. **Conflicts with COP305-R1.** |
| **4** | **COP335 — Evolve your observability for the agentic era** · Breakout | **Tuesday, 11:30 AM–12:30 PM** · Wynn/Encore | Introduces CloudWatch Omni and evaluation of agent quality, accuracy, cost, and drift. |
| Optional | **COP410-R — Build a fully managed open source observability stack on AWS** · Code talk | **Friday, 8:30–9:30 AM** · Wynn/Encore | Compare an OpenTelemetry architecture using Managed Prometheus and OpenSearch. This is an alternative architecture session, not a CloudWatch-specific session. |

**Choose COP305 if you want immediate security-investigation skills; choose COP336 if you are designing the telemetry platform.** COP410 conflicts with the workforce-access session I previously recommended.

**Sessions on defending AI agents**

| Session | When / where | Why it matters |
|---|---|---|
| **SEC352-R1 — Build a security boundary for AI agents with WAF and Network Firewall** | **Tuesday, 4:30–5:30 PM** · MGM Grand | Extends your existing ingress/egress expertise to AI: caller filtering and control of destinations an agent can reach. |
| **SEC343 — From MCP poisoning to defense: securing the agent tool supply chain** | **Thursday, noon–1 PM** · Wynn/Encore | Covers malicious or altered tool definitions, tool-action restrictions, integrity checks, and runtime monitoring. |
| **SEC341 — Build layered defenses for agentic AI from prompt to tool execution** | **Thursday, 3–5 PM** · Wynn/Encore | Most comprehensive hands-on option: prompt defenses, tool authorization, rate limits, and monitoring. |
| **SEC347 — Agentic AI for Security: How AWS CIRT reduced triage time to minutes** | **Thursday, 3–3:20 PM** · Wynn/Encore | A short look at AI investigations using live AWS APIs, evaluation against expert answers, and human oversight. |

**Choose SEC341 for securing AI applications, or SEC347 for using AI in a security operations team.** They overlap. SEC341 also replaces the Thursday afternoon firewall-proxy/exfiltration sessions in your earlier plan.

For your role, the key design question is: **“Even if an agent follows a malicious instruction, what prevents it from accessing another mission owner’s data or changing production infrastructure?”**

**High-level overview of AWS AI offerings**

| Offering | Plain-English purpose | Relevance to you |
|---|---|---|
| **Amazon Bedrock** | Managed access to foundation models, with application capabilities such as retrieval from enterprise knowledge sources. | Build an assistant that answers questions using approved runbooks, architecture documents, and investigation data. |
| **Amazon Nova** | Amazon’s own foundation-model family, available through Bedrock. | A model choice within your application—not the application platform itself. |
| **Amazon SageMaker AI** | Build, train, customize, and deploy models with more control over the ML lifecycle and infrastructure. | Useful if your organization needs custom models; a lower conference priority unless you own that platform. |

AWS distinguishes Bedrock’s managed application/model access from SageMaker AI’s model-development and infrastructure control. Nova is one of the model families available through Bedrock. [AWS Decision Guides](https://docs.aws.amazon.com/decision-guides/latest/decision-guides/bedrock-or-sagemaker.html?refid=snark\&sc_icampaign=hp-aware_data-agentic-ai_2026\&sc_ichannel=ha\&utm_source=chatgpt.com)

| Offering | Plain-English purpose | Relevance to you |
|---|---|---|
| **Bedrock AgentCore** | Infrastructure for running agents, connecting tools, managing identity and memory, and observing behavior. | Where your identity, network isolation, tool permissions, and audit requirements become central. |
| **Strands Agents** | An open-source SDK for writing agents. | The development framework; AgentCore can provide the managed runtime around it. |
| **Bedrock Guardrails** | Filters and checks for prompts and responses, including sensitive information and prompt-attack detection. | One layer of defense alongside IAM, tool authorization, network controls, and validation. |

AgentCore supports multiple frameworks and models. Guardrails provide content and prompt safeguards; they should be combined with controls over what the agent can actually do. [AWS](https://aws.amazon.com/bedrock/agentcore/faqs/?utm_source=chatgpt.com)

| Offering | Plain-English purpose | Relevance to you |
|---|---|---|
| **AWS DevOps Agent** | Investigates operational problems by correlating telemetry, topology, code, and deployment information. | **Your highest-priority offering to evaluate for troubleshooting.** |
| **CloudWatch / CloudWatch Omni** | Collect, query, correlate, and explore operational telemetry; Omni adds an AI-oriented experience and agent evaluations. | Your telemetry foundation and investigation workspace. |
| **AWS Security Agent, now part of AWS Continuum** | Application-security reviews, threat modeling, code reviews, and scoped penetration testing. | Evaluate for application assurance and your development pipeline. |
| **Amazon GuardDuty** | Threat detection using AWS activity, threat intelligence, and ML. | Detect suspicious behavior; its findings can feed investigation and response workflows. |

These serve different roles: DevOps Agent investigates operational issues; CloudWatch supplies and explores telemetry; Continuum validates application security; GuardDuty detects threats. [AWS DevOps Agent](https://docs.aws.amazon.com/devopsagent/latest/userguide/about-aws-devops-agent.html?utm_source=chatgpt.com)

Other parts of the portfolio include **Kiro** for AI-assisted development, **Amazon Quick** for business research and automation, **AWS Transform** for modernization, and **Trainium/Inferentia/GPU infrastructure** for running AI workloads. For this conference, I would spend more of your time on the security and operations layers above. [AWS](https://aws.amazon.com/ai/generative-ai/services/?utm_source=chatgpt.com)

**Third-party sessions I would consider**

This ranking reflects their relevance to your work, rather than a ranking of the vendors’ products. The descriptions below are based on their sponsored-session abstracts.

| Rank | Vendor and session | When / where | What to evaluate |
|---|---|---|---|
| **1** | **Splunk/Cisco — AIM109-S: Build Trust in AI with Agent Observability** | **Tuesday, 4–5 PM** · Venetian | Since you already use Splunk, examine agent tracing, behavior evaluation, token costs, and what requires products beyond your existing deployment. |
| **2** | **CrowdStrike — SEC101-S: Stop AWS Intrusions with CrowdStrike’s Cloud SOC Agent** | **Monday, 1–2 PM** · Wynn/Encore | Correlation across identity, control-plane, and workload activity, followed by AI investigation and human-approved response. |
| **3** | **New Relic — AIM104-S: Autonomous AI Ops with AWS DevOps Agent and New Relic Autopilot** | **Tuesday, 11:30 AM–12:30 PM** · MGM Grand | A useful comparison of AWS-native investigation with a third-party observability platform. |
| **4** | **OpenAI — AIM384-S: Inside OpenAI’s Cyber Defense Factory** | **Thursday, 11:30 AM–12:30 PM** · Venetian | Continuous vulnerability discovery, validation, finding ownership, and testing proposed fixes. |
| **5** | **Cribl — AIM132-S: From Observer to Builder: AI Observability at HubSpot** | **Monday, 10–11 AM** · MGM Grand | AI usage, spend, and sensitive-data visibility. Use a booth discussion to explore your broader telemetry-routing requirements. |
| **6** | **Palo Alto Networks — SEC106-S: AI Under Fire** | **Thursday, 1–1:20 PM** · Venetian | A short vendor perspective on AI-driven attacks, firewall controls, and securing coding workflows. Relevant to your AWS-native versus vendor comparison. |

**If you attend only three vendor sessions, choose Splunk, CrowdStrike, and New Relic.** Splunk overlaps SEC352; New Relic overlaps COP335 and the start of your network-defense workshop. OpenAI overlaps SEC343, and Palo Alto overlaps COP339.

For vendor demos, bring one concrete scenario:

> “A GitLab runner intermittently fails when downloading Terraform modules through NAT and a possible proxy. Show me what your system collects, how it distinguishes a hypothesis from evidence, and what it needs permission to change.”

For your GovCloud environment, also ask each team to identify **the exact supported Region, where telemetry and prompts are processed, how mission-owner access boundaries are enforced, and whether remediation can require approval**. Treat commercial-region demonstrations as capabilities to evaluate until those details are confirmed.
