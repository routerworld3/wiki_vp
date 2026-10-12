

**You need to convert the private key to PKCS#8 DER and hash that private-key data directly. You do not generate a public key for this comparison.**

For an **AWS-generated RSA key pair**, run:

```bash
openssl pkcs8 -in your-aws-key.pem -inform PEM -outform DER -topk8 -nocrypt | openssl sha1 -c
```

This command:

1. Reads your PEM private key.
2. Converts it to unencrypted **PKCS#8 DER** in memory.
3. Calculates its **SHA-1 fingerprint**, which should match the AWS console. No separate DER file is written. [docs.aws.amazon.com](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/verify-keys.html?utm_source=chatgpt.com)

Your earlier public-key extraction was still correct:

```bash
ssh-keygen -y -f your-aws-key.pem > public.key


Use that public key for **Cisco SSH authentication**. The OpenSSL command above is specifically for **verifying the AWS console fingerprint**.
ssh-keygen -y -f your-aws-key.pem > public.key
ssh-keygen -l -E md5 -f public.key

```
