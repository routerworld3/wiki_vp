### **Cross-Account S3 Replication with KMS Encryption - High-Level Steps and Meeting Preparation Document**

---

## **High-Level Steps**

1. **Enable Versioning** on both Source and Destination S3 buckets.  
2. **Create IAM Role** in Source Account A with the necessary permissions for replication.  
3. **Update KMS Key Policies** in both Source and Destination accounts.  
4. **Update Bucket Policy** on the Destination bucket to allow replication access.  
5. **Set Up Replication Rule** in the Source bucket to replicate data to the Destination bucket.  
6. **Test and Verify Replication** to ensure objects are successfully replicated and encrypted.  

---

## **Information Needed for the Technical Meeting**

To configure the setup, the following information must be gathered in advance:

### **From Source Account A:**
1. **S3 Source Bucket Details:**
   - Bucket Name  
   - Bucket ARN (e.g., `arn:aws:s3:::source-bucket`)  

2. **KMS Key Details (used to encrypt the Source Bucket):**
   - KMS Key ID or ARN (e.g., `arn:aws:kms:region:account-id:key/key-id`)  
   - Key Policy details (current permissions and required updates).  

3. **Account ID:**
   - AWS Account ID of Source Account A (e.g., `123456789012`)  

4. **IAM Role Information:**
   - IAM Role Name to be created for replication (e.g., `ReplicationRole`).  

5. **Data to Replicate:**
   - Specific prefixes, tags, or all objects for replication.  

---

### **From Destination Account B:**
1. **S3 Destination Bucket Details:**
   - Bucket Name  
   - Bucket ARN (e.g., `arn:aws:s3:::destination-bucket`)  

2. **KMS Key Details (to encrypt replicated data):**
   - KMS Key ID or ARN for the Destination Bucket.  
   - Key Policy details (to be updated for the Source IAM role).  

3. **Account ID:**
   - AWS Account ID of Destination Account B (e.g., `987654321098`).  

4. **Bucket Policy:**
   - Current Bucket Policy and permissions for the Destination bucket.

---

## **Step-by-Step Configuration**

### **Step 1: Enable Versioning on Both S3 Buckets**
1. **Source Bucket** (Account A):  
   - Go to **S3 Console** → Source Bucket → **Properties** → Enable Versioning.  

2. **Destination Bucket** (Account B):  
   - Go to **S3 Console** → Destination Bucket → **Properties** → Enable Versioning.  

---

### **Step 2: Create IAM Role for Replication in Source Account A**
1. Go to **IAM Console** → Create a new role.  
2. Use the following **Trust Policy**:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": { "Service": "s3.amazonaws.com" },
         "Action": "sts:AssumeRole"
       }
     ]
   }
   ```

3. Attach the following **Inline Policy**:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowSourceBucketAccess",
         "Effect": "Allow",
         "Action": ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"],
         "Resource": ["arn:aws:s3:::<SourceBucket>", "arn:aws:s3:::<SourceBucket>/*"]
       },
       {
         "Sid": "AllowDestinationBucketWrite",
         "Effect": "Allow",
         "Action": ["s3:ReplicateObject", "s3:ObjectOwnerOverrideToBucketOwner"],
         "Resource": "arn:aws:s3:::<DestinationBucket>/*"
       },
       {
         "Sid": "AllowKMSAccess",
         "Effect": "Allow",
         "Action": ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*"],
         "Resource": [
           "arn:aws:kms:<region>:<SourceAccountA-ID>:key/<SourceKMSKey-ID>",
           "arn:aws:kms:<region>:<DestinationAccountB-ID>:key/<DestinationKMSKey-ID>"
         ]
       }
     ]
   }
   ```

**Information Needed:** Replace placeholders `<SourceBucket>`, `<DestinationBucket>`, `<SourceKMSKey-ID>`, and `<DestinationKMSKey-ID>`.

---

### **Step 3: Update KMS Key Policy in Source Account A**
Add permissions for the **Replication IAM Role**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReplicationRoleToDecrypt",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::<SourceAccountA-ID>:role/ReplicationRole" },
      "Action": ["kms:Decrypt", "kms:GenerateDataKey"],
      "Resource": "*"
    }
  ]
}
```

---

### **Step 4: Update KMS Key Policy in Destination Account B**
Add permissions for the **Replication IAM Role**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReplicationRoleToEncrypt",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::<SourceAccountA-ID>:role/ReplicationRole" },
      "Action": ["kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*"],
      "Resource": "*"
    }
  ]
}
```

---

### **Step 5: Update Bucket Policy in Destination Account B**
Add a policy to allow the **ReplicationRole** to write replicated objects:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReplicationFromSourceAccountA",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::<SourceAccountA-ID>:role/ReplicationRole" },
      "Action": ["s3:ReplicateObject", "s3:ReplicateDelete"],
      "Resource": "arn:aws:s3:::<DestinationBucket>/*"
    }
  ]
}
```

---

### **Step 6: Configure Replication Rule in Source Bucket**
1. Go to **S3 Console** → Source Bucket → **Management** → **Replication Rules**.  
2. Set up the rule:
   - **Destination Bucket**: ARN of the Destination bucket.  
   - **IAM Role**: Select the ReplicationRole created earlier.  
   - Enable **Replicate Objects Encrypted with KMS**.  
3. Save the rule.

---

### **Step 7: Test and Verify**
1. Upload a test object to the **Source Bucket** in Account A.  
2. Check the **Destination Bucket** to verify:
   - Object replication.  
   - Object encryption with the Destination KMS Key.

---

## **Summary**

### **Information to Gather for Meeting:**
| **Item**                        | **Source Account A**                  | **Destination Account B**               |
|---------------------------------|--------------------------------------|----------------------------------------|
| **S3 Bucket Name & ARN**        | Required                             | Required                               |
| **AWS Account ID**              | Source Account ID                    | Destination Account ID                 |
| **KMS Key ARN/ID**              | Source Bucket KMS Key                | Destination Bucket KMS Key             |
| **IAM Role**                    | Role Name: ReplicationRole           | N/A                                    |
| **Bucket Policies**             | N/A                                  | Existing Bucket Policy                 |
| **Data for Replication**        | Prefix, Tags, or All Objects         | N/A                                    |

By following these high-level steps, the meeting will have clear technical details for smooth execution.