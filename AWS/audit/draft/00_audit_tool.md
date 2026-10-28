 The standard pattern is **AWS-native for collection, one open-source scanner for assessment, and an IAM-specific tool for permissions analysis.**

## The one tool that actually spans all three

**Steampipe + Powerpipe** (Turbot, Apache-2.0) is the closest fit to your exact list. It exposes AWS APIs as Postgres tables, so Security Hub findings, IAM policies, and SSM Inventory become SQL joins:

```sql
-- all three domains, one query layer
select * from aws_securityhub_finding where compliance_status = 'FAILED';
select * from aws_iam_policy where is_attached and is_aws_managed = false;
select * from aws_ssm_inventory where type_name = 'AWS:Application';
```

It handles org-wide via connection aggregators (one connection per account, queried as one). The `steampipe-mod-aws-compliance` mod ships CIS, NIST, PCI, HIPAA benchmarks on top. Caveat: it queries live APIs, so a full-org scan is slow and rate-limit-prone above ~50 accounts.

**CloudQuery** is the alternative if you want the data *persisted* — it ETLs AWS into Postgres/Snowflake/S3 on a schedule, which is better for a repeated audit or a dashboard. The core is open source but some of it moved behind a commercial license, so check the plugin terms for your use.

## Per-domain picks

| Domain | Open source | AWS native |
|---|---|---|
| Security Hub findings | **Prowler** (600+ checks, `--organizations-role`, writes findings *into* Security Hub via ASFF) | Delegated admin + **central configuration**; findings aggregated cross-region/account for free |
| IAM permissions | **PMapper** (graph-based privesc paths), **Cloudsplaining** (identifies resource exposure + data exfil risk in policies), **policy_sentry** | **IAM Access Analyzer** — external access + unused access findings, now surfaced directly in Security Hub |
| SSM Inventory | Steampipe `aws_ssm_inventory` | **Resource Data Sync** → central S3 → Athena/QuickSight (the canonical multi-account pattern) |
| Full asset graph | **Cartography** (Neo4j, maps relationships across IAM/EC2/S3/etc.) | **AWS Config aggregator** + advanced queries; **Resource Explorer** for quick search |

## What I'd actually do for an org audit

1. **Security Hub** delegated admin with central configuration — turns it on org-wide from one place, no per-account work.
2. **Prowler** from the management account with `--organizations-role`, output to JSON + ASFF. It's the highest signal-per-effort tool and auto-discovers accounts.
3. **IAM Access Analyzer unused-access analyzer** at the org level, then **Cloudsplaining** on the policy dump for the deep read. Add PMapper only if you care about privilege-escalation chains.
4. **SSM Resource Data Sync** to a central bucket in the audit account, Glue crawler, Athena. This is a one-time setup that keeps paying off.
5. Glue it together in **Steampipe** or dump to S3 and query everything in Athena.

One naming trap worth knowing: AWS now ships **two** Security Hub products — the original is **Security Hub CSPM**, and the newer one is just **AWS Security Hub** (sometimes called "advanced"), with different org onboarding. Make sure docs and tooling you follow match the one you've enabled.

Want me to write the setup scripts — Prowler org-scan + SSM Resource Data Sync Terraform + the Athena DDL?

**Sources:**

- [Open-source tools to analyze your AWS environment](https://www.playingaws.com/posts/aws-open-source-tools-environment/)
- [Prowler — AWS Security Audit Tool](https://prowler.com/cloud-security-solutions/aws-security-audit)
- [Powerpipe Hub — steampipe-mod-aws-compliance](https://hub.powerpipe.io/mods/turbot/steampipe-mod-terraform-aws-compliance) · [Steampipe AWS plugin mods](https://hub.steampipe.io/plugins/turbot/aws/mods)
- [Steampipe vs CloudQuery: architecture and trade-offs](https://www.cloudquery.io/blog/steampipe-vs-cloudquery)
- [AWS — Security Hub now uncovers identity risks from unused access](https://aws.amazon.com/about-aws/whats-new/2026/05/aws-security-hub-unused-access/)
- [Integrating Security Hub CSPM with AWS Organizations](https://docs.aws.amazon.com/securityhub/latest/userguide/designate-orgs-admin-account.html) · [AWS Security Hub best practices](https://aws.github.io/aws-security-services-best-practices/guides/security-hub/)
- [AWS Security Hub vs Security Hub CSPM: 2026 guide](https://primesecacademy.com/blog/aws-security-hub-vs-security-hub-cspm)
- [Creating a resource data sync for Inventory](https://docs.aws.amazon.com/systems-manager/latest/userguide/inventory-create-resource-data-sync.html) · [Automatically inventory AWS resources across multiple accounts and Regions](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/automate-aws-resource-inventory.html)
- [Cloudsplaining — AWS IAM security assessment tool](https://dev.to/aws-builders/cloudsplaining-aws-iam-security-assessment-tool-5fc7) · [PMapper](https://cloudsecurity.org/tool/pmapper)
- [Awesome IAM Policy Access Analysis](https://github.com/ishandutta2007/Awesome-IAM-Policy-Access-Analysis)
