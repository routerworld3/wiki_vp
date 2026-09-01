# Amazon ECS — Component Model and the GHES Runner Path

## 1. The mental model

ECS has exactly three ideas underneath all the vocabulary:

| Layer | What it is | Analogy |
|---|---|---|
| **Declaration** | Task Definition | The AMI / the Dockerfile output — a versioned, immutable spec |
| **Instantiation** | Task | The running EC2 instance — a live object with an ID, an IP, and a lifecycle |
| **Reconciliation** | Service | The Auto Scaling Group — a controller that keeps N instantiations alive |

Everything else (cluster, capacity provider, agent, container instance) exists to answer one question: **where does the compute come from?**

The control plane is AWS-managed and lives outside your VPC. Your tasks live inside your VPC. That split is why the task ENI matters so much for troubleshooting — it is the only part of the data path you can actually observe.

---

## 2. Object model

```mermaid
flowchart TB
    subgraph CTRL["ECS Control Plane — AWS managed, outside your VPC"]
        SCHED["Scheduler<br/>placement + reconciliation"]
        REG["Task Definition Registry<br/>family:revision"]
    end

    subgraph ACCT["Your AWS Account"]
        CLUSTER["Cluster<br/>logical boundary + namespace"]

        SVC["Service<br/>desiredCount = 3<br/>deployment controller"]
        CP["Capacity Provider Strategy<br/>FARGATE / FARGATE_SPOT / ASG"]

        subgraph TASK["Task — a running instance of a revision"]
            C1["Container: app"]
            C2["Container: sidecar<br/>optional"]
            ENI["Task ENI — awsvpc<br/>private IP + security groups"]
        end

        TG["Target Group<br/>optional, ALB/NLB"]
    end

    subgraph SUPPORT["Supporting Services"]
        ECR["ECR<br/>image source"]
        CWL["CloudWatch Logs<br/>stdout/stderr"]
        IAMX["Task Execution Role<br/>used BEFORE container starts"]
        IAMT["Task Role<br/>used BY your code"]
    end

    REG -.->|"blueprint"| TASK
    SCHED -->|"places"| TASK
    CLUSTER --> SVC
    SVC -->|"maintains N"| TASK
    SVC --> CP
    CP -->|"supplies compute"| TASK
    SVC -->|"registers task IP:port"| TG
    TG -->|"health checks + traffic"| ENI

    IAMX -->|"docker pull"| ECR
    IAMX -->|"create log stream"| CWL
    IAMT -.->|"sts / s3 / secrets at runtime"| C1
    C1 --> CWL
    ENI --- C1
    ENI --- C2
```

**Key relationships people get wrong:**

- A Task Definition is **immutable**. You never edit one; you register a new revision. `my-runner:14` and `my-runner:15` are different objects.
- A Service is optional. `RunTask` launches a standalone task with no controller behind it — which is often the *correct* choice for CI runners (see §6).
- Containers in a task share the ENI, the network namespace, and `localhost`. Two containers in one task cannot both bind :443.
- The task ENI belongs to the task, not the host. It is created at task start and destroyed at task stop.

---

## 3. Where the compute comes from

```mermaid
flowchart LR
    CPS["Capacity Provider Strategy<br/>base / weight"]

    subgraph FG["Fargate — serverless"]
        FGA["AWS-managed microVM"]
        FGN["Task ENI in your subnet<br/>always awsvpc"]
        FGX["No ECS Agent to manage<br/>No IMDS<br/>No host access"]
    end

    subgraph EC2["ECS on EC2 — you own the hosts"]
        CI["Container Instance<br/>EC2 in your ASG"]
        AGENT["ECS Agent<br/>polls control plane"]
        DOCKER["Docker / containerd"]
        HOSTENI["Host ENI + optional trunk ENI<br/>awsvpc, bridge, or host mode"]
    end

    CPS -->|"FARGATE<br/>FARGATE_SPOT"| FG
    CPS -->|"ASG capacity provider"| EC2
    CI --> AGENT --> DOCKER
    CI --> HOSTENI

    style FG fill:#e8f4ea,stroke:#4a7c59
    style EC2 fill:#eef2f8,stroke:#4a6fa5
```

| Concern | Fargate | ECS on EC2 |
|---|---|---|
| Patching the host | AWS | You (AMI refresh, ASG rotation) |
| ECS Agent | Not exposed | You manage it, and it can fail independently |
| Container Instance object | Does not exist | Exists; `describe-container-instances` |
| Network modes | `awsvpc` only | `awsvpc`, `bridge`, `host`, `none` |
| ENI per task | Always | Only with `awsvpc`; density limited without trunking |
| IMDS (`169.254.169.254`) | **Not available** | Available |
| Task metadata | `ECS_CONTAINER_METADATA_URI_V4` | Same |
| Docker socket / DinD | Not possible | Possible (privileged) |
| Accounting | Per-task vCPU/GB-second | Per-EC2-instance, regardless of packing |

**The Fargate item that bites CI runners:** no Docker socket. If your GitHub workflows do `docker build`, Fargate cannot do it natively — you need Kaniko, Buildah, BuildKit rootless, or ECS on EC2.

---

## 4. The two IAM roles

This is the single most common ECS misconfiguration, so it gets its own diagram.

```mermaid
sequenceDiagram
    participant SVC as ECS Service
    participant AGENT as ECS Agent / Fargate Runtime
    participant XROLE as Task Execution Role
    participant ECR as ECR
    participant SM as Secrets Manager / SSM
    participant CWL as CloudWatch Logs
    participant APP as Your Container Process
    participant TROLE as Task Role
    participant AWS as S3 / STS / KMS

    SVC->>AGENT: Start task from revision N
    AGENT->>XROLE: AssumeRole
    XROLE->>ECR: GetAuthorizationToken + BatchGetImage
    ECR-->>AGENT: image layers
    XROLE->>SM: GetSecretValue for task-def "secrets" block
    SM-->>AGENT: values injected as env vars
    XROLE->>CWL: CreateLogStream
    AGENT->>APP: Container starts

    Note over APP,TROLE: Container is now running — execution role is done

    APP->>TROLE: GET 169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
    TROLE-->>APP: temporary credentials
    APP->>AWS: sts:AssumeRole, s3:GetObject, etc.
    APP->>CWL: stdout / stderr via awslogs driver
```

| | Task Execution Role | Task Role |
|---|---|---|
| Who uses it | The ECS agent / Fargate runtime | Your application process |
| When | Before and during container startup | After the container is running |
| Typical policy | `AmazonECSTaskExecutionRolePolicy` + `secretsmanager:GetSecretValue` + `kms:Decrypt` | Whatever your app calls — `sts:AssumeRole` for cross-account Terraform, `s3:*` on state buckets |
| Failure symptom | Task never starts. `CannotPullContainerError`, `ResourceInitializationError`, `AccessDeniedException` on the secret | Task starts fine, then the app throws `AccessDenied` mid-job |

**Rule of thumb:** if the failure is in `stoppedReason` on the task, it is the execution role. If the failure is in your container logs, it is the task role.

**GovCloud note:** both role ARNs are in the `aws-us-gov` partition, and the managed policy is `arn:aws-us-gov:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`. Cross-partition `AssumeRole` does not work — a GovCloud runner cannot assume a role in a commercial account.

---

## 5. Task startup in a private subnet

Worth internalizing because it explains most "task stuck in PROVISIONING/PENDING" tickets in a no-IGW environment.

```mermaid
flowchart TB
    S1["PROVISIONING<br/>ENI created and attached in your subnet"]
    S2["PENDING<br/>image pull + secret fetch"]
    S3["RUNNING<br/>your process is up"]
    S4["DEACTIVATING / STOPPING<br/>deregister from TG, SIGTERM"]
    S5["STOPPED<br/>ENI deleted"]

    S1 --> S2 --> S3 --> S4 --> S5

    S1 -.->|"fails if subnet has no free IPs<br/>or SG/subnet invalid"| F1["ResourceInitializationError"]
    S2 -.->|"fails if no route to ECR/S3/Logs/Secrets"| F2["CannotPullContainerError<br/>ResourceInitializationError: unable to pull secrets"]
    S3 -.->|"exits non-zero"| F3["Essential container exited"]
```

Required egress before your container ever runs — via NAT, or via interface endpoints if you have no NAT:

| Endpoint | Why |
|---|---|
| `com.amazonaws.<region>.ecr.api` | Auth token, image manifest |
| `com.amazonaws.<region>.ecr.dkr` | Registry protocol |
| `com.amazonaws.<region>.s3` **(gateway)** | ECR layers physically live in S3 |
| `com.amazonaws.<region>.logs` | `awslogs` driver |
| `com.amazonaws.<region>.secretsmanager` / `.ssm` | Only if the task def uses `secrets` |
| `com.amazonaws.<region>.ssmmessages` | Only if you want ECS Exec |

The S3 gateway endpoint is the one that gets forgotten. Image pull fails with the three interface endpoints present but no S3 route.

**GovCloud caveats to verify against current docs rather than trust from memory:**
- **Fargate Spot** has historically not been offered in `us-gov-west-1` / `us-gov-east-1`. If your capacity provider strategy includes `FARGATE_SPOT`, confirm before you write the Terraform.
- Fargate platform version parity lags commercial; pin `platform_version` explicitly rather than using `LATEST` if you depend on a specific behavior.
- FIPS endpoints (`ecs-fips`, `ecr-fips`, `logs-fips`) may be required by your ATO boundary — check whether the interface endpoints above need the FIPS variant.
- ECS Exec is generally available but often blocked by SCP in DoD orgs; do not design your troubleshooting workflow around it.

---

## 6. Your GHES runner on ECS

Based on what you described. I do not have your actual account topology, so treat the ALB and GHES placement as the two hypotheses you are trying to distinguish, not as established fact.

```mermaid
flowchart TB
    subgraph GH["GitHub Enterprise Server"]
        GHES["GHES appliance<br/>:443"]
    end

    subgraph VPC["Runner VPC"]
        subgraph PRIV["Private subnets"]
            subgraph T["ECS Task"]
                RUNNER["actions/runner container<br/>long-poll to GHES"]
                TENI["Task ENI<br/>10.x.x.x + SG<br/>← flow log observation point"]
            end
        end

        subgraph ALBSUB["ALB subnets"]
            ALB["ALB nodes<br/>one ENI per AZ"]
        end

        R53["Route 53 Resolver<br/>or inbound endpoint"]
        RT["Route table<br/>+ NFW / TGW"]
    end

    ECSSVC["ECS Service<br/>desiredCount = N"] -->|"maintains"| T
    RUNNER --- TENI
    RUNNER -->|"1. resolve ghes.example.mil"| R53
    R53 -.->|"answer determines the path"| RUNNER
    TENI -->|"2. HTTPS :443 to resolved IP"| RT
    RT -->|"Path A"| ALB
    ALB -->|"proxied"| GHES
    RT -->|"Path B — direct"| GHES

    style TENI fill:#fff3cd,stroke:#856404
    style R53 fill:#e7e0f5,stroke:#6b4fa0
```

**The registration direction matters:** the runner dials out to GHES and holds a long-poll. GHES never initiates inbound to the task. So the security group on the task ENI needs egress :443 only, and any inbound rule you find is either for the ALB health check (if the runner is behind one, which it usually should not be) or is vestigial.

**Service vs RunTask for runners.** If you register runners with `--ephemeral`, each runner exits after one job. Under a Service with `desiredCount = 3`, ECS will restart them continuously — that works, but you get constant task churn, noisy deployment events, and no correlation between a job and a task. The alternative is a webhook-driven `RunTask` per queued job. Either is defensible; just know which one you built, because it changes what "3 tasks are running" means when you are debugging.

---

## 7. Answering "ALB or direct?" from flow logs

Your instinct is right that the task ENI is the leverage point. The method:

**Step 1 — get the ENI and IP for a live task.**

```bash
aws ecs describe-tasks \
  --cluster <cluster> \
  --tasks <task-arn> \
  --query 'tasks[].attachments[].details[?name==`networkInterfaceId` || name==`privateIPv4Address`].[name,value]' \
  --output text
```

**Step 2 — enumerate the ALB's private IPs**, so you have something to compare against.

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=description,Values=ELB app/<alb-name>/*" \
  --query 'NetworkInterfaces[].[PrivateIpAddress,AvailabilityZone]' \
  --output text
```

**Step 3 — query the flow logs.** In Splunk, against `aws:cloudwatchlogs:vpcflow`:

```
index=<vpcflow_index> sourcetype=aws:cloudwatchlogs:vpcflow
  src_ip=10.x.x.x dest_port=443
| stats count sum(bytes) as bytes by src_ip dest_ip action
| sort - bytes
```

Then read `dest_ip`:

| `dest_ip` matches | Conclusion |
|---|---|
| An ALB node IP from Step 2 | Path A — going through the ALB |
| The GHES appliance IP | Path B — direct, ALB bypassed |
| A proxy IP | The container has `HTTPS_PROXY` set and DNS/routing is irrelevant |
| Nothing at all, or `action=REJECT` | SG egress or NACL, not a routing question |

**Two things that will mislead you here:**

1. **Flow logs record the packet's actual destination IP, not the next hop.** If traffic crosses a NAT gateway, TGW, or Network Firewall endpoint, the `dest_ip` at the *task* ENI is still the final destination. So the task-ENI record alone tells you which endpoint was chosen — but it tells you nothing about whether the packet survived the inspection path. If you see the right `dest_ip` and still no connectivity, pull flow logs from the NFW/TGW attachment ENIs next.

2. **DNS is what actually decides this, not routing.** Path A vs Path B is determined by what `ghes.example.mil` resolves to inside the VPC. If you have a private hosted zone overriding the public record, or a Resolver rule forwarding to on-prem, that is the real control point. Route 53 Resolver query logs will answer the question faster than flow logs will.

**Corroborating signals, cheapest first:**

| Signal | Tells you |
|---|---|
| Route 53 Resolver query logs | What the runner resolved, before any packet moves |
| ALB access logs — is the runner's task IP present as `client:port`? | Definitive proof of Path A |
| ALB `RequestCount` / target group `HealthyHostCount` | Whether the ALB is in the path at all |
| Task ENI flow logs | Chosen destination + accept/reject |
| `nslookup` / `curl -v` via ECS Exec | Ground truth, if Exec is permitted in your enclave |

---

## 8. Quick reference

| Term | One line |
|---|---|
| Cluster | Namespace + capacity boundary. No cost of its own. |
| Task Definition | Immutable versioned blueprint: image, CPU/mem, ports, env, roles, logging, volumes, network mode. |
| Task | A running instantiation. Has an ARN, a lifecycle, and (in `awsvpc`) its own ENI and IP. |
| Service | Controller that reconciles running tasks to `desiredCount`; owns LB registration and deployments. |
| Container | One Docker container inside a task. Shares the task's network namespace with its siblings. |
| Capacity Provider | Declares where compute comes from: `FARGATE`, `FARGATE_SPOT`, or an ASG. |
| ECS Agent | Runs on EC2 container instances, polls the control plane. Not exposed on Fargate. |
| Container Instance | An EC2 host registered to a cluster. EC2 launch type only. |
| `awsvpc` / Task ENI | Each task gets a private IP and security groups — the observability anchor for flow logs. |
| Target Group | Optional. ECS registers task IP:port; the service keeps registration in sync. |
| Task Role | Runtime permissions for your code. |
| Task Execution Role | Startup permissions for ECS itself — ECR pull, secrets fetch, log stream creation. |
| ECR | Image source. Requires `ecr.api` + `ecr.dkr` + **S3 gateway** endpoints in a no-NAT VPC. |
| CloudWatch Logs | Default `awslogs` destination. Alternatives: `awsfirelens` → Firehose → Splunk HEC. |
