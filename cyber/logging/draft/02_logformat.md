

## First, resolve your core confusion: structured vs unstructured

This is the distinction that should drive your design.

**Structured** = fields are already separated and named. JSON, Parquet, Windows Event XML, CloudTrail. You can query `result=failed` without parsing.

**Unstructured / semi-structured** = a text blob with a timestamp. Raw Linux syslog, most application `stdout`, legacy appliance logs. You must parse at ingestion or query time to extract fields.

The architectural consequence: **parsing cost is the hidden tax in centralized logging.** Every unstructured source you onboard means writing and maintaining a parser. Both Splunk and Sentinel charge you (in licensing and in engineering time) for this. So your design goal is to push structure as far left (toward the source) as possible.

## Map your sources to their real formats and ingestion paths

| Source | Format reality | Cleanest path to Splunk | Cleanest path to Sentinel |
|---|---|---|---|
| **AWS CloudTrail** | Structured JSON | Splunk Add-on for AWS (SQS/S3) | AWS S3 / CloudTrail data connector |
| **VPC Flow Logs** | Semi-structured (space-delimited) or Parquet | Add-on for AWS via S3 | Via S3 connector or Security Lake |
| **AWS WAF / Network Firewall** | Structured JSON | S3 → Add-on | S3 connector |
| **RDS logs** | Mostly unstructured text (error/slow query/audit) | CloudWatch → Kinesis Firehose → Splunk HEC | CloudWatch → Event Hub → Sentinel |
| **EC2 Linux** | syslog (semi-structured), app logs vary | Universal Forwarder on host | AMA (Azure Monitor Agent) → syslog/CEF |
| **EC2 Windows** | Event Log (XML/structured) | Universal Forwarder | AMA → Windows Event tables |
| **Container logs** | JSON lines (if app emits JSON) or text | OTel Collector / Fluent Bit → HEC | OTel / Fluent Bit → Event Hub |
| **Application logs** | Whatever devs chose | HEC or forwarder | AMA / custom DCR |
| **MS Defender for Endpoint** | Structured (Defender XDR schema) | Defender Add-on / API | Native (Defender XDR connector) |
| **Entra ID** | Structured JSON (Graph) | Add-on via Graph / Event Hub | Native connector |
| **Amazon Security Lake** | OCSF in Parquet | Splunk via S3/Glue | Sentinel via S3 connector |

## The decision that actually matters: where does normalization happen?

You have three viable architectures. Pick based on whether you're Splunk-centric, Sentinel-centric, or genuinely multi-SIEM.

**Option A — SIEM-native normalization (simplest)**
Send raw/structured logs straight into the SIEM and normalize there: Splunk CIM, or Sentinel ASIM. Good when you've committed to one SIEM. Lowest upfront complexity, but you're locked in and you pay full ingestion volume into an expensive tier.

**Option B — Security data lake first, then SIEM (the current trend, and what I'd recommend for an AWS+Microsoft shop)**
Land everything in a lake normalized to **OCSF**, store as Parquet, then selectively forward to the SIEM.

```
AWS sources ──► Amazon Security Lake (OCSF/Parquet in S3)
Microsoft sources ──► Sentinel (ASIM) + export to lake
                          │
            ┌─────────────┴─────────────┐
        Splunk (federated/             Sentinel
        forwarded subset)              (analytics)
```

Why this wins for you specifically: you have *both* AWS and Microsoft. OCSF is the only vendor-neutral schema that lets CloudTrail and Defender events share field names. Security Lake does the AWS→OCSF conversion for you automatically. You keep cheap full-fidelity retention in S3/Parquet and send only detection-relevant data into Splunk/Sentinel hot tiers, controlling cost.

**Option C — Pipeline/broker in the middle (Cribl, Kinesis, Event Hub, OTel)**
A routing/transform layer between sources and destinations. Lets you parse, drop noise, reduce volume, and fan out to *both* Splunk and Sentinel from one pipeline. Often combined with B.

## A concrete reference design

```
TIER 1 — COLLECTION (push structure left)
  Linux/Windows EC2 ──► Universal Forwarder + AMA
  Containers/apps   ──► OTel Collector / Fluent Bit (emit JSON)
  AWS services      ──► native → S3 / CloudWatch
  RDS               ──► CloudWatch Logs

TIER 2 — AGGREGATION / TRANSPORT
  AWS:  CloudWatch ─► Kinesis Firehose ─┐
        S3 (service logs) ──────────────┤─► routing
  MS:   Diagnostic settings ─► Event Hub┘
  (optional broker: Cribl Stream for filter/route/reduce)

TIER 3 — NORMALIZATION + STORAGE
  Amazon Security Lake  → OCSF / Parquet / S3   (long-term, cheap)
  Sentinel Log Analytics → ASIM                  (Microsoft estate)

TIER 4 — DETECTION & ANALYTICS
  Splunk (CIM)  +  Sentinel (ASIM analytics)
  Athena / lake queries for hunting & cold retention
```

## Three principles to anchor the design

Structure at the source beats parsing downstream — mandate JSON for new app logs now, before more unstructured sources accrete. Separate your retention tiers from your detection tiers — full-fidelity cheap storage (Parquet/S3) is a different problem than hot searchable detection data (Splunk/Sentinel indexes), and conflating them is the most common cost blowout. And choose one normalization schema as your spine: OCSF if you're lake-first and multi-vendor (your case), CIM if Splunk is the center of gravity, ASIM if Sentinel is.

Want me to turn this into a formal architecture document (Word/draw.io diagram), or go deeper on one tier — for example the exact Sentinel data connectors and DCR setup, or the Splunk ingestion pipeline and CIM mapping?
