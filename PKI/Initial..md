
# **PKI (Public Key Infrastructure):**

- **Definition**: A framework that manages digital keys and certificates for secure communication.
- **Components**:
  - **Certificate Authority (CA)**: Issues and verifies digital certificates.
  - **Registration Authority (RA)**: Authenticates the identity of users before certificates are issued.
  - **Digital Certificates**: Verify the authenticity of public keys.
  - **Public and Private Keys**: Used for encryption, decryption, and digital signatures.
- **Functionality**: Enables secure data exchange by providing confidentiality, authentication, integrity, and non-repudiation.

---

## **Encryption**

- **Definition**: The process of converting plaintext into unreadable ciphertext using an algorithm and a key.
- **Types**:
  - **Symmetric Encryption**: Same key is used for both encryption and decryption (e.g., AES).
  - **Asymmetric Encryption**: Uses a pair of keys – public key (encryption) and private key (decryption) (e.g., RSA).
- **Purpose**: Ensures data confidentiality and prevents unauthorized access.

---

## **Integrity**

- **Definition**: Ensures that the data is not altered during transmission or storage.
- **How Achieved**:
  - **Hash Functions**: Generate a unique fixed-size hash value from data (e.g., SHA-256).
  - **Verification**: Comparing hash values before and after data transfer ensures integrity.
- **Importance**: Protects against data tampering.

---

## **Hash**

- **Definition**: A one-way cryptographic function that converts input data into a fixed-size string (hash value).
- **Characteristics**:
  - Deterministic: Same input always produces the same hash.
  - Irreversible: Original data cannot be derived from the hash.
  - Collision-Resistant: Hard to find two different inputs producing the same hash.
- **Uses**:
  - Ensuring data integrity.
  - Digital signatures and certificate verification.

---

### **Digital Signature**

- **Definition**: A cryptographic technique used to validate the authenticity and integrity of digital data.
- **How It Works**:
  1. **Signing**:
     - The sender generates a hash of the data.
     - The hash is encrypted using the sender’s private key to create the digital signature.
  2. **Verification**:
     - The receiver decrypts the signature using the sender’s public key.
     - Compares the decrypted hash with the hash of the received data.
- **Benefits**:
  - Ensures data integrity.
  - Provides authentication and non-repudiation.
