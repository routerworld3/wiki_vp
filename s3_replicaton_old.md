Certainly! Here is the updated **step-by-step procedure** in the correct sequence for setting up **Cross-Account S3 Replication** with KMS-encrypted buckets. I have reordered the steps to ensure that **IAM roles** and policies are created before they are referenced in later steps.

---

# **Step-by-Step Procedure for Cross-Account S3 Replication with KMS Encryption**

### **Step 1: Enable Versioning on Both S3 Buckets**

1. **Source Bucket** in Account A:  
   - Go to the **AWS S3 Console** → Source Bucket → **Properties**.
   - Enable **Versioning**.

2. **Destination Bucket** in Account B:  
   - Go to the **AWS S3 Console** → Destination Bucket → **Properties**.
   - Enable **Versioning**.

**Key Point:** Versioning is mandatory for S3 replication.

---

### **Step 2: Create IAM Role for Replication in Source Account A**

1. Go to the **IAM Console** in **Source Account A** → Create a new role.  
2. Choose **AWS Service** → **S3** as the trusted service.  
3. Set the **Trust Policy** to allow S3 to assume the role:

   **Trust Policy:**
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

4. Attach the **Inline Policy** to the role, granting permissions to:  
   - Read from the **Source Bucket**.  
   - Write to the **Destination Bucket**.  
   - Use the **KMS keys** in both accounts.

   **Replication IAM Role Policy:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowSourceBucketAccess",
         "Effect": "Allow",
         "Action": [
           "s3:GetObject",
           "s3:GetObjectVersion",
           "s3:ListBucket",
           "s3:ListBucketVersions"
         ],
         "Resource": [
           "arn:aws:s3:::<SourceBucket>",
           "arn:aws:s3:::<SourceBucket>/*"
         ]
       },
       {
         "Sid": "AllowDestinationBucketWrite",
         "Effect": "Allow",
         "Action": [
           "s3:ReplicateObject",
           "s3:ReplicateDelete",
           "s3:ObjectOwnerOverrideToBucketOwner"
         ],
         "Resource": "arn:aws:s3:::<DestinationBucket>/*"
       },
       {
         "Sid": "AllowKMSAccess",
         "Effect": "Allow",
         "Action": [
           "kms:Encrypt",
           "kms:Decrypt",
           "kms:ReEncrypt*",
           "kms:GenerateDataKey*",
           "kms:DescribeKey"
         ],
         "Resource": [
           "arn:aws:kms:<region>:<SourceAccountA-ID>:key/<SourceKMSKey-ID>",
           "arn:aws:kms:<region>:<DestinationAccountB-ID>:key/<DestinationKMSKey-ID>"
         ]
       }
     ]
   }
   ```

**Key Points:**
- Replace placeholders like `<SourceBucket>`, `<DestinationBucket>`, and `<region>`.
- This role grants necessary permissions for S3 replication and KMS encryption/decryption.

---

### **Step 3: Update KMS Key Policy in Source Account A**

1. Identify the **Source KMS Key ARN** used for encryption in the Source bucket.  
2. Update the **KMS Key Policy** to allow the **ReplicationRole** to decrypt the data.

   **KMS Key Policy:**
   ```json
   {
     "Version": "2012-10-17",
     "Id": "source-key-policy",
     "Statement": [
       {
         "Sid": "AllowReplicationRoleToDecrypt",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::<SourceAccountA-ID>:role/ReplicationRole"
         },
         "Action": [
           "kms:Decrypt",
           "kms:GenerateDataKey"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

**Key Point:** This allows the **ReplicationRole** to decrypt the Source bucket data.

---

### **Step 4: Update KMS Key Policy in Destination Account B**

1. Identify the **Destination KMS Key ARN** for encrypting replicated data.  
2. Update the **KMS Key Policy** to allow the **ReplicationRole** from Source Account A to encrypt objects.

   **KMS Key Policy:**
   ```json
   {
     "Version": "2012-10-17",
     "Id": "destination-key-policy",
     "Statement": [
       {
         "Sid": "AllowReplicationRoleToEncrypt",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::<SourceAccountA-ID>:role/ReplicationRole"
         },
         "Action": [
           "kms:Encrypt",
           "kms:ReEncrypt*",
           "kms:GenerateDataKey*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

**Key Point:** This allows the **ReplicationRole** to encrypt objects into the Destination bucket.

---

### **Step 5: Add Bucket Policy to Destination Bucket in Account B**

1. Open the **Destination Bucket** in the S3 Console.  
2. Update the **Bucket Policy** to allow the **ReplicationRole** to write objects.

   **Bucket Policy:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowReplicationFromSourceAccountA",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::<SourceAccountA-ID>:role/ReplicationRole"
         },
         "Action": [
           "s3:ReplicateObject",
           "s3:ReplicateDelete",
           "s3:ObjectOwnerOverrideToBucketOwner"
         ],
         "Resource": "arn:aws:s3:::<DestinationBucket>/*"
       }
     ]
   }
   ```

**Key Point:** This policy ensures the **ReplicationRole** can replicate objects into the Destination bucket.

---

### **Step 6: Configure Replication Rule in Source Bucket**

1. Go to **S3 Console** → Source Bucket → **Management** → **Replication Rules**.  
2. Add a new replication rule:
   - **Source Bucket**: Select the Source bucket.
   - **Destination Bucket**: Enter the **ARN** of the Destination bucket in Account B.
   - **IAM Role**: Choose the **ReplicationRole** created in Step 2.
   - Enable **Replicate Objects Encrypted with AWS KMS**.  
3. Configure optional filters (e.g., prefix or tags) as needed.  
4. Save the rule.

---

### **Step 7: Test and Verify Replication**

1. Upload a test object to the **Source Bucket** in Account A.  
2. Confirm the object appears in the **Destination Bucket** in Account B.  
3. Ensure the object in the Destination bucket is encrypted using the **Destination KMS Key**.

**Key Verification:**
- Use the AWS S3 Console to check object encryption properties.  
- Monitor the replication status and metrics for any errors.

---

## **Summary of Key Points**
1. **IAM Role:** Created first to handle permissions for both buckets and KMS keys.  
2. **KMS Policies:** Updated in both Source and Destination accounts to allow the **ReplicationRole** to decrypt/encrypt objects.  
3. **Bucket Policies:** Destination bucket allows write access for the replication role.  
4. **Replication Rule:** Configured in the Source bucket, specifying the Destination bucket and IAM Role.  
5. **Verification:** Test object replication and validate encryption on the Destination side.

This sequence ensures that all dependencies are addressed in the correct order for seamless **cross-account S3 replication**.