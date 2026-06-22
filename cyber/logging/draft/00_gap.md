
# Security Telemetry, Logging, Detection, and Response Capability Gaps

## 1. Purpose

This section identifies current capability gaps across security logging, data collection, detection engineering, SIEM/SOC analytics, and incident response. The goal is to determine whether the current architecture provides sufficient visibility, correlation, alerting, investigation, and response capability across AWS, Microsoft, endpoint, network, application, and database environments.

The assessment should not focus only on whether logs exist. It should evaluate whether the organization can reliably collect the right telemetry, normalize it, detect meaningful threats, investigate incidents, and take timely response actions.

---

## 2. Recommended Capability Domains

## 2.1 Logging and Aggregation / Log Management

### Objective

Ensure security-relevant logs are generated, centralized, protected, retained, and searchable.

### Key Points to Assess

* Are all critical systems producing security-relevant logs?
* Are logs centrally aggregated instead of remaining only on individual systems?
* Are AWS logs, Microsoft logs, endpoint logs, network logs, database logs, and application logs included?
* Are logs protected from unauthorized modification or deletion?
* Is log retention aligned with operational, compliance, forensic, and mission requirements?
* Are logs time-synchronized using trusted time sources?
* Are logs searchable during an incident without needing manual collection from each system?
* Are high-volume logs separated from high-value security logs to control cost?
* Is there a defined hot, warm, and cold retention strategy?
* Are logs archived to immutable or write-once storage where required?

### Common Gaps

* Logs exist, but are not centrally aggregated.
* Logs are stored but not searchable by the SOC.
* Retention is inconsistent across AWS, Microsoft, endpoints, and databases.
* CloudWatch, Splunk, Sentinel, and Security Lake have overlapping or unclear roles.
* Security teams do not know which logs are authoritative during an investigation.
* Critical logs are not protected against deletion or tampering.
* No documented log-source inventory exists.

### Target State

Security-relevant logs should be centrally collected, protected, searchable, retained according to policy, and routed to the correct platform based on use case: CloudWatch for AWS operational logs, Security Lake for AWS security data lake use cases, Splunk or Sentinel for SIEM correlation, and Defender XDR for Microsoft-native security investigation.

---

## 2.2 Ingestion and Collection

### Objective

Ensure required telemetry is reliably collected from all critical sources and delivered to the appropriate analytics platforms.

### Key Points to Assess

* Is there a defined list of required log sources by asset type?
* Are EC2 Linux logs collected, including syslog, auth logs, auditd, application logs, and EDR logs?
* Are EC2 Windows logs collected, including Security, System, Application, PowerShell, Sysmon, and Defender events?
* Are AWS service logs collected, including CloudTrail, VPC Flow Logs, WAF, Route 53 Resolver, GuardDuty, Inspector, Security Hub, and Network Firewall?
* Are EKS/Kubernetes logs collected, including control plane logs, audit logs, pod logs, container runtime logs, and security runtime events?
* Are RDS and database audit logs exported to CloudWatch Logs or another central platform?
* Are Microsoft Entra ID, Defender XDR, M365, and endpoint logs collected?
* Are network logs collected from firewalls, proxies, DNS, VPN, load balancers, and ingress/egress points?
* Is log ingestion monitored for failure, delay, or volume spikes?
* Is there a process for onboarding new log sources?

### Common Gaps

* Logs are enabled in AWS but not forwarded to the SOC/SIEM.
* EC2 Linux and Windows logs are collected inconsistently.
* EKS application logs are collected, but Kubernetes audit logs are not.
* Database logs are available but not integrated into detection use cases.
* Security tool findings are sent to dashboards but not correlated with raw evidence.
* No ingestion health monitoring exists.
* New applications are deployed without logging standards.

### Target State

Telemetry collection should be automated, standardized, monitored, and integrated into the SIEM/SOC workflow. Each critical asset class should have a defined collection method, required log types, destination, retention requirement, and detection use case.

---

## 2.3 Normalization, Enrichment, and Data Quality

### Objective

Ensure collected logs are usable for detection, correlation, investigation, and reporting.

### Key Points to Assess

* Are logs parsed into searchable fields?
* Are fields normalized to a common model such as Splunk CIM, Microsoft ASIM, or OCSF?
* Are logs enriched with account, workload, application, owner, environment, mission owner, VPC, subnet, asset criticality, and identity context?
* Are timestamps normalized to UTC?
* Are user, source IP, destination IP, host, process, account ID, and action fields consistently populated?
* Are duplicate logs reduced?
* Are noisy logs filtered or routed to lower-cost storage?
* Are high-value security logs prioritized for SIEM ingestion?
* Are parsing failures monitored?
* Are dashboards available to show log-source coverage and parser health?

### Common Gaps

* Logs arrive in the SIEM but are not parsed correctly.
* Different sources use different field names for the same concept.
* AWS logs, Microsoft logs, and endpoint logs cannot be easily correlated.
* Asset context is missing, making prioritization difficult.
* SOC analysts must manually interpret raw JSON, XML, or syslog messages.
* Detection rules fail because required normalized fields are missing.

### Target State

Logs should be normalized and enriched before or during SIEM ingestion. Splunk should use CIM-aligned fields, Microsoft Sentinel should use ASIM-aligned parsers where appropriate, and AWS Security Lake should use OCSF for AWS-native security data lake use cases.

---

## 2.4 Analytics and Detection

### Objective

Ensure the organization can detect meaningful threats using curated analytics, correlation rules, behavioral detections, and threat-informed detection engineering.

### Key Points to Assess

* Are detections mapped to MITRE ATT&CK techniques?
* Are AWS-native detections from GuardDuty, Inspector, Macie, IAM Access Analyzer, and Security Hub integrated into the SOC workflow?
* Are Microsoft detections from Defender XDR, Entra ID, M365, and Defender for Endpoint integrated?
* Are SIEM correlation rules defined for AWS, Microsoft, endpoint, identity, network, and database activity?
* Are detections prioritized by severity, asset criticality, and mission impact?
* Are false positives tracked and tuned?
* Are detections tested regularly?
* Are use cases documented with data sources, logic, expected output, response steps, and owner?
* Are there detections for identity abuse, privilege escalation, data exfiltration, lateral movement, command execution, malware, suspicious API activity, and unauthorized network access?
* Is there a process to identify detection gaps?

### Common Gaps

* Security tools generate findings, but there is no enterprise-level correlation.
* GuardDuty and Security Hub findings are not correlated with endpoint, identity, or network logs.
* SIEM rules are enabled but not mapped to real threats.
* Too many alerts are low-value or duplicate.
* Detection coverage is not mapped to MITRE ATT&CK.
* Detection logic is not version-controlled or tested.
* SOC cannot easily answer “what would detect this attack?”

### Target State

Detection engineering should be threat-informed, risk-prioritized, and mapped to required data sources. AWS detectors should provide high-fidelity cloud findings, while Splunk or Sentinel should provide cross-source correlation, investigation, and enterprise SOC visibility.

---

## 2.5 Response and Actionability / Incident Response

### Objective

Ensure alerts result in timely, repeatable, and measurable incident response actions.

### Key Points to Assess

* Do alerts create actionable incidents or tickets?
* Are response playbooks defined for common scenarios?
* Are response actions automated where appropriate?
* Can the SOC isolate an endpoint, disable a user, revoke credentials, block an IP, quarantine a workload, or trigger containment?
* Are AWS response actions integrated, such as disabling keys, isolating security groups, quarantining EC2 instances, blocking WAF sources, or invoking Lambda remediation?
* Are Microsoft response actions integrated, such as disabling Entra users, isolating devices in Defender, revoking sessions, or blocking indicators?
* Are incident severity levels defined?
* Are escalation paths documented?
* Are evidence collection and chain-of-custody requirements defined?
* Are post-incident lessons learned tracked?

### Common Gaps

* Alerts are generated, but response actions are manual and inconsistent.
* SOC analysts do not have clear playbooks.
* Security Hub or GuardDuty findings are reviewed but not tied to containment actions.
* Splunk and Sentinel both generate alerts, causing duplicate triage.
* Incident ownership is unclear.
* Response metrics such as MTTD and MTTR are not tracked.
* There is no feedback loop from incidents back into detection tuning.

### Target State

SOC alerts should be actionable, prioritized, and connected to response workflows. The organization should define playbooks for AWS, Microsoft, endpoint, identity, network, and application incidents, with automation used for repeatable low-risk actions and analyst approval for high-impact containment.

---

## 2.6 Governance, Metrics, and Continuous Improvement

### Objective

Ensure logging, detection, and response capabilities are governed, measured, and continuously improved.

### Key Points to Assess

* Is there a formal logging standard?
* Is there a required minimum log baseline by system type?
* Is there ownership for each log source, parser, detection rule, and response playbook?
* Are SIEM onboarding standards documented?
* Are log retention requirements documented?
* Are detection use cases reviewed periodically?
* Are gaps tracked in a remediation backlog?
* Are SOC metrics reported to leadership?
* Are tabletop exercises and purple-team tests used to validate detections?
* Are lessons learned from incidents used to improve controls?

### Common Gaps

* Logging requirements are not defined at architecture/design time.
* Teams deploy systems without security telemetry requirements.
* Detection rules are not tested after log-source changes.
* SIEM costs increase without clear value measurement.
* There is no single view of logging coverage, detection coverage, or response readiness.
* Remediation actions are tracked informally.

### Target State

Security telemetry should be treated as an architectural requirement, not an afterthought. Logging, detection, and response capabilities should have defined owners, standards, metrics, and continuous improvement processes.

---

# 3. Suggested Gap Assessment Table

| Capability Domain            | Current State | Target State | Gap | Risk / Impact | Recommendation | Priority            | Owner |
| ---------------------------- | ------------- | ------------ | --- | ------------- | -------------- | ------------------- | ----- |
| Logging and Aggregation      |               |              |     |               |                | High / Medium / Low |       |
| Ingestion and Collection     |               |              |     |               |                | High / Medium / Low |       |
| Normalization and Enrichment |               |              |     |               |                | High / Medium / Low |       |
| Analytics and Detection      |               |              |     |               |                | High / Medium / Low |       |
| Response and Actionability   |               |              |     |               |                | High / Medium / Low |       |
| Governance and Metrics       |               |              |     |               |                | High / Medium / Low |       |

---

# 4. Recommended Prioritization Criteria

Use the following criteria to prioritize remediation:

| Priority Factor           | Description                                                                            |
| ------------------------- | -------------------------------------------------------------------------------------- |
| Mission impact            | Does the gap affect critical mission systems or high-value assets?                     |
| Detection impact          | Does the gap prevent detection of likely attack techniques?                            |
| Response impact           | Does the gap delay containment or recovery?                                            |
| Compliance impact         | Does the gap affect audit, retention, forensic, or regulatory requirements?            |
| Data sensitivity          | Does the gap affect systems containing sensitive, regulated, or mission-critical data? |
| Exploit likelihood        | Is the gap related to commonly exploited attack paths?                                 |
| Implementation complexity | Can the gap be remediated quickly or does it require architecture change?              |

---

# 5. Executive Summary Statement

The current logging and detection environment should be evaluated not only by whether logs are generated, but by whether those logs are collected, normalized, correlated, retained, and actionable. AWS-native services such as Security Hub CSPM, GuardDuty, Inspector, Macie, CloudTrail, CloudWatch, and Security Lake provide strong cloud-native visibility, but they do not replace enterprise SIEM and SOC capabilities. Splunk and Microsoft Sentinel provide broader cross-platform correlation, investigation, alert management, and response workflows. The recommended target state is an integrated security telemetry architecture where AWS and Microsoft-native detections feed a centralized SOC process, with clear ownership, normalized schemas, tested detection use cases, and defined response playbooks.

## Suggested “industry-standard” mapping

| Your topic                 | Better capability name                             | Related standards / models                    |
| -------------------------- | -------------------------------------------------- | --------------------------------------------- |
| Logging and Aggregation    | Log Management, Retention, and Evidence Protection | NIST SP 800-92, NIST CSF Detect               |
| Ingestion and Collection   | Telemetry Collection and Coverage                  | NIST CSF Detect, MITRE ATT&CK data sources    |
| Analytics and Detection    | Detection Engineering and Threat Analytics         | MITRE ATT&CK, Splunk CIM, Sentinel ASIM, OCSF |
| Response and Actionability | Incident Response and SOAR                         | NIST SP 800-61, NIST CSF Respond/Recover      |
| Missing topic              | Normalization, Enrichment, and Data Quality        | OCSF, CIM, ASIM                               |
| Missing topic              | Governance, Metrics, and Continuous Improvement    | NIST CSF Govern                               |

OCSF is useful for open cybersecurity event normalization, Splunk CIM is Splunk’s semantic normalization model, and Microsoft ASIM is Sentinel’s normalization approach. ([Open Cybersecurity Schema Framework][2])

My recommendation: **keep your four original headings**, but add **Normalization/Enrichment** and **Governance/Metrics**. Those two are often where architecture gap documents become much stronger because they show that the problem is not only “are logs collected?” but “are they usable, correlated, actionable, measured, and continuously improved?”

[1]: https://nvlpubs.nist.gov/nistpubs/CSWP/NIST.CSWP.29.pdf?utm_source=chatgpt.com "The NIST Cybersecurity Framework (CSF) 2.0"
[2]: https://ocsf.io/?utm_source=chatgpt.com "Open Cybersecurity Schema Framework: Welcome to OCSF"
