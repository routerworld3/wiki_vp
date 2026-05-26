Below is a **high-level AWS Bedrock RAG architecture** showing how you can use **company data** with Amazon Bedrock.


---

# 1. Simple Bedrock RAG Architecture

```mermaid
flowchart TD
    A[Company Data<br/>PDF, DOCX, TXT, MD, HTML, CSV, XLSX, Images] --> B[Data Source<br/>Amazon S3 / SharePoint / Confluence / Salesforce]

    B --> C[Amazon Bedrock Knowledge Base]

    C --> D[Parser<br/>Extract text / tables / image content]
    D --> E[Chunking<br/>Break documents into smaller sections]
    E --> F[Embedding Model<br/>Convert chunks into vectors]
    F --> G[Vector Store<br/>OpenSearch / Aurora pgvector / Neptune / Pinecone / Redis / MongoDB Atlas]

    U[User] --> H[Chat App / Web Portal / Teams Bot]
    H --> I[Amazon Bedrock Runtime]
    I --> C
    C --> J[Retrieve Relevant Chunks]
    J --> K[Foundation Model<br/>Claude / Llama / Titan / Mistral]
    K --> L[Answer with Citations]
    L --> U
```

In simple terms:

```text
Company documents go into the Knowledge Base.
Knowledge Base converts documents into searchable vectors.
User asks a question.
Bedrock retrieves the right chunks.
Foundation Model writes the answer.
```

---

# 2. Admin / Data Owner Interaction Flow

This is what the **admin or data owner** does.

```mermaid
flowchart TD
    A[Admin / Data Owner] --> B[Prepare Company Data]

    B --> C{Data Format?}

    C -->|Documents| D[PDF, DOCX, TXT, Markdown, HTML]
    C -->|Tables| E[CSV, Excel]
    C -->|Images / Diagrams| F[JPEG, PNG, PDF with diagrams]
    C -->|Enterprise Sources| G[SharePoint, Confluence, Salesforce, Web]

    D --> H[Upload to S3<br/>or connect source]
    E --> H
    F --> H
    G --> I[Configure Bedrock Connector]

    H --> J[Create Bedrock Knowledge Base]
    I --> J

    J --> K[Choose Embedding Model]
    K --> L[Choose Vector Store]
    L --> M[Configure Chunking / Parsing / Metadata]
    M --> N[Start Sync / Ingestion Job]

    N --> O[Bedrock Parses Data]
    O --> P[Bedrock Chunks Data]
    P --> Q[Bedrock Creates Embeddings]
    Q --> R[Embeddings Stored in Vector Store]

    R --> S[Knowledge Base Ready for Queries]
```

AWS describes this ingestion process as: parse the data, split documents into chunks, convert chunks into vector embeddings using an embedding model, and write those embeddings into a vector index in the selected vector store. ([AWS Documentation][2])

---

# 3. End User Interaction Flow

This is what happens when a normal user asks a question.

```mermaid
sequenceDiagram
    participant User
    participant App as Chat App / Portal
    participant Auth as AuthN/AuthZ<br/>Cognito / Entra ID / IAM Identity Center
    participant KB as Bedrock Knowledge Base
    participant VS as Vector Store
    participant FM as Foundation Model

    User->>App: Ask question
    App->>Auth: Verify user identity and access
    Auth-->>App: User allowed

    App->>KB: Send user question
    KB->>KB: Convert question to embedding
    KB->>VS: Search similar vectors
    VS-->>KB: Return relevant document chunks

    KB->>FM: Send prompt + retrieved context
    FM-->>KB: Generate grounded answer
    KB-->>App: Answer + citations
    App-->>User: Display final response
```

The important part is that the model is answering from **retrieved company context**, not just from general internet-trained knowledge. AWS describes RAG in Bedrock Knowledge Bases as a way to use retrieved information from data sources to generate more accurate responses and include citations to original sources. ([AWS Documentation][3])

---

# 4. Data Format View

This diagram shows what kind of company data can go into the system.

```mermaid
flowchart LR
    A[Company Data] --> B[Unstructured Data]
    A --> C[Structured Data]

    B --> B1[TXT / Markdown / HTML]
    B --> B2[PDF / Word Documents]
    B --> B3[Images / Diagrams / Charts]
    B --> B4[Confluence / SharePoint / Salesforce / Web]

    C --> C1[CSV / Excel]
    C --> C2[Amazon Redshift]
    C --> C3[AWS Glue Data Catalog<br/>Lake Formation]

    B1 --> D[Bedrock Knowledge Base]
    B2 --> D
    B3 --> D
    B4 --> D

    C1 --> D
    C2 --> E[Structured Query Path<br/>Natural Language to SQL]
    C3 --> E

    D --> F[Vector Embeddings + Retrieval]
    E --> G[SQL Query + Table Result]
```

For unstructured data, Bedrock Knowledge Bases converts the raw data into embeddings and stores them in a vector store. For structured data, AWS documentation says Bedrock Knowledge Bases can connect through a query engine, convert natural language into SQL, and retrieve relevant table data. ([AWS Documentation][2])

---

# 5. Recommended Company Data Format

For best results, I would organize company data like this:

```text
Best:
- Markdown .md
- TXT
- DOCX
- PDF with selectable text
- HTML documentation
- CSV / Excel for tabular reference data

Good but needs care:
- PDF with diagrams
- PNG/JPEG architecture diagrams
- PowerPoint exported to PDF
- Scanned PDFs

Avoid as primary source:
- Screenshot-only documents
- Unlabeled diagrams
- Large PDFs with no headings
- Random file dumps with no metadata
```

Best practical format for architecture documents:

```text
Architecture.md
  - Executive summary
  - Component table
  - ASCII flow
  - Mermaid diagram
  - Traffic flow steps
  - Security assumptions
  - Known limitations
```

Example:

````markdown
# SCCA Egress Architecture

## Summary
Mission Owner VPCs send outbound traffic through TGW to the Inspection VPC before reaching the Egress VPC.

## Flow

```text
Mission Owner VPC
  -> TGW Pre-Inspection Route Table
  -> Inspection VPC
  -> AWS Network Firewall
  -> TGW Post-Inspection Route Table
  -> Egress VPC
```

## Mermaid

```mermaid
flowchart LR
    MO[Mission Owner VPC] --> TGW1[TGW Pre-Inspection RT]
    TGW1 --> INS[Inspection VPC]
    INS --> ANFW[AWS Network Firewall]
    ANFW --> TGW2[TGW Post-Inspection RT]
    TGW2 --> EGRESS[Egress VPC]
```

## Component Table

| Component | Purpose |
|---|---|
| Mission Owner VPC | Application workloads |
| TGW Pre-Inspection RT | Sends traffic to inspection |
| AWS Network Firewall | Stateful inspection |
| Egress VPC | Central outbound path |
````

This is better than only uploading a diagram image because the RAG system can retrieve exact words like **TGW Pre-Inspection Route Table**, **Inspection VPC**, and **AWS Network Firewall**.

---

# 6. Admin vs User High-Level Architecture

```mermaid
flowchart TB
    subgraph AdminSide[Admin / Data Engineering Side]
        A1[Admin uploads or connects data]
        A2[S3 / SharePoint / Confluence / Salesforce]
        A3[Bedrock Knowledge Base Sync]
        A4[Parse + Chunk + Embed]
        A5[Vector Store]
        A1 --> A2 --> A3 --> A4 --> A5
    end

    subgraph UserSide[User Query Side]
        U1[User asks question]
        U2[Chat App / Portal]
        U3[AuthZ Filter<br/>Who can see what?]
        U4[Retrieve relevant chunks]
        U5[Foundation Model]
        U6[Answer with source citations]
        U1 --> U2 --> U3 --> U4 --> U5 --> U6
    end

    A5 --> U4
```

The **admin side** keeps the knowledge base current.
The **user side** retrieves relevant content and generates answers.

AWS says that after adding, modifying, or removing files from a data source, you sync the data source so Bedrock re-indexes the knowledge base; the sync is incremental and processes added, modified, or deleted documents since the last sync. ([AWS Documentation][4])

---

# 7. Security View

For company data, this part matters a lot.

```mermaid
flowchart TD
    U[User] --> A[Chat App]

    A --> B[Identity Provider<br/>Entra ID / Cognito / IAM Identity Center]

    B --> C{User Authorized?}

    C -->|No| D[Deny Access]
    C -->|Yes| E[Apply Data Access Filter]

    E --> F[Bedrock Knowledge Base Query]

    F --> G[Vector Store Search<br/>Filtered by metadata / ACL / classification]

    G --> H[Retrieve Allowed Chunks Only]

    H --> I[Foundation Model]

    I --> J[Answer]

    J --> K[Audit Logs<br/>CloudWatch / CloudTrail / App Logs]
```

Important design point:

> Do not let every user search every company document.

Use metadata and authorization boundaries such as:

```text
department = cloud-security
classification = internal
mission_owner = MO-A
environment = govcloud
document_owner = platform-team
```

Then filter retrieval based on the user’s access.

---

# 8. Simplest AWS-Native Design

For your first design, this is the easiest path:

```mermaid
flowchart TD
    A[Company Documents] --> B[Amazon S3 Bucket]

    B --> C[Amazon Bedrock Knowledge Base]

    C --> D[Amazon Titan / Cohere Embedding Model]

    C --> E[Amazon OpenSearch Serverless<br/>or S3 Vectors / Aurora pgvector]

    U[User] --> F[Web App / Chat UI]

    F --> G[Amazon Cognito or Entra ID OIDC]

    G --> H[Bedrock RetrieveAndGenerate API]

    H --> C

    C --> I[Foundation Model<br/>Claude / Llama / Titan / Mistral]

    I --> J[Answer with Citations]

    J --> U
```

Use this if you want a managed AWS-native RAG implementation without building your own parser, chunker, embedding pipeline, and retriever.

---

# 9. What you actually feed into Bedrock

You feed Bedrock a **data source**, not raw training data.

```text
You provide:
- S3 bucket or connector
- Supported files
- Optional metadata files
- Embedding model choice
- Vector store choice
- Sync schedule or manual sync

Bedrock handles:
- Parsing
- Chunking
- Embedding
- Indexing
- Retrieval
```

A good first version would be:

```text
Amazon S3 bucket:
s3://company-ai-knowledge-base/

Folders:
  /architecture/
  /runbooks/
  /policies/
  /terraform/
  /networking/
  /identity/
  /security/
  /diagrams/

File types:
  .md
  .txt
  .docx
  .pdf
  .csv
  .xlsx
  .png
```

For architecture and security documents, **Markdown plus Mermaid plus ASCII flow** is the most reliable format. PDF and images are useful, but I would not make image-only documents your primary knowledge source.

[1]: https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base-ds.html "Prerequisites for your Amazon Bedrock knowledge base data - Amazon Bedrock"
[2]: https://docs.aws.amazon.com/bedrock/latest/userguide/kb-how-data.html "Turning data into a knowledge base - Amazon Bedrock"
[3]: https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html?utm_source=chatgpt.com "Retrieve data and generate AI responses with ..."
[4]: https://docs.aws.amazon.com/bedrock/latest/userguide/kb-data-source-sync-ingest.html "Sync your data with your Amazon Bedrock knowledge base - Amazon Bedrock"
