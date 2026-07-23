# DevOps Architecture — CI/CD on AWS with GitLab

**A five-part series on building infrastructure CI/CD for a multi-account AWS estate with GitLab.**

Each document defines its primitives once; later documents compose them. Read in order, or jump to the question you have. Every diagram is Mermaid and renders on GitLab/GitHub.

---

## The series

| # | Document | Answers |
|---|---|---|
| 1 | [Infra CI/CD Foundations](01-cicd-for-aws-infrastructure.md) | Why is infrastructure CI/CD fundamentally different from software CI/CD? |
| 2 | [Multi-Account AWS with GitLab](02-multi-account-aws-cicd-with-gitlab.md) | How do you isolate blast radius across many AWS accounts? |
| 3 | [GitLab Architecture](03-gitlab-architecture.md) | What GitLab machinery executes the plan/apply/promote model? |
| 4 | [AWS ↔ GitLab OIDC Integration](04-aws-gitlab-oidc-integration.md) | How do jobs get AWS access with no long-lived keys? |
| 5 | [Real-World Patterns: Environments & Accounts](05-real-world-patterns-environments-and-accounts.md) | How do real teams arrange environments, accounts, and pipelines — and grow them? |

> A single-file version of all five is available as **[DevOps-CICD-AWS-GitLab-Complete-Guide.md](DevOps-CICD-AWS-GitLab-Complete-Guide.md)**.

---

## The core idea in one paragraph

Infrastructure CI/CD does not ship a runnable artifact — it ships a **declaration of desired state** and converges live, shared, stateful cloud resources to match it (Doc 1). Because a mistake mutates real production, you isolate blast radius at the **AWS account** boundary (Doc 2), orchestrate the plan → review → apply → promote flow with **GitLab** stages, environments, and gates (Doc 3), and authorize every job with **short-lived, claim-scoped OIDC credentials** instead of stored keys (Doc 4). Real teams then compose these into environment models and account mappings that grow from a single account to a full landing zone (Doc 5).

---

## How to read it

- **New to infra CI/CD?** Start at Doc 1 and go in order.
- **Designing a multi-account layout?** Docs 2 and 5 (§2, the account maturity ladder).
- **Wiring the pipeline?** Doc 3 (GitLab) then Doc 4 (OIDC).
- **Just need the environment/account mapping?** Doc 5, §§1–3.

---

## Conventions

- **Diagram colors:** green = safe/auto (dev), amber = gated (stage/plan), red = production/destructive, blue = CI-CD/shared, purple = guardrails/approvals.
- **Same code, values differ per environment** — a rule repeated throughout: environments diverge only in inputs (sizes, counts, CIDRs), never in logic.
- **Three stacked permission layers** — trust policy (who) → role policy (what) → SCP (ceiling) — recur from Doc 2 onward.

---

## Possible future documents (Doc 6+)

Cost management & FinOps across accounts · disaster-recovery topology and drills · secrets management (Vault / AWS Secrets Manager) alongside OIDC · compliance-as-code for regulated estates.
