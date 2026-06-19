## 1. First clarify: “log format” can mean two different things

There are **two layers**:

| Layer                            | Meaning                                        | Examples                                     |
| -------------------------------- | ---------------------------------------------- | -------------------------------------------- |
| **Encoding / file format**       | How the data is physically written             | JSON, XML, CSV, plain text, Syslog, Parquet  |
| **Security schema / data model** | What fields mean and how events are normalized | OCSF, CEF, LEEF, Microsoft ASIM, Elastic ECS |

So **JSON and XML are formats**, but **OCSF is not just a file format**. OCSF is a **cybersecurity event schema**. OCSF data may be stored as JSON, Parquet, or another structured representation.

---

## 2. JSON log format

**JSON is the most common modern log format** because it is structured, readable, and easy for tools to parse.

Example:

```json
{
  "timestamp": "2026-06-19T14:30:10Z",
  "event_type": "authentication",
  "user": "jdoe",
  "source_ip": "10.10.1.25",
  "action": "login",
  "result": "failed",
  "reason": "invalid_password"
}
```

### Why cybersecurity likes JSON

JSON makes it easy to search fields like:

```sql
user = "jdoe"
source_ip = "10.10.1.25"
result = "failed"
```

Instead of parsing a raw text message like:

```text
Jun 19 14:30 failed login for jdoe from 10.10.1.25
```

### AWS examples using JSON

| AWS product              | Log format                                                                                                                                                               |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **AWS CloudTrail**       | JSON. CloudTrail events use a JSON log format with records describing who made the API call, what service/action was used, and request details. ([AWS Documentation][1]) |
| **AWS WAF logs**         | Structured logs delivered to CloudWatch Logs, S3, or Firehose; WAF log examples are JSON-like structured web request records. ([AWS Documentation][2])                   |
| **AWS Lambda logs**      | Can emit system logs to CloudWatch Logs as plain text or JSON. ([AWS Documentation][3])                                                                                  |
| **AWS Network Firewall** | Alert, flow, and TLS logs contain structured event details such as timestamp, event type, packet metadata, and rule-match information. ([AWS Documentation][4])          |

### Microsoft examples using JSON

| Microsoft product                           | Log format / structure                                                                                                                                         |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Microsoft Entra ID sign-in logs**         | Exposed through Microsoft Graph APIs as structured records for user, service principal, managed identity, and non-interactive sign-ins. ([Microsoft Learn][5]) |
| **Azure Monitor Logs Ingestion API**        | Allows sending external/custom data into Log Analytics tables using REST/client libraries and custom table schemas. ([Microsoft Learn][6])                     |
| **Microsoft Defender XDR Advanced Hunting** | Data is organized into structured hunting tables such as device, identity, alert, and event tables. ([Microsoft Learn][7])                                     |

---

## 3. XML log format

**XML is older, more verbose, and still common in Windows/security tooling.**

Example:

```xml
<Event>
  <System>
    <Provider Name="Microsoft-Windows-Security-Auditing"/>
    <EventID>4625</EventID>
    <TimeCreated SystemTime="2026-06-19T14:30:10Z"/>
  </System>
  <EventData>
    <Data Name="TargetUserName">jdoe</Data>
    <Data Name="IpAddress">10.10.1.25</Data>
  </EventData>
</Event>
```

### Where XML is still common

| Product / area              | How XML is used                                                                                                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Windows Event Log**       | Windows Event Log has an event schema that defines elements and attributes used in logged events, and Windows supports XML-based event rendering/querying. ([Microsoft Learn][8]) |
| **SAML authentication**     | SAML assertions are XML-based, so identity/security logs may include XML-style authentication artifacts.                                                                          |
| **Legacy enterprise tools** | Some older SIEM, audit, identity, and middleware systems still emit or export XML.                                                                                                |

### Cybersecurity view

XML is not “bad,” but it is **heavier** than JSON and less favored for cloud-native telemetry. In modern pipelines, XML logs are often parsed and normalized into tables, JSON, ASIM, OCSF, or another analytics schema.

---

## 4. Syslog, CEF, and LEEF

These are very common in network/security devices.

### Syslog

Syslog is the traditional format for Linux, Unix, firewalls, routers, and appliances.

Example:

```text
Jun 19 14:30:10 firewall01 drop src=10.1.1.10 dst=8.8.8.8 spt=51514 dpt=53 proto=UDP
```

It is simple and widely supported, but fields are not always consistent across vendors.

### CEF — Common Event Format

CEF is a security-event format widely used by older SIEM integrations.

Example:

```text
CEF:0|Palo Alto Networks|PAN-OS|11.0|threat|Malware detected|High|src=10.1.1.10 dst=10.2.2.20 suser=jdoe
```

Microsoft Sentinel still commonly ingests **Syslog and CEF** from Linux machines, network devices, and security appliances using Azure Monitor Agent connectors. ([Microsoft Learn][9]) Sentinel maps CEF fields into the **CommonSecurityLog** table. ([Microsoft Learn][10])

### LEEF

LEEF is similar to CEF but historically associated with IBM QRadar integrations.

---

## 5. OCSF — Open Cybersecurity Schema Framework

**OCSF is the current important trend in cybersecurity logging.**

Think of OCSF as a **common language for security events**.

Instead of every vendor saying things differently:

| Vendor A    | Vendor B        | Vendor C    |
| ----------- | --------------- | ----------- |
| `src_ip`    | `sourceAddress` | `client.ip` |
| `username`  | `actor.user`    | `principal` |
| `eventName` | `activity`      | `operation` |

OCSF tries to normalize them into a common cybersecurity model.

The OCSF project describes itself as a vendor-agnostic core security schema that helps map different schemas so security teams can simplify ingestion, normalization, threat detection, and investigation. ([GitHub][11])

### OCSF example concept

A normalized authentication event may look conceptually like this:

```json
{
  "class_name": "Authentication",
  "activity_name": "Logon",
  "severity": "Medium",
  "time": 1781879410000,
  "actor": {
    "user": {
      "name": "jdoe"
    }
  },
  "src_endpoint": {
    "ip": "10.10.1.25"
  },
  "status": "Failure"
}
```

### AWS product using OCSF

The best AWS example is **Amazon Security Lake**.

Amazon Security Lake automatically collects security-related logs and events, converts supported AWS service data to **OCSF**, and stores it in Amazon S3. AWS states that Security Lake converts data into **Apache Parquet** and the OCSF schema. ([AWS Documentation][12]) Custom sources for Security Lake must use OCSF schema and Apache Parquet format. ([AWS Documentation][13])

So:

```text
Raw AWS logs → Security Lake → OCSF normalized schema → Parquet in S3 → Athena/SIEM/Splunk/Sentinel/etc.
```

That is very important for large security programs because it reduces the parsing burden.

---

## 6. Microsoft equivalent trend: ASIM, CommonSecurityLog, and Defender tables

Microsoft’s ecosystem does not rely only on OCSF. Microsoft Sentinel commonly uses:

| Microsoft model                                | Purpose                                                                                                                                 |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| **ASIM — Advanced Security Information Model** | Microsoft Sentinel normalization layer. It uses parsers to normalize different sources into common schemas. ([Microsoft Learn][14])     |
| **CommonSecurityLog**                          | Common table for CEF-based security appliance logs in Sentinel. ([Microsoft Learn][10])                                                 |
| **Defender XDR Advanced Hunting schema**       | Microsoft security events organized into hunting tables for devices, identities, alerts, cloud apps, email, etc. ([Microsoft Learn][7]) |

ASIM is Microsoft Sentinel’s way of solving the same general problem: **different vendors produce different logs, so normalize them into common schemas for detection and hunting**.

---

## 7. Does CloudWatch Logs use a specific data format?

**CloudWatch Logs does not force one application log format.**

CloudWatch Logs understands a log event mainly as:

```text
timestamp + raw message
```

AWS documentation says a CloudWatch Logs event contains the timestamp and the raw event message, and the message must be UTF-8 encoded. ([AWS Documentation][15])

So CloudWatch can store:

```text
Plain text
JSON
XML
Syslog-style text
Application logs
AWS service logs
```

### Important point

CloudWatch Logs is more like a **log storage and query service**, not a universal security schema.

For example:

| Source                     | CloudWatch receives                       |
| -------------------------- | ----------------------------------------- |
| EC2 application log        | Whatever the app writes: text, JSON, etc. |
| Lambda                     | Plain text or JSON system logs            |
| CloudTrail into CloudWatch | JSON event records                        |
| AWS WAF into CloudWatch    | Structured WAF request logs               |
| AWS Network Firewall       | Flow/alert/TLS security logs              |

CloudWatch Logs Insights can automatically discover fields in JSON logs and AWS service logs, but for non-JSON logs you usually rely on parsing. AWS also notes a limit of 200 discovered JSON fields per log event. ([AWS Documentation][16])

AWS also introduced HTTP-based ingestion support for CloudWatch Logs with formats including ND-JSON, structured JSON, and OpenTelemetry; availability can vary by region/partition, so check GovCloud support separately if that is your target. ([Amazon Web Services, Inc.][17])

---

## 8. Current industry trend in cybersecurity logging

The industry is moving in this direction:

```text
Raw text logs
   ↓
Structured JSON logs
   ↓
Normalized security schemas
   ↓
Security data lakes
   ↓
AI-assisted detection, hunting, correlation, and response
```

### Main trend

| Trend                                     | Why it helps                                            |
| ----------------------------------------- | ------------------------------------------------------- |
| **Structured JSON at source**             | Easier parsing, better search, fewer regex rules        |
| **OCSF / ASIM / ECS-style normalization** | Common field names across products                      |
| **Parquet data lake storage**             | Cheaper long-term storage and faster analytics          |
| **OpenTelemetry for app/infra telemetry** | Common observability pipeline for logs, metrics, traces |
| **Detection-as-code**                     | Repeatable SIEM detections using normalized fields      |
| **AI/SOC copilots**                       | AI works better when logs are structured and normalized |

For AWS, the trend is clearly visible in **Security Lake + OCSF + Parquet**. For Microsoft, the trend is visible in **Sentinel ASIM**, **CommonSecurityLog**, **Defender XDR Advanced Hunting**, and the Microsoft security data lake direction.

---

## 9. Practical recommendation for your AWS/Microsoft security architecture

For a cloud security program, I would think of it like this:

```text
Source systems
  - AWS CloudTrail
  - VPC Flow Logs
  - AWS WAF
  - AWS Network Firewall
  - EC2 / Linux / Windows logs
  - Microsoft Defender
  - Entra ID
  - M365 / Defender XDR

        ↓

Hot operational logging
  - CloudWatch Logs
  - Azure Monitor / Log Analytics

        ↓

Security normalization
  - AWS Security Lake → OCSF
  - Microsoft Sentinel → ASIM / CommonSecurityLog
  - Splunk CIM, if using Splunk

        ↓

Detection / alerting / hunting
  - GuardDuty
  - Security Hub
  - Sentinel Analytics
  - Defender XDR Advanced Hunting
  - Splunk correlation searches
```

### Best practice

For **new application logs**, use **structured JSON**.

For **security data lake**, normalize to **OCSF** where possible, especially in AWS Security Lake.

For **Microsoft Sentinel**, use **ASIM** and built-in Microsoft tables rather than forcing everything into raw custom logs.

For **legacy network devices**, accept **Syslog/CEF**, then normalize downstream.

---

## 10. Simple way to remember

| Format         | Simple meaning                                                  |
| -------------- | --------------------------------------------------------------- |
| **Plain text** | Human-readable, hard for machines                               |
| **Syslog**     | Traditional infrastructure/network log transport/message format |
| **JSON**       | Modern structured log format                                    |
| **XML**        | Older structured format, common in Windows/SAML/legacy systems  |
| **CEF/LEEF**   | Legacy SIEM-friendly security event formats                     |
| **OCSF**       | Modern open cybersecurity schema                                |
| **ASIM**       | Microsoft Sentinel normalization model                          |
| **Parquet**    | Efficient analytics/data-lake storage format                    |

**Bottom line:** CloudWatch Logs does not require one log format. It stores timestamp + message. But for cybersecurity, the industry is moving toward **structured JSON at ingestion** and **normalized schemas like OCSF or ASIM for detection, hunting, and data lake analytics**.

[1]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-events.html?utm_source=chatgpt.com "Understanding CloudTrail events"
[2]: https://docs.aws.amazon.com/waf/latest/developerguide/logging.html?utm_source=chatgpt.com "Logging AWS WAF protection pack (web ACL) traffic"
[3]: https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-logformat.html?utm_source=chatgpt.com "Configuring JSON and plain text log formats - AWS Lambda"
[4]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/firewall-logging-contents.html?utm_source=chatgpt.com "Contents of a AWS Network Firewall log"
[5]: https://learn.microsoft.com/en-us/graph/api/resources/azure-ad-auditlog-overview?view=graph-rest-1.0&utm_source=chatgpt.com "Microsoft Entra audit logs API overview - Microsoft Graph v1.0"
[6]: https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview?utm_source=chatgpt.com "Logs Ingestion API in Azure Monitor"
[7]: https://learn.microsoft.com/en-us/defender-xdr/advanced-hunting-schema-tables?utm_source=chatgpt.com "Understand the advanced hunting schema"
[8]: https://learn.microsoft.com/en-us/windows/win32/wes/eventschema-schema?utm_source=chatgpt.com "Event Schema - Win32 apps"
[9]: https://learn.microsoft.com/en-us/azure/sentinel/cef-syslog-ama-overview?utm_source=chatgpt.com "Syslog and CEF AMA connectors - Microsoft Sentinel"
[10]: https://learn.microsoft.com/en-us/azure/sentinel/cef-name-mapping?utm_source=chatgpt.com "CEF and CommonSecurityLog field mapping"
[11]: https://github.com/ocsf?utm_source=chatgpt.com "Open Cybersecurity Schema Framework"
[12]: https://docs.aws.amazon.com/security-lake/latest/userguide/what-is-security-lake.html?utm_source=chatgpt.com "Amazon Security Lake"
[13]: https://docs.aws.amazon.com/security-lake/latest/userguide/open-cybersecurity-schema-framework.html?utm_source=chatgpt.com "Open Cybersecurity Schema Framework (OCSF) in ..."
[14]: https://learn.microsoft.com/en-us/azure/sentinel/normalization-about-parsers?utm_source=chatgpt.com "Use Advanced Security Information Model (ASIM) parsers"
[15]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatchLogsConcepts.html?utm_source=chatgpt.com "Amazon CloudWatch Logs concepts"
[16]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_AnalyzeLogData-discoverable-fields.html?utm_source=chatgpt.com "Supported logs and discovered fields"
[17]: https://aws.amazon.com/about-aws/whats-new/2026/03/cloudwatch-http-log-collector/?utm_source=chatgpt.com "Amazon CloudWatch Logs now supports log ingestion ..."
