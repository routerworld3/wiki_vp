

## The One-Sentence Version

**MCP connects agents to *systems*. Skills teach agents *know-how*.**

That's the whole distinction. Everything else flows from it.

## A Concrete Analogy

Imagine you hired a new assistant.

- **MCP is like giving them login credentials and phone numbers** — access to your email, your calendar, your CRM, your database. Now they can *reach* the systems where work happens.
- **Skills are like handing them a binder of standard operating procedures** — "here's how we format quarterly reports," "here's our process for onboarding a client." Now they know *how* to do the work properly.

A great assistant needs both. Credentials without procedures means they can log in but don't know what to do. Procedures without credentials means they know the playbook but can't act on anything.## Why This Matters for Newcomers

The mistake people make is treating these as competitors. They're not — they're complementary.

**Reach for MCP when** the agent needs to *do something in the real world* that requires live data or actions: pulling tickets from Jira, sending a Slack message, querying a production database, posting to GitHub. The data lives somewhere else, and you need a connection.

**Reach for Skills when** the agent needs to *follow your specific way of doing things*: how your company formats a sales proposal, what fields belong in your incident report template, the exact steps for generating a compliance PDF. The knowledge is the deliverable, not the connection.

## A Real Example

Say you want an agent that produces weekly customer health reports.

- It pulls usage data from your data warehouse → **MCP** (live system access)
- It pulls support tickets from Zendesk → **MCP** (live system access)
- It formats the report following your company's exact template, brand colors, and section structure → **Skill** (reusable know-how)
- It saves a polished PDF with the right naming convention → **Skill** (procedural knowledge)

Same agent, both extensions, no overlap.

## The Cost Trade-off

Skills are cheap — a folder with a markdown file. You can create one in 10 minutes.

MCP servers are heavier — a running service, authentication, deployment, monitoring. Worth it when you genuinely need live system access, overkill when you just want the agent to follow a procedure.

The newbie rule of thumb: **if you find yourself spinning up an MCP server just to make the agent format something a certain way, you wanted a Skill.**

---

As for the "most interesting Skill" question — I'd flip it back to you, since you're closer to that ecosystem than I am. What's caught your attention lately?
