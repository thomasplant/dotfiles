# review-lite

A cheap, bounded alternative to the built-in `/code-review` (7 finders + N
verify calls + 1 report call). review-lite makes **at most 3 model calls**:

| Call | Model (exact, pinned) | When |
| --- | --- | --- |
| `A-correctness` finder | `anthropic/claude-opus-5-5:medium` | always |
| `B-cross-file` finder | `anthropic/claude-opus-5-5:medium` | always, parallel with A |
| `verify-batch` (one batched call for all surviving candidates) | `openai-codex/gpt-6.1-sol:low` | only if ≥1 deduplicated candidate survives capping at 5 |

No report-writing model call: the final markdown is rendered **deterministically
in plain JS** from the structured, verified data — nothing is worded by a model
at the end.

Both model IDs match the shared `agent/settings.json` (`enabledModels`);
runtime provider availability still needs verification after installation.
Nothing here changes global model tiers
(`~/.pi/workflows/model-tiers.json`) and it does not touch or replace the
built-in `code_review` saved/registered workflow — it is a separate, additively
installed saved workflow named `review-lite`.

## Files

- `review-lite.ts` — the workflow generator (`generateReviewLiteWorkflow()`),
  produces the plain-JS workflow script string. Read the header comment for
  the full behavior contract.
- `install.mjs` — one-shot installer: saves the generated script to the
  **user tier** (`~/.pi/workflows/saved/review-lite.json`), via the real
  installed package's own `createWorkflowStorage` module — so it's available
  from **any project**, not just this `.pi` checkout, and uses the exact same
  on-disk format `/workflows save` produces.
- `test/` — mocked, offline unit tests. See [Testing](#testing).

## Install / update

```
node "$HOME/.pi/agent/review-lite/install.mjs"
```

Re-run after any edit to `review-lite.ts` to refresh the saved copy. Then in a
running Pi session, `/reload` (or restart) to pick it up as a `/review-lite`
slash command; it's readable by `runWorkflow`/`workflow()`/the navigator
immediately without a reload.

The test-runtime bootstrap is currently Windows-specific. Model availability
and workflow execution have not been reverified as part of the dotfiles migration;
review the pinned model IDs before using it on another installation.

## Invocation

review-lite takes `args = { diff: string, diffSource?: string }`. **Collect
the diff yourself, host-side, before invoking the workflow** — do not spend an
extra agent call just to fetch a diff Pi could get from a shell command
directly:

```bash
git diff HEAD            # working tree vs HEAD (most common)
git diff HEAD~3..HEAD    # a commit range
git diff -- path/to/file # a scoped diff
```

### From a running Pi session (recommended)

Ask Pi naturally, after you (or Pi, via the `bash` tool) have the diff text:

> Run the saved `review-lite` workflow with this diff (`diffSource: "git diff
> HEAD"`): \`\`\`diff
> <paste git diff output>
> \`\`\`

Pi's `workflow` tool accepts a saved workflow by `name` plus a JSON `args`
object directly — `workflow({ name: 'review-lite', args: { diff, diffSource }
})` — which avoids the slash-command text-argument parser (`/review-lite
key=value`) entirely. That parser space-splits tokens and is unsuitable for a
multi-line diff with `=` characters in it; prefer the `workflow` tool call or
`workflow('review-lite', { diff, diffSource })` from inside another workflow
script.

### Prompt-template helper (collect diff without spending an agent call)

If you want a single copy-pasteable request, run this yourself first:

```bash
DIFF="$(git diff HEAD)"
printf 'Run the saved review-lite workflow with diffSource "git diff HEAD" and this diff:\n```diff\n%s\n```\n' "$DIFF"
```

Paste the printed text as your message to Pi. This puts the actual `git diff`
work on your shell (free), not on a paid agent call.

### Programmatically (inside another workflow script)

```js
const result = await workflow('review-lite', { diff, diffSource: 'git diff HEAD' })
```

## Output shape

```ts
{
  status: 'clean' | 'findings' | 'incomplete',
  diffTruncated: boolean,
  missingCoverage: string[],       // finder labels that returned no coverage
  verifierIncomplete: boolean,
  verifierIssues: string[],        // duplicate/unknown/omitted verifier ids, etc.
  totalRaw: number,
  totalDeduped: number,
  totalCarried: number,            // <= 5
  omittedCount: number,            // deduped candidates cut by the cap
  findings: Array<{ id, file, line, summary, failure_scenario, angle, verdict, verifyReason }>, // CONFIRMED only
  unresolved: Array<object>,       // uncertain/unverified candidates, not confirmed findings
  report: string,                  // deterministically rendered markdown
}
```

Only CONFIRMED findings appear in the report's findings list. Uncertain or
unverified candidates are returned separately as `unresolved` and force
`status: 'incomplete'`, as do candidates omitted by the five-candidate cap.
Read-only behavior is instructed in prompts, not enforced by a tool sandbox.

`status` is **never** `'clean'` when coverage is incomplete, the diff was
truncated, or the verifier's output was missing/malformed — those cases return
`'incomplete'` with the specific reason(s) in `missingCoverage` /
`verifierIssues` / `diffTruncated`, so a caller (human or agent) cannot mistake
"we couldn't fully check this" for "this is fine."

## Limitations

- **Diff cap:** inputs over 120,000 characters (`MAX_DIFF_CHARS`) are
  truncated, not rejected; the omitted tail is never reviewed. This always
  forces `status: 'incomplete'`.
- **Candidate cap:** at most 5 deduplicated, prioritized (correctness before
  cross-file) candidates reach the verifier and the report. Lower-priority
  candidates beyond the cap are counted in `omittedCount` but not reviewed or
  reported individually.
- **No fix suggestions / no auto-edit.** review-lite only reports; it never
  edits the reviewed code or runs repository scripts.
- **`retries: 0`** on every agent call, by design, so the call budget above is
  exact. A transient empty-output failure from a finder or the verifier is
  reported as missing coverage / incomplete, not silently retried.
- **No token/time cap is imposed by the script itself.** Pass
  `agentTimeoutMs` / `tokenBudget` to the workflow tool or `runWorkflow` call
  if you want one; review-lite does not set a default.
- **Verifier evidence is a windowed diff excerpt per candidate, not the full
  diff**, plus an explicit instruction to independently re-check the real
  file with its own read-only tools. It is not guaranteed to have full
  surrounding file context beyond what its own tool calls retrieve.
- **This is a lighter check than `/code-review`** (2 finder angles vs. 7, one
  batched verify pass vs. per-candidate verify, no narrative synthesis model
  call). Use `/code-review` when you want the deeper multi-angle pass;
  review-lite is for a fast, cheap, bounded second opinion.

## Testing

Offline, mocked, no live model calls, no cost. The workflow **script is
parsed and executed by the real installed
`@quintinshaw/pi-dynamic-workflows`** (`parseWorkflowScript` / `runWorkflow`);
only the leaf subagent runner is replaced with a mock (`options.agent`, the
package's own supported extension point for exactly this purpose) so no
network/provider call happens.

```
node --preserve-symlinks --test "$HOME/.pi/agent/review-lite/test/review-lite.test.mjs"
```

`--preserve-symlinks` is required because the test setup (`test/
setup-workflow-runtime.mjs`) creates Windows junctions under
`test/.rt-linkcache/` so the installed package (which lives in
`agent/npm/node_modules`) can resolve its `@earendil-works/pi-coding-agent`
peer dependency (installed separately, globally, at the `npm root -g`
location) — Node resolves symlinked/junctioned paths to their real location
before doing `node_modules` lookup unless this flag is set. Nothing under any
installed `node_modules` tree is modified; the junctions are test-local and
safe to delete (`test/.rt-linkcache/`).

Covered scenarios (14 tests, including uncertain-verdict handling): real-parser acceptance, no-diff input, empty
findings from both finders (clean, exactly 2 calls, verifier skipped), exact
model routing + exact call count when candidates exist, REFUTED exclusion,
dedup + 5-cap + correctness-priority ordering, one finder returning `null`
(missing coverage, not zero findings), both finders returning `null`, verifier
returning `null`, duplicate verifier ids, unknown verifier ids, omitted
verifier ids, and oversized-diff truncation — each assertion checks that the
corresponding failure mode never resolves to `status: 'clean'`.
