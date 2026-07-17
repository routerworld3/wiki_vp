NIST SP 800-53 Rev 5 addresses centralized logging primarily through the **Audit and Accountability (AU)** control family, with supporting requirements in **System and Information Integrity (SI)**.

While several controls touch on log generation and storage, **AU-12(1)** is the primary control that explicitly mandates centralized logging.

---

## Primary Centralized Logging Controls

### AU-12(1) | System-Wide / Centralized Logging

This is the core requirement. It requires the organization to centralize the management and analysis of audit records.

* **The Requirement:** The system must generate and consolidate audit records into a central repository (such as a SIEM, syslog collector, or centralized cloud logging bucket).
* **Architectural Intent:** This prevents "siloed" logs, makes correlation possible, and ensures that even if an individual host is compromised, its historical logs are already safely shipped off the box.

### AU-9(2) | Protection of Audit Information: Audit Backup on Separate Physical Systems / Components

* **The Requirement:** You must back up audit records to a physically or logically separate system or component from the system generating the logs.
* **Architectural Intent:** Centralized log servers or dedicated write-once storage accounts (like AWS S3 with Object Lock or Azure immutable storage) satisfy this by keeping logs out of reach from local system administrators or attackers who compromise a single workload.

---

## Supporting AU Controls That Depend on Centralization

To make a centralized logging architecture fully compliant, several other controls must be designed into the pipeline:

| Control ID | Control Name | Centralized Logging Context |
| --- | --- | --- |
| **AU-3** | Content of Audit Records | Dictates *what* must be sent to the central log repository (timestamps, source/destination IPs, user IDs, event type, success/fail status). |
| **AU-4** | Audit Log Storage Capacity | Requires planning the central repository's storage size and retention policies so it doesn't drop logs when traffic spikes. |
| **AU-5** | Response to Audit Logging Process Failures | The centralized system (or local forwarders) must alert administrators if the logging path is broken, if the central SIEM is unreachable, or if storage is full. |
| **AU-8** | Time Stamps | Requires all log-generating components to synchronize their clocks to a primary time source (like NTP). This is critical for the central repository to accurately correlate events across different systems. |
| **AU-9** | Protection of Audit Information | Requires strict Access Control Lists (ACLs) on the central log repository. Local administrators should not have modify or delete access to the centralized logs. |

---

## The Monitoring and Analysis Piece

Simply collecting logs centrally isn't enough; NIST Rev 5 requires you to actively analyze them:

* **AU-6 | Audit Record Review, Analysis, and Reporting:** Mandates that the centralized logs are regularly reviewed for target indicators of concern or unusual activity.
* **SI-4 | System Monitoring:** Often combined with centralized logging to feed automated intrusion detection systems (IDS), security analytics engines, or SOAR playbooks.

> **Architectural Tip:** When designing for Rev 5, ensure your log forwarders (like Fluentbit, Logstash, or cloud-native agents) use encrypted transport (TLS) to ship logs to the central repository to satisfy **SC-8 (Transmission Confidentiality and Integrity)**.
