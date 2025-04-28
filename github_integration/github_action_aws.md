# AWS Github Action Integration

This **reusable GitHub Actions workflow** does the following:

1. Determines the target AWS environment (dev/test/prod) based on the branch name.
2. Authenticates as a **GitHub App** (via app ID and private key).
3. Downloads helper scripts from a private repo using that GitHub App token.
4. Replaces Terraform version placeholders.
5. Authenticates with AWS (via OIDC and role assumption).
6. Cancels in-progress AWS CodePipeline executions.
7. Zips the current repo and uploads it to S3 for CodePipeline usage.

---

##  BREAKDOWN BY COMPONENTS

###  `on: workflow_call`

This makes the workflow **reusable** (i.e., it can be invoked from other workflows).

**Inputs:**

- `AWS_REGION`, `S3_PATH`, `TF_VERSION`: runtime parameters.
  
**Secrets:**

- AWS Account IDs for `dev`, `test`, `prod`.
- `REPO_NAME`: used to construct the IAM role name and S3 file name.
- `APP_ID` and `PRIV_KEY`: used to authenticate as a **GitHub App**.

---

###  Job: `pushRepoToS3`

Runs on `ubuntu-latest`, with minimal permissions:

```yaml
permissions:
  contents: read
  id-token: write  # Required for OIDC to assume AWS role
```

---

###  1. **Set ENV Vars (Branch to AWS Account mapping)**

This step dynamically sets `AWS_ACCOUNT_ID` based on branch (`main`, `test`, `dev`).

Key Takeaways:

- `main` maps to PROD
- `test` maps to TEST
- `dev` maps to DEV
- Fails if any other branch is used

---

###  2. **GitHub App Authentication**

```yaml
uses: actions/create-github-app-token@v1
with:
  app-id: ${{ secrets.APP_ID }}
  private-key: ${{ secrets.PRIV_KEY }}
```

####  What is this?

- Authenticates as a **GitHub App**, not a personal access token.
- This **creates a short-lived token** with specific repo/org-level access (e.g., to access private helper repos).

> ⚠️ You must pre-configure a GitHub App in your org, grant it access to the needed repositories, and store its `APP_ID` and `PRIV_KEY` as secrets in the calling repo.

---

###  3. **Checkout Repos**

- Checks out **current repository** (using default token).
- Checks out `nmmes-org-codebuild-helpers` repo using **GitHub App token** (created in the previous step).

Key Point: This allows centralized helper logic to be reused securely across multiple repos.

---

###  4. **Configure BuildSpec Scripts**

Replaces the placeholder `terraform-TF_VERSION` in any file named `buildspec*` with the actual Terraform version (from input).

> Example: `terraform-TF_VERSION → terraform-1.5.7`

---

###  5. **Configure AWS Credentials (OIDC Integration)**

```yaml
uses: aws-actions/configure-aws-credentials@v4
with:
  role-to-assume: "arn:aws-us-gov:iam::${{ env.AWS_ACCOUNT_ID }}:role/githubToS3-${{ secrets.REPO_NAME }}"
  role-session-name: "GithubS3Integration"
```

####  What’s happening here?

- Uses **GitHub OIDC** to authenticate to AWS *without using static credentials*.
- Assumes the specified IAM role (`githubToS3-<REPO_NAME>`) using `sts:AssumeRoleWithWebIdentity`.

> This role must be created in advance and trusted for OIDC federated login from GitHub.

####  CloudFormation

You mentioned a CloudFormation stack that configures GitHub as an OIDC provider — that’s exactly what enables this step. The role's **trust policy** must allow:

```json
"Federated": "arn:aws-us-gov:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com",
"Condition": {
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:ref:refs/heads/*"
  },
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  }
}
```

---

###  6. **Cancel In-Progress CodePipeline Executions**

This step:

- Uses AWS CLI to list all *in-progress* pipeline executions.
- Abandons them to prevent overlapping deployments.

> This is useful for serializing deployment pipelines and avoiding race conditions.

---

###  7. **Zip and Upload Repo to S3**

- Zips the entire repository.
- Uploads it to an S3 bucket for CodePipeline to use as the source artifact.

> Bucket name: `codepipeline-sources-${AWS_ACCOUNT_ID}`  
> Object key: `tf_repos/repo_<repo_name>.zip` (or whatever `S3_PATH` is set to)

---

##  What About the GitHub App vs OIDC?

Let’s clarify the difference:

| Purpose               | GitHub App (App ID & Private Key) | OIDC Provider (IAM Role & GitHub Token)       |
|-----------------------|------------------------------------|-----------------------------------------------|
| Used For              | Accessing private GitHub repos     | Accessing AWS securely without secrets        |
| Authenticates As      | GitHub App Identity                | GitHub Workflow OIDC token                    |
| Where it's used       | To fetch `nmmes-org-codebuild-helpers` repo | To assume AWS IAM role                        |
| How it's used         | `actions/create-github-app-token`  | `aws-actions/configure-aws-credentials`       |

>  They are **independent authentication flows** serving **different targets**:
>
> - **GitHub App** → GitHub API
> - **OIDC** → AWS STS

---

##  Summary Table

| Step                          | Purpose                                                      |
|-------------------------------|--------------------------------------------------------------|
| `Set ENV Vars`                | Determines AWS Account ID based on branch                   |
| `GitHub App Authentication`   | Generates short-lived GitHub token using App ID + Key       |
| `Checkout Repo(s)`            | Clones both calling and helper repositories                 |
| `Configure BuildSpec`         | Injects correct Terraform version                           |
| `Configure AWS Credentials`   | Uses OIDC to securely assume AWS IAM Role                   |
| `Cancel CodePipeline`         | Ensures no overlapping executions                           |
| `Zip and Ship`                | Pushes zipped repo to S3 for downstream CodePipeline use     |

---

Would you like a **CloudFormation or Terraform** example that:

- Sets up the OIDC provider
- Creates the trust policy
- Creates `githubToS3-<repo>` role

Let me know and I can generate it!

Absolutely — let’s take a deep dive into how **GitHub App Authentication** works, especially when using the built-in GitHub Action:

```yaml
uses: actions/create-github-app-token@v1
id: app-token
with:
  app-id: ${{ secrets.APP_ID }}
  private-key: ${{ secrets.PRIV_KEY }}
  owner: ${{ github.repository_owner }}
```

---

##  What is `actions/create-github-app-token@v1`?

This is an **official GitHub Action** that:

- Authenticates as a **GitHub App** using its `App ID` and `Private Key`
- Generates a **short-lived installation access token**
- Outputs that token so you can use it in subsequent steps (e.g., to clone private repos)

🔗 GitHub Action: [create-github-app-token](https://github.com/actions/create-github-app-token)

---

##  Why Use GitHub App Authentication?

GitHub Apps are **secure, scoped integrations** — preferred over Personal Access Tokens (PATs) for CI/CD.

Use cases:

- Access private repositories
- Manage issues, PRs, commits
- Automate organization-level tasks
- Enable least-privilege access across multiple projects

---

---

##  Purpose-Based Comparison

| Purpose                                | **GitHub App (App ID & Private Key)**                                   | **OIDC Provider (IAM Role & GitHub Token)**                               |
|----------------------------------------|-------------------------------------------------------------------------|---------------------------------------------------------------------------|
| **Primary Use Case**                   | Secure access to **GitHub APIs** and **private repos**                  | Secure access to **AWS services** using GitHub Actions workflows          |
| **Target System**                      | GitHub                                                                  | AWS IAM                                                                   |
| **Authentication Type**               | App-based token generation                                              | OIDC-based identity federation                                            |
| **Replaces**                           | Personal Access Token (PAT)                                             | Long-lived AWS credentials in GitHub secrets                             |

---

##  GitHub App Authentication Flow (to GitHub API)

>  Used for authenticating as a **GitHub App** to access private repos, perform GitHub API actions (issues, PRs, checkouts, etc.).

###  Flow Summary

```plaintext
[Workflow Step]
  │
  ├── Load GitHub App credentials (APP_ID, PRIVATE_KEY)
  │
  ├── Generate signed JWT
  │
  ├── Exchange JWT for Installation Token (GitHub API)
  │
  └── Use Token to access private GitHub resources (e.g., checkout repo)
```

###  Key Components

| Element             | Description                                                  |
|---------------------|--------------------------------------------------------------|
| `APP_ID`            | ID of your GitHub App (numeric)                              |
| `PRIVATE_KEY`       | PEM-format private key generated when setting up the App     |
| `JWT`               | Short-lived signed token for authenticating as the App       |
| `Installation Token`| Token used to call GitHub APIs or checkout private repos     |

###  Use Cases

- Checkout a **private helper repo** (like shared build scripts)
- Automate issue/PR comments, checks, GitHub metadata operations
- Centralize org-wide integrations via GitHub Apps

---

##  OIDC + IAM Role Flow (to AWS)

>  Used to authenticate **from GitHub Actions to AWS** securely without storing credentials.

###  Flow Summary

```plaintext
[GitHub Actions Workflow]
  │
  ├── GitHub auto-generates OIDC token (JWT)
  │
  ├── Use GitHub Action to call AWS STS AssumeRoleWithWebIdentity
  │
  ├── AWS validates OIDC token (issuer, sub, audience)
  │
  └── Temporary AWS credentials returned to workflow
```

###  Key Components

| Element               | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `OIDC Token`          | JWT automatically issued by GitHub for each workflow run                    |
| `OIDC Provider`       | Registered in AWS IAM: `token.actions.githubusercontent.com`                |
| `IAM Role`            | Trusted for web identity federation via condition: `repo:<org>/<repo>`      |
| `STS`                 | Secure Token Service: exchanges OIDC token for temporary AWS credentials    |

###  Use Cases

- Deploy Terraform/CloudFormation to AWS
- Upload artifacts to S3
- Trigger or cancel CodePipeline
- Push Docker images to ECR

---

##  Visual Diagram Comparison

###  GitHub App Flow

```plaintext
[GitHub Actions Workflow]
   │
   ├──▶ Generate JWT (APP_ID + PRIVATE_KEY)
   │
   ├──▶ GitHub API: Exchange JWT for App Installation Token
   │
   └──▶ Use Token to clone repo / call GitHub API
```

---

###  OIDC to AWS IAM Role Flow

```plaintext
[GitHub Actions Workflow]
   │
   ├──▶ GitHub generates OIDC token for workflow (built-in)
   │
   ├──▶ AWS STS: AssumeRoleWithWebIdentity
   │      ↳ IAM Role trust policy matches repo/org/branch
   │
   └──▶ AWS returns short-lived credentials
```

---

##  Side-by-Side Summary Table

| Feature                              | GitHub App                             | OIDC Provider (AWS)                          |
|--------------------------------------|----------------------------------------|----------------------------------------------|
| **Purpose**                          | GitHub API access                      | AWS API access via IAM                        |
| **Token Issued By**                  | GitHub (via App + JWT)                 | GitHub OIDC provider                          |
| **Expires After**                    | ~1 hour (installation token)           | ~15 minutes (AWS session token)               |
| **Trust Model**                      | GitHub App permissions                 | IAM Role Trust Policy + OIDC sub/aud claims   |
| **Authentication Needed**            | App ID + PEM Private Key               | Built-in OIDC identity from GitHub workflow   |
| **GitHub Secret Required?**          |   Yes (`APP_ID`, `PRIVATE_KEY`)        |  No AWS keys required if using OIDC         |
| **Where It Works**                   | GitHub API / repo clone / metadata     | AWS API (S3, CodePipeline, etc.)              |

---

##  Final Recommendation

Use both **in combination** for secure and scalable GitHub → AWS pipelines:

| Task                        | Use                                      |
|-----------------------------|------------------------------------------|
| Clone private helper repos  | GitHub App (via `create-github-app-token`) |
| Assume AWS IAM roles        | OIDC (via `configure-aws-credentials`)     |

Want a visual architecture diagram of this full CI/CD trust flow across GitHub + AWS? I can draw that too.

Absolutely — let’s go **deep into the OIDC + IAM Role flow** used by GitHub Actions to access AWS **securely, without storing static credentials**. This is a purpose-built machine-to-machine identity federation model based on **OIDC Web Identity Federation**, not traditional user login flows.

---

##  OIDC + IAM Role Flow: Overview

> GitHub Actions runners authenticate to AWS using **short-lived OIDC tokens** issued by GitHub and **validated by AWS STS** (Security Token Service), which returns **temporary IAM credentials**.

---

##  OIDC Authentication Flow Type

This flow uses:

###  **OIDC Web Identity Federation Flow**

| OIDC Flow Type                  | Used In                                       |
|----------------------------------|-----------------------------------------------|
| **Authorization Code Flow**     | User login via browser (OAuth2/OIDC apps)     |
| **Client Credentials Flow**     | Machine-to-machine auth (OAuth2 only)         |
| **Implicit Flow**               | (Legacy) Browser-only apps                    |
|  **Web Identity Federation**   | External workload identity to cloud platform (e.g., GitHub → AWS) |

---

##  End-to-End Flow (GitHub → AWS)

```plaintext
[GitHub Actions Runner]
   │
   ├── 1. GitHub generates OIDC token (JWT)
   │       - Issuer: https://token.actions.githubusercontent.com
   │       - Audience: sts.amazonaws.com
   │       - Subject: repo:<org>/<repo>:ref:refs/heads/<branch>
   │
   ├── 2. GitHub Action calls AWS STS
   │       sts:AssumeRoleWithWebIdentity
   │       → Passes: OIDC token + Role ARN
   │
   ├── 3. AWS validates:
   │        OIDC provider trust (issuer match)
   │        Claims (sub, aud) match trust policy
   │
   ├── 4. AWS STS returns:
   │       - Temporary IAM credentials (Access Key, Secret, Token)
   │
   └── 5. GitHub Actions can now interact with AWS services
```

---

##  Component Breakdown

###  1. OIDC Token (JWT) from GitHub

This JWT is **automatically generated** during the workflow if you set:

```yaml
permissions:
  id-token: write
```

**Claims inside the token:**

| Claim                     | Example                                                            |
|---------------------------|---------------------------------------------------------------------|
| `iss` (issuer)            | `https://token.actions.githubusercontent.com`                       |
| `aud` (audience)          | `sts.amazonaws.com`                                                |
| `sub` (subject)           | `repo:your-org/your-repo:ref:refs/heads/main`                      |
| `repository_owner`        | `your-org`                                                         |
| `repository`              | `your-org/your-repo`                                               |
| `ref`                     | `refs/heads/main`                                                  |

You can decode this JWT on jwt.io or with `jq`.

---

###  2. AWS OIDC Provider Setup

You must **register GitHub’s OIDC provider** in AWS:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list <GitHub CA thumbprint>
```

This is often deployed via CloudFormation/Terraform.

---

###  3. IAM Role with Web Identity Trust

IAM Role **trusts OIDC tokens** issued by GitHub, and includes **conditions** on `sub` and `aud`:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<account_id>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:your-org/your-repo:*"
    },
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    }
  }
}
```

 This ensures only **specific GitHub repos and branches** can assume this role.

---

###  4. GitHub Workflow Assumes IAM Role

In the workflow YAML:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::<account_id>:role/<RoleName>
    aws-region: us-gov-west-1
```

The action:

- Automatically retrieves the OIDC token from GitHub
- Passes it to AWS STS via `AssumeRoleWithWebIdentity`

---

###  5. AWS STS Returns Temporary Credentials

If AWS validates the token and the trust policy conditions match, it returns:

```json
{
  "Credentials": {
    "AccessKeyId": "ASIA....",
    "SecretAccessKey": "wJalrXUtnF....",
    "SessionToken": "IQoJb3JpZ2luX2VjEMX...",
    "Expiration": "2025-04-19T19:00:00Z"
  }
}
```

These are injected into the GitHub Actions environment as:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

 These credentials are **short-lived (~15 mins)** and scoped only to that IAM role.

---

##  Security Advantages of OIDC

| Feature                      | Benefit                                           |
|------------------------------|---------------------------------------------------|
| **No secrets stored**        | No need for `AWS_SECRET_ACCESS_KEY` in GitHub    |
| **Short-lived tokens**       | Least privilege, automatic expiration             |
| **Fine-grained access**      | Use IAM trust policy conditions (repo, ref, aud)  |
| **Org-wide centralization**  | Share roles across GitHub org repos safely        |

---

##  Summary

| Element                        | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| **Flow Type**                  | OIDC Web Identity Federation                                                |
| **Issuer**                     | `https://token.actions.githubusercontent.com`                               |
| **AWS Role Assumption**        | `sts:AssumeRoleWithWebIdentity`                                             |
| **Auth Token Type**            | JWT issued by GitHub OIDC provider                                          |
| **Trust Policy Scope**         | Based on `repo:org/repo`, `aud`, and optionally branch (`ref`)              |
| **Used In**                    | GitHub Actions workflows (not apps, not human users)                        |
| **Lifetime of Credentials**    | ~15 minutes (configurable with IAM session duration)                        |
| **Replaces**                   | Static IAM credentials in GitHub secrets                                    |

---

Absolutely — let’s go **packet-level and security-deep** into how the **OIDC Web Identity Federation flow** works between **GitHub Actions and AWS STS**.

This includes:

1. What the **actual JWT (OIDC token)** looks like at the wire level
2. The **HTTP request** to AWS STS (`AssumeRoleWithWebIdentity`)
3. The **response** with AWS credentials
4. Key **security insights** on how trust and verification works
5. An **ASCII diagram** to tie it all together

---

##  1. OIDC Token (JWT) Packet Structure

GitHub issues a **JWT** (JSON Web Token), which is used as the **web identity token** when calling AWS STS.

```plaintext
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.               ← Header (base64-encoded)
eyJpc3MiOiJodHRwczovL3Rva2VuLmFjdGlvbnMuZ2l0aHViY29udGVudC5jb20iLCJzdWIiOiJyZXBvOm15LW9yZy9teS1yZXBvOnJlZjp..... ← Payload
<signature>                                          ← Signed using GitHub's private key
```

###  Example Decoded JWT Claims

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:my-org/my-repo:ref:refs/heads/main",
  "aud": "sts.amazonaws.com",
  "repository": "my-org/my-repo",
  "repository_owner": "my-org",
  "ref": "refs/heads/main",
  "exp": 1714152127,
  "nbf": 1714151527,
  "iat": 1714151527
}
```

---

##  2. AWS STS Call (HTTP Packet View)

The GitHub workflow sends the token in a **POST request** to STS like this:

###  HTTP Request (simplified)

```http
POST / HTTP/1.1
Host: sts.amazonaws.com
Content-Type: application/x-www-form-urlencoded

Action=AssumeRoleWithWebIdentity
&Version=2011-06-15
&RoleArn=arn:aws:iam::123456789012:role/github-deploy-role
&RoleSessionName=GitHubSession
&WebIdentityToken=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ....<truncated>
```

The `WebIdentityToken` is passed **inline** in the body (not as an HTTP header).

---

##  3. AWS STS Response (What AWS Sends Back)

If the token is valid and the IAM role trust policy conditions match:

### 🔹 HTTP 200 OK Response (JSON)

```json
{
  "AssumeRoleWithWebIdentityResponse": {
    "AssumeRoleWithWebIdentityResult": {
      "Credentials": {
        "AccessKeyId": "ASIA...",
        "SecretAccessKey": "abc123...",
        "SessionToken": "IQoJb3J...",
        "Expiration": "2025-04-20T01:00:00Z"
      },
      "SubjectFromWebIdentityToken": "repo:my-org/my-repo:ref:refs/heads/main",
      "Audience": "sts.amazonaws.com"
    }
  }
}
```

These credentials are scoped to the IAM role assumed and expire after ~15 minutes (configurable up to 1 hour).

---

##  ASCII FLOW DIAGRAM: GitHub Actions OIDC to AWS IAM

```plaintext
+--------------------+          +------------------------+         +------------------------+
| GitHub Actions     |          | GitHub OIDC Provider   |         | AWS IAM + STS          |
| Workflow Runner    |          | token.actions...com    |         |                        |
+--------------------+          +------------------------+         +------------------------+
        |                                  |                                   |
        | 1. GitHub generates JWT          |                                   |
        |--------------------------------->|                                   |
        |                                  |                                   |
        |                                  |                                   |
        |        JWT w/ sub, aud, iss      |                                   |
        |<---------------------------------|                                   |
        |                                  |                                   |
        |                                  |                                   |
        | 2. POST AssumeRoleWithWebIdentity (JWT, RoleArn)                    |
        |------------------------------------------------------------->       |
        |                                                                  3. |
        |                                            IAM checks:              |
        |                                            - OIDC issuer = GitHub   |
        |                                            - aud = sts.amazonaws.com|
        |                                            - sub matches condition  |
        |                                            - token signature valid  |
        |                                                                  4. |
        |                 Temporary Credentials (AccessKey, Secret, Token)   |
        |<-------------------------------------------------------------       |
        |                                  |                                   |
        | 5. Use credentials in workflow   |                                   |
        +----------------------------------+-----------------------------------+
```

---

##  SECURITY KEY INSIGHTS

| Aspect                    | Insight                                                                 |
|---------------------------|-------------------------------------------------------------------------|
| **Zero long-lived creds** | No AWS credentials are stored in GitHub at any time                    |
| **Short-lived tokens**    | GitHub OIDC token lifetime: ~5 min; AWS creds: ~15 min                 |
| **Trust is scoped**       | IAM Role trust policy limits by `repo:<org>/<repo>:ref:refs/heads/*`   |
| **No GitHub App needed**  | OIDC is **workflow-based**, no GitHub App or PAT needed                |
| **Signed JWT**            | GitHub signs token with private key; AWS validates using known thumbprint |
| **Token audience locked** | AWS requires `aud` claim to be `sts.amazonaws.com`                     |
| **Bound to GitHub context** | Claims like `repository`, `ref`, `actor`, etc., enable tight binding |

---

##  How You Can Observe This Live

To inspect the token during a workflow run, you can dump it:

```yaml
- name: Print OIDC Token
  run: echo "TOKEN=$(curl -s $ACTIONS_ID_TOKEN_REQUEST_URL -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN")"
  env:
    ACTIONS_ID_TOKEN_REQUEST_URL: ${{ secrets.ACTIONS_ID_TOKEN_REQUEST_URL }}
    ACTIONS_ID_TOKEN_REQUEST_TOKEN: ${{ secrets.ACTIONS_ID_TOKEN_REQUEST_TOKEN }}
```

Then decode the token at [jwt.io](https://jwt.io).

---

##  Conclusion

GitHub → AWS via OIDC is a **secure, modern, machine-auth flow** built on:

-  **JWT-based identity federation**
-  **STS AssumeRoleWithWebIdentity**
-  **Temporary IAM credentials**
-  **Fine-grained repo-scoped trust**

It’s the **recommended pattern** for CI/CD access to AWS today.

---

Great! Here's a **sample decoded GitHub OIDC token (JWT)** showing what claims you can expect in a real workflow when using GitHub Actions with OIDC.

---

##  Sample GitHub OIDC JWT (Decoded)

When GitHub Actions generates a JWT for OIDC authentication, it has three parts:

- Header
- Payload (claims)
- Signature

Here's a **decoded payload** (middle part of the JWT):

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:my-org/my-repo:ref:refs/heads/main",
  "aud": "sts.amazonaws.com",
  "ref": "refs/heads/main",
  "sha": "6d82cb95e53ad52bb7c75b1ec0c18c7dba361d7a",
  "repository": "my-org/my-repo",
  "repository_owner": "my-org",
  "actor_id": "1234567",
  "actor": "my-github-username",
  "workflow": "deploy-to-aws.yml",
  "event_name": "push",
  "ref_type": "branch",
  "job_workflow_ref": "my-org/my-repo/.github/workflows/deploy-to-aws.yml@refs/heads/main",
  "runner_environment": "github-hosted",
  "environment": "Production",
  "iat": 1714149500,
  "exp": 1714149800,
  "nbf": 1714149500,
  "jti": "abcde12345-efg67890-hijk"
}
```

---

##  Key Claims Explained

| Claim                   | Description                                                                 |
|--------------------------|-----------------------------------------------------------------------------|
| `iss` (Issuer)           | Always `https://token.actions.githubusercontent.com` for GitHub OIDC       |
| `sub` (Subject)          | **Main trust identifier** for IAM role trust policy (`repo:<org>/<repo>:ref...`) |
| `aud` (Audience)         | Must be `sts.amazonaws.com` — AWS validates this                           |
| `ref`                    | Git ref — e.g., `refs/heads/main`                                          |
| `sha`                    | Commit SHA that triggered the workflow                                     |
| `repository`             | Full repo name: `org/repo`                                                 |
| `repository_owner`       | Organization or user who owns the repo                                     |
| `actor` / `actor_id`     | User who triggered the workflow                                            |
| `workflow`               | Workflow filename (`.github/workflows/*.yml`)                              |
| `event_name`             | GitHub event type: `push`, `pull_request`, etc.                            |
| `environment` (optional) | Deployment environment (from `environment:` block in workflow)             |
| `iat` / `exp` / `nbf`    | Issued at, expires at, not-before timestamps (in seconds since epoch)      |
| `jti`                    | Unique token ID (helps prevent replay attacks)                             |

---

##  Security Notes

- The **`sub` claim is the one IAM uses for matching**, so your role trust policy should match it like:

  ```json
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:*"
    }
  }
  ```

- The **JWT is signed** by GitHub’s OIDC provider and **validated by AWS STS** using the GitHub root CA thumbprint.

- The **audience (`aud`) must exactly match `sts.amazonaws.com`**, or AWS will reject the token.

---

## 🛠 How to Inspect in Your Workflow (Optional)

You can add this debug step (for learning/testing):

```yaml
- name: Inspect OIDC Token (Base64)
  run: |
    curl -s "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=sts.amazonaws.com" \
    -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" | jq .
  env:
    ACTIONS_ID_TOKEN_REQUEST_URL: ${{ secrets.ACTIONS_ID_TOKEN_REQUEST_URL }}
    ACTIONS_ID_TOKEN_REQUEST_TOKEN: ${{ secrets.ACTIONS_ID_TOKEN_REQUEST_TOKEN }}
```

Then paste the JWT at [https://jwt.io](https://jwt.io) and inspect the payload.

---


---

##  Sample GitHub OIDC JWT (Decoded)

When GitHub Actions generates a JWT for OIDC authentication, it has three parts:

- Header
- Payload (claims)
- Signature

Here's a **decoded payload** (middle part of the JWT):

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:my-org/my-repo:ref:refs/heads/main",
  "aud": "sts.amazonaws.com",
  "ref": "refs/heads/main",
  "sha": "6d82cb95e53ad52bb7c75b1ec0c18c7dba361d7a",
  "repository": "my-org/my-repo",
  "repository_owner": "my-org",
  "actor_id": "1234567",
  "actor": "my-github-username",
  "workflow": "deploy-to-aws.yml",
  "event_name": "push",
  "ref_type": "branch",
  "job_workflow_ref": "my-org/my-repo/.github/workflows/deploy-to-aws.yml@refs/heads/main",
  "runner_environment": "github-hosted",
  "environment": "Production",
  "iat": 1714149500,
  "exp": 1714149800,
  "nbf": 1714149500,
  "jti": "abcde12345-efg67890-hijk"
}
```

---

## 🔷 Key Claims Explained

| Claim                   | Description                                                                 |
|--------------------------|-----------------------------------------------------------------------------|
| `iss` (Issuer)           | Always `https://token.actions.githubusercontent.com` for GitHub OIDC       |
| `sub` (Subject)          | **Main trust identifier** for IAM role trust policy (`repo:<org>/<repo>:ref...`) |
| `aud` (Audience)         | Must be `sts.amazonaws.com` — AWS validates this                           |
| `ref`                    | Git ref — e.g., `refs/heads/main`                                          |
| `sha`                    | Commit SHA that triggered the workflow                                     |
| `repository`             | Full repo name: `org/repo`                                                 |
| `repository_owner`       | Organization or user who owns the repo                                     |
| `actor` / `actor_id`     | User who triggered the workflow                                            |
| `workflow`               | Workflow filename (`.github/workflows/*.yml`)                              |
| `event_name`             | GitHub event type: `push`, `pull_request`, etc.                            |
| `environment` (optional) | Deployment environment (from `environment:` block in workflow)             |
| `iat` / `exp` / `nbf`    | Issued at, expires at, not-before timestamps (in seconds since epoch)      |
| `jti`                    | Unique token ID (helps prevent replay attacks)                             |

---

##  Security Notes

- The **`sub` claim is the one IAM uses for matching**, so your role trust policy should match it like:

  ```json
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:*"
    }
  }
  ```

- The **JWT is signed** by GitHub’s OIDC provider and **validated by AWS STS** using the GitHub root CA thumbprint.

- The **audience (`aud`) must exactly match `sts.amazonaws.com`**, or AWS will reject the token.

---

##  How to Inspect in Your Workflow (Optional)

You can add this debug step (for learning/testing):

```yaml
- name: Inspect OIDC Token (Base64)
  run: |
    curl -s "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=sts.amazonaws.com" \
    -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" | jq .
  env:
    ACTIONS_ID_TOKEN_REQUEST_URL: ${{ secrets.ACTIONS_ID_TOKEN_REQUEST_URL }}
    ACTIONS_ID_TOKEN_REQUEST_TOKEN: ${{ secrets.ACTIONS_ID_TOKEN_REQUEST_TOKEN }}
```

Then paste the JWT at [https://jwt.io](https://jwt.io) and inspect the payload.

---

Excellent question — this goes to the **heart of how AWS STS verifies an OIDC token** from GitHub Actions. Let's walk through it step-by-step, including cryptographic verification and trust policy logic.

---

##  Overview: How AWS Verifies GitHub’s OIDC JWT

When GitHub sends a JWT to AWS STS using `AssumeRoleWithWebIdentity`, AWS validates it by:

1. **Checking the OIDC Issuer** (`iss`)
2. **Validating the Signature** (against GitHub’s public key)
3. **Verifying Claims** (`aud`, `sub`, etc.)
4. **Ensuring the OIDC Provider is Trusted in IAM**
5. **Checking IAM Role Trust Policy Conditions**

---

##  Step-by-Step: JWT Verification by AWS

###  Step 1: GitHub Action Sends Token

The GitHub Action (like `aws-actions/configure-aws-credentials`) sends this:

```http
POST /?Action=AssumeRoleWithWebIdentity...
Content-Type: application/x-www-form-urlencoded

WebIdentityToken=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
RoleArn=arn:aws:iam::123456789012:role/github-deploy-role
```

---

###  Step 2: AWS Extracts and Parses the JWT

- Splits the JWT into **header, payload, and signature**
- Decodes the **header** to see which algorithm is used (`alg: RS256`)
- Extracts the `iss` (issuer) and `aud` (audience) from the payload

Example:

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "aud": "sts.amazonaws.com",
  "sub": "repo:my-org/my-repo:ref:refs/heads/main"
}
```

---

###  Step 3: AWS Looks Up the OIDC Provider in IAM

AWS checks:  
> *“Do I trust this issuer (`https://token.actions.githubusercontent.com`) as a valid OIDC provider?”*

 This depends on whether the OIDC provider was created in the AWS account:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list <GitHub_CA_thumbprint>
```

If the OIDC provider is not defined, **STS will reject the request immediately.**

---

###  Step 4: AWS Validates the JWT Signature

- The JWT is **signed by GitHub’s private key**.
- AWS uses the **GitHub public key (via the OIDC provider’s JWKs endpoint)** to validate the signature.

GitHub's OIDC JWKs endpoint:

```
https://token.actions.githubusercontent.com/.well-known/openid-configuration
→ points to:
https://token.actions.githubusercontent.com/.well-known/jwks
```

These JWKs (public keys) are used by AWS to ensure the token wasn't tampered with.

>  **No shared secrets** — it's public key cryptography (RS256).

---

###  Step 5: AWS Verifies `aud` and `sub` Claims

**Required:**

- `aud` (audience) **must exactly match** `sts.amazonaws.com`
- `sub` (subject) must match what's allowed in the IAM Role trust policy

**IAM Role Trust Policy Example:**

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<account_id>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:*"
    }
  }
}
```

If `aud` ≠ `sts.amazonaws.com` → ❌ REJECT  
If `sub` doesn’t match → ❌ REJECT

---

### 🔷 Step 6: AWS STS Issues Temporary Credentials

If **issuer is trusted**, **JWT signature is valid**, and **claims match the IAM trust policy**, AWS responds with:

```json
{
  "AccessKeyId": "...",
  "SecretAccessKey": "...",
  "SessionToken": "...",
  "Expiration": "2025-04-20T01:00:00Z"
}
```

These are scoped to the permissions defined in the IAM role.

---

##  ASCII Recap: Trust Verification Chain

```plaintext
[GitHub Actions Runner]
   |
   |-- JWT (RS256 signed)
   |
   ▼
[AWS STS]
   |
   |-- Check OIDC Provider Exists (issuer match)
   |-- Fetch JWKs from GitHub → Validate JWT Signature
   |-- Check `aud` == "sts.amazonaws.com"
   |-- Check `sub` matches IAM Role Trust Policy
   ▼
[Success] → Return temporary AWS credentials
```

---

##  Security Highlights

| Security Mechanism          | How It Protects AWS IAM                                                 |
|-----------------------------|---------------------------------------------------------------------------|
| **OIDC Provider Setup**     | Explicit trust anchor — you must register the issuer + thumbprint        |
| **Public Key Signature**    | Ensures GitHub token hasn’t been forged or tampered                      |
| **aud Claim**               | Prevents misuse of token for other platforms                             |
| **sub Claim Restriction**   | Binds GitHub tokens to specific repos and branches                       |
| **Short Token TTL**         | Limits the window for any misuse (JWT ~5 mins, AWS creds ~15 mins)       |
| **IAM Role Conditions**     | Granular control over who can assume the role and from which workflows   |

---


