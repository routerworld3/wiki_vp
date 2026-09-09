I'll verify a few details before laying this out.Two different ID families get conflated here, and separating them is the first step in any credential investigation.

## Family 1: Access key IDs (what a caller presents)

Only two prefixes matter:

| Prefix | Meaning | Expires? | Has session token? |
|---|---|---|---|
| `AKIA` | Long-term key belonging to an **IAM user** (or root) | No | No |
| `ASIA` | **Temporary** credential minted by STS | Yes | Yes — always |

AKIA credentials are long-lived keys associated with IAM users; because they don't expire by default they're a favored vehicle for initial access. ASIA credentials are short-lived keys generated through STS.

Roles never have AKIA keys. If you see an AKIA in your logs, a static secret exists somewhere — in code, a CI variable, a `~/.aws/credentials` file, a Terraform state file.

Everything that produces an ASIA key: `AssumeRole`, `AssumeRoleWithSAML`, `AssumeRoleWithWebIdentity`, `GetSessionToken`, `GetFederationToken`, IMDS on EC2, ECS task role endpoint, Lambda env vars, IAM Identity Center, IAM Roles Anywhere.

## Family 2: Unique IDs (what a principal *is*)

These show up in `userIdentity.principalId` and in `aws:userid` conditions — not as credentials.

| Prefix | Resource |
|---|---|
| `AIDA` | IAM user |
| `AROA` | IAM role |
| `AIPA` | Instance profile |
| `AGPA` | User group |
| `ANPA` / `ANVA` | Managed policy / policy version |
| `APKA` | Public key |
| `ASCA` | Certificate |
| `ABIA` | STS bearer token |
| `ACCA` | Context-specific credential |

These are stable and immutable. Delete a role and recreate it with the same name and you get a new `AROA` — which is why a bare `AROAxxxx` string sitting in a resource policy means someone deleted the principal it referenced.

## Reading `userIdentity` in CloudTrail

**AKIA / IAM user:**
```json
"userIdentity": {
  "type": "IAMUser",
  "principalId": "AIDACKCEVSQ6C2EXAMPLE",
  "arn": "arn:aws:iam::111122223333:user/deploybot",
  "accessKeyId": "AKIAIOSFODNN7EXAMPLE"
}
```

**ASIA / assumed role:**
```json
"userIdentity": {
  "type": "AssumedRole",
  "principalId": "AROADBQP57FF2AEXAMPLE:i-0abc123",
  "arn": "arn:aws:sts::111122223333:assumed-role/AppRole/i-0abc123",
  "accessKeyId": "ASIAY34FZKBOKMUTVV7A",
  "sessionContext": {
    "sessionIssuer": { "type": "Role", "arn": "arn:aws:iam::111122223333:role/AppRole" },
    "attributes": { "creationDate": "...", "mfaAuthenticated": "false" }
  }
}
```

The `principalId` is `<AROA>:<session-name>`. The session name is your best free attribution signal — Identity Center puts the user's email there, EC2 puts the instance ID, and an attacker running `aws sts assume-role` will put whatever they typed.

## The pivot that matters for your investigation

**Given an ASIA key, find who minted it.** Search CloudTrail for the STS event where `responseElements.credentials.accessKeyId` equals your ASIA key. AWS's own guidance is that to learn who requested the temporary credentials behind an ASIA key, you view the STS events in CloudTrail.

```sql
-- Athena over CloudTrail
SELECT eventtime, eventname, useridentity.arn, sourceipaddress, useragent
FROM cloudtrail_logs
WHERE json_extract_scalar(responseelements,
        '$.credentials.accessKeyId') = 'ASIAY34FZKBOKMUTVV7A'
```

That single row gives you the originating principal, source IP, and MFA state. Then run it forward:

```sql
SELECT eventtime, eventsource, eventname, sourceipaddress, errorcode
FROM cloudtrail_logs
WHERE useridentity.accesskeyid = 'ASIAY34FZKBOKMUTVV7A'
ORDER BY eventtime
```

Repeat for chained roles — if the attacker assumed a second role, that new ASIA is in the `responseElements` of an `AssumeRole` call made *by* the first ASIA.

**Given a key you found in a leak,** `aws sts get-access-key-info --access-key-id <id>` returns the owning account without needing the secret. It works on both AKIA and ASIA, but it tells you nothing about state — the key may be active, inactive, or deleted. No CloudTrail entry lands in the victim account when you call it.

## Signals that a credential left its intended home

- **ASIA with a role session name matching `i-*` but `sourceIPAddress` outside AWS** → classic instance credential exfiltration. This is GuardDuty `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`. Your known false-positive pattern applies here — if egress is hairpinned through on-prem or a SASE stack, the source IP won't be the instance's EIP.
- **`ec2RoleDelivery: 1.0`** on calls made with instance-profile creds means IMDSv1 was used to fetch them — SSRF is a live path.
- **AKIA used from a new ASN, or an AKIA whose `get-access-key-last-used` region set suddenly widens** → static key leak.
- **`GetCallerIdentity` / `ListBuckets` / `DescribeInstances` burst as the first actions** on a key → attacker orienting.
- **`mfaAuthenticated: false`** in `sessionContext` on a role that should require MFA.

## Containment differs sharply between the two

**AKIA** — you own the credential object:
```bash
aws iam update-access-key --access-key-id AKIA... --status Inactive --user-name deploybot
```
Deactivate first, delete after you've finished collecting. Deactivation is instant and reversible.

**ASIA** — there is no API to revoke an individual session. Your options:

1. Attach an inline deny to the role keyed on issue time (the `AWSRevokeOlderSessions` pattern, also the console's "Revoke active sessions" button):
```json
{ "Effect": "Deny", "Action": "*", "Resource": "*",
  "Condition": { "DateLessThan": { "aws:TokenIssueTime": "2026-09-09T14:00:00Z" } } }
```
2. Fix the trust policy so the attacker can't just call `AssumeRole` again — step 1 alone does not stop re-issuance.
3. For instance profiles, disassociate the profile *and* apply the deny; disassociation alone leaves already-issued creds valid until expiry.

The `aws:TokenIssueTime` deny hits every session on that role, including legitimate ones. In a production role that's a self-inflicted outage, so scope it and communicate it.

Two traps worth internalizing for the exam and for real incidents: deleting an IAM user's AKIA key does **not** kill ASIA sessions that user already minted via `GetSessionToken` or `AssumeRole` — those run to expiry unless separately denied. And a role-level `TokenIssueTime` deny does nothing to an AKIA key.

