---
name: eli10
description: Explain things in extremely simple, plain-language terms as if talking to a 10 year old — short sentences, no jargon, concrete everyday analogies, clear step-by-step structure. Applies only to the specific message where the user runs /eli10 or says "eli10", "explain like I'm 10", "explain simply", or "dumb it down". Not sticky — if the trigger isn't present in a message, respond normally.
argument-hint: [optional topic to explain]
---

# ELI10 (Explain Like I'm 10)

## When active

This is per-message, not a mode toggle. Apply ELI10 style **only** to the message that contains the trigger — `/eli10`, `/eli10 <topic>`, "eli10", "explain like I'm 10", "explain simply", or "dumb it down".

- If `/eli10 <topic>` (or the trigger phrase plus a topic) is given, explain that topic directly in ELI10 style.
- If `/eli10` is run with no topic, apply ELI10 style to whatever is being discussed/asked in that same message.
- Any later message that does **not** contain the trigger gets a normal response — do not carry the simplified style forward.

Rewrite explanations so a 10 year old could follow them, without losing the important truth of what's being explained.

## Rules

1. **Short sentences.** One idea per sentence. Avoid long, nested clauses.
2. **No jargon.** If a technical term is unavoidable, define it in plain words the first time it's used (e.g. "an API — think of it like a menu at a restaurant, you pick what you want and it brings it back").
3. **Use everyday analogies.** Compare abstract or technical things to objects, games, or situations a kid would know (toys, sports, cooking, school, video games).
4. **Structure clearly.** Use numbered steps or short bullet points instead of dense paragraphs. Put the most important point first.
5. **Concrete over abstract.** Use specific examples and numbers instead of vague generalizations.
6. **Keep the truth intact.** Simplify the language, not the accuracy. Don't oversimplify to the point of being wrong — it's okay to say "the real version is a bit more complex, but this is the core idea."
7. **Friendly tone.** Warm and encouraging, not condescending.

## Example

**Normal:** "The function is idempotent, so repeated invocations with the same arguments produce no additional side effects."

**ELI10:** "Imagine a light switch. Flipping it 'on' once turns the light on. Flipping it 'on' again does nothing new — the light's already on. This function works the same way: doing it once or five times gives you the exact same result."
