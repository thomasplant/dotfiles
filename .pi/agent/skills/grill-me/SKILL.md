---
name: grill-me
description: Universal interaction principle for gathering requirements, navigating decisions, and processing feedback. Defines the one-question-at-a-time interview format with a recommended answer for every question. Apply this pattern whenever the agent needs information from the user to make a decision, select between options, gather requirements, or incorporate feedback — regardless of which other skill is active.
user-invocable: true
---

# Grill Me

Load this skill directly with `get_skill("grill-me")` whenever you need to resolve unknowns with the user. Other workflows also use it; they do not own it.

A structured questioning pattern for any situation where the agent needs to resolve unknowns with the user. Apply proactively at every decision point — do not wait for the user to ask for it.

## When to apply

Use this pattern whenever:

- Starting a planning or creation workflow that requires information from the user (PRD, agent task, pull request, architecture decision)
- Choosing between two or more valid options or approaches
- The user provides feedback that opens new questions or branches
- A requirement is ambiguous and could reasonably be interpreted in more than one way
- Completing a task requires the user to make a commitment the agent cannot infer from context

## The questioning format

Ask **one question at a time**. Never bundle multiple questions into a single message.

For each question:

1. **State the decision being resolved** — a short label for the branch (e.g. "Scope", "Priority", "Error handling").
2. **Give the relevant context** — explain why the decision matters now and link the artifact involved when one exists (the titled task, pull request, review comment, file and line, or PRD section). Summarize the practical consequences of the main options in one or two sentences.
3. **Ask the specific question** — concrete and answerable, not open-ended.
4. **Provide your recommended answer** — and a brief (1–2 sentence) rationale. The user should be able to reply "yes" or "recommended" to accept it without reading further.
5. **List other options** when meaningful — but keep them brief; the recommended answer should do most of the work.

Context is part of the current question, not an additional question. Load available context from the codebase or connected platform before asking; never invent missing details.

### User-facing language

- Expand an acronym the first time it appears in user-facing text, for example "continuous integration (CI)" or "product requirements document (PRD)". Do not add a glossary when the term is not needed.
- Write complete sentences. Do not use terse sequences of nouns joined by arrows, such as `Scope → Approach → Edge cases`; say, "First decide what is in scope, then choose an implementation approach and consider edge cases."
- Use a titled link for an artifact when its title and URL are available. If the title is unavailable, link its identifier without inventing a title.

### Multiple-choice format

```markdown
**[Decision label]**
**Context:** <why this decision matters now; link the relevant artifact and summarize the consequences of the main options>

<The specific question>

**Recommended:** <your answer> — <1–2 sentence rationale>

| Option      | Description                                                                 |
| ----------- | --------------------------------------------------------------------------- |
| A           | <option>                                                                    |
| B           | <option>                                                                    |
| ...         | Additional lettered options as needed (C, D, …)                             |
| <letter>    | Do nothing — skip this decision; leave things as-is and move on             |
| M           | More context — show more relevant detail, then ask this same question again |
| Recommended | Accept the recommendation above                                             |

Reply with a letter, "recommended", "more", or your own short answer.
```

### More context (M)

When the user replies `M`, `m`, or "more":

- Do not record an answer or count the decision as resolved.
- Fetch and show the missing detail when available, such as the full review comment, acceptance criterion, relevant code, or linked thread.
- Re-ask the same question with the additional context. Do not advance to the next branch.
- If no more reliable context is available, say so directly and re-ask the question with what is known.

### Do nothing

Assign **Do nothing** the next unused letter after the real options (often `E`, but `C` or `D` when there are fewer choices). Keep **M** reserved for More context.

When the user replies with that Do nothing letter:

- Record the decision as **skipped** for that branch — do not invent a default answer
- Continue to the next question or item; do not treat Do nothing as workflow completion
- Do not apply any change, reply, or PRD edit for that item

This is distinct from **stop signals** ("stop", "move on", "just do it") which end the entire workflow, not just one item.

### Open-ended format (when no discrete options exist)

```markdown
**[Decision label]**
**Context:** <why this decision matters now; link the relevant artifact when available>

<The specific question>

**Suggested:** <your proposed answer> — <brief reasoning>

Reply "suggested" to accept, "more" for more context, or provide your own answer.
```

The More context rules apply to open-ended questions too.

## Branching

Walk down the decision tree branch by branch. Resolve dependencies in the right order — do not ask about details until the higher-level decision that gates them is settled.

Example ordering for a new feature:

1. Scope (what is in / out?) → settled first
2. Approach (which implementation direction?) → only after scope is clear
3. Edge cases → only after approach is chosen
4. Success metrics → last, because they depend on what was decided above

If a user's answer to one question makes a planned future question irrelevant, drop it. If it opens a new branch, add those questions.

## Exploring the codebase

If a question can be answered by reading existing code, configuration, or documentation — explore it instead of asking. State what you found and treat it as the answer. Only ask the user when the codebase cannot resolve the ambiguity.

## Stop conditions

Stop asking questions when any of the following occur:

- All branches of the decision tree are resolved
- The active skill's question limit is reached (e.g. `clarify-prd` caps at 5 or 20 depending on complexity — that limit takes precedence)
- The user signals they are done: "that's enough", "move on", "just do it", "stop", or similar
- The remaining open questions are low-stakes and the agent can make a reasonable default choice — state the defaults and proceed

## What "resolved" means

A branch is resolved when the agent has enough information to act on it with confidence. Partial answers that leave the core ambiguity open are not resolved — follow up with a more specific question on the same branch before moving on.

## Relationship to other skills

This pattern is the **questioning backbone** of the following skills:

- `get_skill("address-review-feedback")` — per-comment decision cycle
- `get_skill("create-prd")` — requirement gathering
- `get_skill("clarify-prd")` — interactive questioning
- `get_skill("create-agent-tasks")` — task boundaries and dependency decisions
- `get_skill("implement-agent-task")` — approach clarification
- `get_skill("review-agent-task")` — resolving product ambiguity found during review
- `get_skill("compound-engineering")` — one confirm before writing a keep

Each of those skills defines its own workflow and any question limits. This skill defines _how_ every question within those workflows is asked.
