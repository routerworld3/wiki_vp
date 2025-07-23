
---

#  Cross-Org Snapshot Copy Using KMS-B (Only KMS Policy Required)

##  **Objective**

* 📦 Copy **KMS-encrypted EBS snapshots** from **multiple Org-A accounts** to a **central DR Account-B**
* 🔐 Use **KMS-B in Account-B** to re-encrypt snapshots for DR
* 🎯 Avoid maintaining IAM role assumptions or explicit per-account grants
* 🔄 Further copy or rotate to **KMS-C** inside Account-B as needed

---

## 🧭 **Architecture**

```text
Org-A (Many Accounts)                    Org-B (DR Account-B)
+--------------------------+             +----------------------------+
| Account-A1               |             | DR Account-B               |
|  + EBS Vol (KMS-A1)      |             |  + KMS-B (Org-A trusted)   |
|  + Snapshot (KMS-A1)     |             |  + Copied Snapshot         |
|  + Copy → using KMS-B    |────────────►|                            |
+--------------------------+             +----------------------------+
                                          |
                                          | (optional)
                                          ▼
                                 +------------------------+
                                 | KMS-C (internal-only)  |
                                 | Copy from KMS-B        |
                                 +------------------------+
```

---

## ✅ **Key Design Highlights**

| Component         | Description                                                                                                |
| ----------------- | ---------------------------------------------------------------------------------------------------------- |
| **KMS-B**         | Created in DR Account-B. Used as **re-encryption key** for all incoming snapshots                          |
| **KMS-B policy**  | Trusts **all Org-A accounts** via `aws:PrincipalOrgID` (no per-account grants)                             |
| **Snapshot copy** | Initiated from **Org-A accounts**, **not** from Account-B                                                  |
| **KMS-A**         | No changes or trust needed — used only in the source account                                               |
| **KMS-C**         | Internal key used for re-copying snapshots inside DR Account-B for further isolation or lifecycle purposes |

---

## 🔐 KMS-B Policy (In DR Account-B)

This is the **only required configuration**:

```json
{
  "Sid": "AllowOrgAToUseKMSBForSnapshotCopy",
  "Effect": "Allow",
  "Principal": "*",
  "Action": "kms:*",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalOrgID": "o-orgaid123456",
      "kms:ViaService": "ec2.us-east-1.amazonaws.com"
    }
  }
}
```

> ✅ `kms:*` is acceptable if scoped via `aws:PrincipalOrgID` + `kms:ViaService`. You can scope it further if needed later (`kms:Encrypt`, `kms:ReEncrypt*`, `kms:DescribeKey`, etc.)

---

## 📦 Snapshot Copy Flow (from Org-A)

From any account in Org-A, run:

```bash
aws ec2 copy-snapshot \
  --source-region us-east-1 \
  --source-snapshot-id snap-aaaaaa \
  --destination-region us-east-1 \
  --encrypted \
  --kms-key-id arn:aws:kms:us-east-1:<account-b-id>:key/<kms-b-id> \
  --description "DR Copy - Re-encrypted with KMS-B"
```

> No need to touch KMS-A or define IAM trust relationships.

---

## 🔁 Recommened Re-encryption to KMS-C (Inside DR) This will Transfer the Ownership to DR Account & Encryption Key Changed from Temporary KMS-B 

After snapshot exists in Account-B, you may want to:

* Re-encrypt with **KMS-C** (tighter permissions, audit zone, etc.)
* Delete KMS-B-encrypted version

```bash
aws ec2 copy-snapshot \
  --source-region us-east-1 \
  --source-snapshot-id snap-bbbbbbb \
  --destination-region us-east-1 \
  --encrypted \
  --kms-key-id arn:aws:kms:us-east-1:<account-b-id>:key/<kms-c-id> \
  --description "Rotated to internal KMS-C"
```

---

## ✅ Final Benefits

| Advantage                             | Result                                                         |
| ------------------------------------- | -------------------------------------------------------------- |
| 🔐 **Org-level access control**       | No need to list Org-A account IDs                              |
| 💥 **No reliance on KMS-A post-copy** | Clean hand-off to DR account                                   |
| 🔄 **Re-key within DR**               | Further re-encryption with KMS-C                               |
| 🔁 **Automation-friendly**            | Can be embedded in CI/CD, AWS Backup, or EventBridge workflows |

---

## 🧰 Optional Enhancements

* 📜 Use snapshot **tagging** (`SourceAccount`, `SourceSnapshotId`, `kms:key-id`) for tracking
* 📡 Use **EventBridge rule** to detect new snapshots in Org-A and invoke copy logic automatically
* 🔒 Lock down `KMS-B` after snapshot copies are done (reduce scope to read-only)

---


