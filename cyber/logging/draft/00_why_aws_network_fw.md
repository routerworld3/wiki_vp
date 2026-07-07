
## What the repo is

The transformation library is a solution for transforming log sources into the Open Cybersecurity Schema Framework (OCSF) format for use with Amazon Security Lake — it lets you ingest, transform, and store security data from custom sources in a standardized format. The three supported custom sources are Windows Sysmon, AWS Network Firewall, and Application Load Balancer, with logs mapped to OCSF v1.1.0.

## The root cause: everything in Security Lake must be OCSF Parquet

Security Lake isn't a dumping ground for raw logs. It's an opinionated data lake with a hard contract: all log data stored with Security Lake must conform to OCSF, and it's stored as Apache Parquet for query performance. That contract is what makes cross-source Athena queries and subscriber integrations (Splunk, your SIEM, etc.) work — every source speaks the same schema.

So for *any* log to land in Security Lake, someone has to do the raw-format → OCSF → Parquet conversion. The only question is **who does it: AWS or you.**

## Native sources: AWS does the transformation for you

For a small set of high-value sources — **CloudTrail (management + S3/Lambda data events), VPC Flow Logs, Route 53 Resolver query logs, Security Hub findings, EKS audit logs, and WAF logs** — Security Lake has a built-in, service-side pipeline. When you enable these in the Security Lake console, AWS collects the logs at the *service level* (across your whole org via delegated admin), normalizes them to OCSF, converts to Parquet, and partitions them — zero code from you.

These sources got native treatment because they share two properties. First, they're the core security telemetry nearly every customer needs. Second — and this is the architectural key — they're services where AWS can hook in **at the service plane, uniformly, org-wide**. CloudTrail has an organization trail concept; VPC Flow Logs and Resolver logs have service-level delivery integrations Security Lake can subscribe to. AWS controls both ends of the pipe, so one canonical transformation works for everyone.

## Why Network Firewall and ELB don't fit that model

Network Firewall and ELB logs break both properties:

**1. No uniform service-side delivery hook.** Network Firewall logging is configured *per firewall*, and you choose the destination — S3, CloudWatch Logs, or Kinesis Firehose. ALB access logging is configured *per load balancer*, delivering to an S3 bucket you pick. There's no single, org-wide service integration point for Security Lake to attach to the way it attaches to an org CloudTrail. The logs land wherever each team pointed them.

**2. Messy, heterogeneous formats.** ALB access logs aren't even JSON — they're space-delimited text lines, gzipped, with a schema that differs from NLB and Classic LB logs. Network Firewall emits *three different log types* (alert logs, flow logs, TLS logs), each JSON but with different structures that map to different OCSF classes. Turning these into OCSF requires per-type parsing logic — which is exactly why the repo's Lambda has a `preprocessors/` folder for source-specific preprocessors and a `mappings/` folder for OCSF mapping configurations.

For sources like these, Security Lake provides the **custom source** mechanism instead: you register the source, and Security Lake automatically creates the Glue IAM role and Crawler configuration plus an S3 prefix (`ext/<source-name>/`) in the lake bucket. But the deal is: **you must deliver OCSF-conformant Parquet into that prefix yourself.** That's the gap the custom Lambda fills.

## What the Lambda actually does

The pipeline in the repo works like this: raw logs are ingested via Kinesis Data Streams or S3 buckets; the Lambda function processes them using source-specific preprocessors; it maps the log fields to OCSF schema using mapping configurations; and the transformed data is stored in the Security Lake S3 bucket in Parquet format.Here's the flow (visualizer isn't rendering right now, so in text form):

```
Network Firewall / ALB  →  logging config points to  →  S3 bucket or Kinesis Data Stream
                                                              │
                                              S3 event notification / stream trigger
                                                              ▼
                                            Transformation Lambda
                                    1. preprocessor  (parse NFW JSON types /
                                       split ALB space-delimited fields)
                                    2. mapping config (raw field → OCSF class
                                       attribute; unmapped fields → "unmapped")
                                    3. write OCSF v1.1 Parquet
                                                              ▼
                              Security Lake bucket  s3://…/ext/<custom-source>/
                                                              │
                                        Glue Crawler updates partitions/table
                                                              ▼
                                    Lake Formation grants → Athena / subscribers
```

Three details in the mapping design worth noting (they generalize to any custom source you'd build):

- **The mapping is declarative, not hardcoded.** The JSON mapping files support static values (fixed metadata like vendor name), derived values prefixed with `$.` extracted from the log data, and enum mappings that translate source values to OCSF-defined values. So adding a new source is mostly config, not code — you update the mappings folder and `sources_config.json`.
- **Non-destructive mapping.** OCSF won't have a field for everything, so attributes in the raw log that don't map directly to OCSF class attributes should go to the `unmapped` attribute rather than being dropped. You lose nothing; you just normalize what's normalizable.
- **The Glue crawler is part of the contract.** After new data lands, the crawler updates partitions — the repo's FAQ notes that failing Athena queries with a HIVE error are fixed by re-running the Glue crawler. Custom-source class routing got easier in v3, which removed the need to manually update the crawler for multi-class sources like Sysmon.

## The SCS-C03 angle

This maps directly to Skill 1.2.3 (implement log data lakes and integrate with third-party tools). The exam-relevant distinctions to keep sharp:

| Dimension | Native source | Custom source |
|---|---|---|
| Who transforms to OCSF/Parquet | Security Lake service | **You** (Lambda/Glue ETL) |
| Examples | CloudTrail, VPC Flow Logs, Route 53 Resolver, Security Hub, EKS audit, WAF | Network Firewall, ELB/ALB, Sysmon, any third-party/on-prem source |
| Enablement | Console toggle, org-wide via delegated admin | `create-custom-log-source` + Glue role + you deliver conformant Parquet to `ext/` prefix |
| S3 location | Service-managed prefixes | `ext/<source-name>/` |

Two trap patterns to watch: first, **WAF is native but Network Firewall is not** — an easy distractor since both are AWS firewall-ish services (WAF got native support later; the native list grows over time, so a question's premise may hinge on which sources require custom handling). Second, custom source creation involves the **external ID + provider identity** pattern in the `create-custom-log-source` call — that's the confused-deputy mitigation you flagged as a follow-up interest, showing up here in a logging context: the Glue role trust is scoped with an external ID so only the intended provider can assume it.

One clarification on your Lambda question specifically: the Lambda isn't required *by* Network Firewall or ELB — it's required *by Security Lake's contract*. If you didn't care about Security Lake, NFW logs in S3 are queryable with Athena directly. The Lambda exists solely to earn those logs a seat at the OCSF table so they can be queried and correlated alongside CloudTrail, VPC Flow Logs, and GuardDuty findings with one schema — and handed to subscribers in one format.
