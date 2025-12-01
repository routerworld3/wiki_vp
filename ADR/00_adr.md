### What an ADR is

**Architectural Decision Record (ADR)**
A short, version-controlled document that captures **one significant technical decision** and the context around it:

* **Context** – the forces at play (requirements, constraints, risks, stakeholders).
* **Decision** – what you chose and, just as important, what you rejected.
* **Consequences** – how the choice affects the system today and in the future (trade-offs, follow-up work, reversibility).

The idea was popularised by Michael Nygard in *“Documenting Architecture Decisions”* and has become a lightweight alternative to heavyweight design documents.

---

### When to create an ADR

| Create an ADR **when …**                                                                                                   | Don’t bother **when …**                                                                         |
| -------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| The choice will be **hard to reverse** once code or infra ships (e.g., pick → Terraform vs Pulumi; choose a TGW layout).\* | It’s a **coding convention** or minor refactor you can change any sprint.                       |
| Multiple viable options exist and you need to **record why one won** (and why others lost).\*                              | The decision is dictated by a policy or the platform (e.g., “use AWS-managed KMS keys for S3”). |
| The outcome will affect **many teams** or **multiple years** of maintenance.                                               | It’s a one-off tweak local to a single micro-service.                                           |
| You see the same argument **re-litigated** every few months (“Why do we have an Inspection VPC again?”).                   | There is no real alternative and the choice is obvious.                                         |

\* Those starred cases map perfectly to your SCCA design choices—Ingress patterns, BCAP connectivity, TGW peering strategy, firewall posture, etc.

---

### “Nobody can use all these options—why document them?”

1. **Memory vs. discovery**
   *People leave, Slack scrolls away.* ADRs give newcomers the *“why”* behind a design in <2 min of reading—no tribal-knowledge hunting.

2. **Prevent re-hashing**
   Teams can focus on new problems instead of revisiting solved ones. If the context really changes (e.g., AWS raises TGW-to-TGW peering limits), you supersede the old ADR with a new one.

3. **Audit & compliance**
   In regulated environments (IL5, SCCA, DoD), being able to point an assessor to “ADR-0017 – All North-South traffic inspected by NFW” is gold.

4. **Parallel exploration**
   You rarely implement every pattern. ADRs let you park research outcomes that *might* be useful later (e.g., “egress via NAT vs. GWLB NAT-instance”) without bloating the current sprint backlog.

---

### Making ADRs usable—not shelved

| Practice                                              | Why it helps                                                         |
| ----------------------------------------------------- | -------------------------------------------------------------------- |
| **Keep each ADR < 1 page Markdown**                   | Easier to skim; encourages focus on the decision, not the prose.     |
| **Number & index** (`0001-…`, `0002-…`)               | Predictable links (<repo>/docs/adr/0003-foo.md).                     |
| **Link from code / Terraform** (`# see ADR-0005`)     | Developers trip over the reference at the exact place it matters.    |
| **Tag & label** (e.g., `networking`, `security`)      | GitHub search surfaces related records quickly.                      |
| **Template** (title, context, decision, consequences) | Consistency means nobody has to relearn the format.                  |
| **Superseded / amended markers**                      | Helps readers know which record is current without deleting history. |

> **Rule of thumb:** if the decision costs more than an afternoon to undo, write an ADR.
> You’ll spend **\~15 minutes to save days** of future head-scratching.

With that lightweight discipline, a team can reap the benefits of institutional memory **without overwhelming contributors**—you’ll capture only the handful of decisions that truly steer the architecture.

Do ADRs need a working implementation first?
No. An ADR is recorded when the decision is made, not after the code ships. Typical rhythm:

Explore / spike – gather facts, prototypes, proofs-of-concept.
Decision meeting – pick the option; write the ADR in Proposed status.
Implementation – as you build, you might discover new constraints.
Accept or supersede – update status to Accepted (or Superseded if you pivot).
Key point: the ADR captures the reasoning at the moment of choice, providing a breadcrumb for future teams—even if the solution is still theoretical or only partly prototyped. When reality diverges, you amend or replace the ADR; the historical context remains intact.

## How ADRs usually unfold—from a quick note to a “living” record

### 1. The initial spark

*Someone notices a fork in the road.*

* **Lightweight decision** ( *“What tag set do we standardise on?”*)
  — A chat + 15 min Markdown note is enough. No prototype, few unknowns.
* **Heavy decision** ( *“Pick an inspection model for all North-South traffic”*)
  — Needs a design spike or PoC first; unknowns and trade-offs are explicit.

### 2. Spike / proof-of-concept (only when needed)

You build just enough to reveal feasibility, cost, and constraints—nothing production-grade. The spike’s findings feed the **Context** and **Consequences** sections.

### 3. **Proposed** ADR

Write the record while the decision is *fresh*:

```md
---
id: 0006
title: Mission-Owner Attachment Model
status: Proposed      # Accepted | Superseded | Deprecated
date: 2025-05-21
authors: VP, J.Doe
---

## Context
....

## Decision
....

## Consequences
....
```

*Optional, when it helps:*

* **Alternatives considered** with brief Pros / Cons bullets.
* **PoC results** (“latency +3 ms, ALB handles mTLS, TGW limit 5 0 K”).
* **Diagram or link to design doc**.

### 4. Review & **Accepted**

Peers sign off (PR merge, architecture board, etc.). Status switches to **Accepted**; now the ADR is the single source of truth until proven wrong.

### 5. Implementation & drift watch

As you build, two things may happen:

1. **Smooth build** → ADR stays as is.
2. **New constraint pops up** (“TGW-to-TGW peering can’t share RAM in our Org”) →
   *Minor tweak* → update **Consequences** in-place, keep history in Git.
   *Major pivot* → write **new ADR** that **Supersedes** the old one; link back.

### 6. Superseded / Deprecated

Old record stays for audit purposes but is clearly marked:

```md
status: Superseded
superseded-by: 0012-multi-region-egress
```

---

## Recommended vs. optional sections

| Section                                                         | Needed for every ADR?                            | Notes                                                    |
| --------------------------------------------------------------- | ------------------------------------------------ | -------------------------------------------------------- |
| **Metadata block** (`id`, `title`, `status`, `date`, `authors`) | **Required**                                     | Enables indexing & at-a-glance search.                   |
| **Context**                                                     | **Required**                                     | Forces you to state *why* a decision matters.            |
| **Decision**                                                    | **Required**                                     | The one-liner “We choose X over Y because …”.            |
| **Consequences**                                                | **Required**                                     | Good + bad side-effects; drives risk planning.           |
| **Alternatives considered**                                     | Optional (but strongly encouraged) for big calls | Saves future teams re-evaluating rejected ideas.         |
| **PoC / Metrics / Benchmarks**                                  | Optional                                         | Include only if they were decisive.                      |
| **Diagrams / Links**                                            | Optional                                         | Inline mermaid or link to a design doc; skip if trivial. |
| **Superseded-by** or **Amends**                                 | Optional, appears only when status changes       | Maintains the decision chain.                            |

---

### Typical evolution patterns

1. **“Set-and-forget”**
   *Small, obvious choice.* Stays untouched—maybe re-validated annually.

2. **“Living ADR”**
   *Infrastructure limits, vendor caps, compliance rules* = likely to shift.
   Updates are incremental PRs that tweak *Consequences* or add a footnote (“Peering limit raised to 1 000 in 2026—no longer a blocker”).

3. **“Serial supersede”**
   Major architectural shifts (monolith → micro-TGWs → multi-region mesh). Each phase gets its own ADR; previous ones are Superseded but kept for provenance.

---

### Key take-away

*Write ADRs **when the choice is made**, not when the code is perfect.*
A record can start tiny, grow with spikes and metrics, and—if reality diverges—give birth to a new ADR. What matters is preserving the decision-making story so future engineers (and auditors) know the *“why”* without spelunking Slack threads.

