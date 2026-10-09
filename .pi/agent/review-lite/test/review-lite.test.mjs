// Mocked, offline tests for review-lite. No network access, no paid model
// calls: every agent() call is intercepted by a mock WorkflowAgentRunner
// injected via runWorkflow's real `options.agent` extension point. The
// workflow SCRIPT itself and its parsing/execution go through the REAL
// installed @quintinshaw/pi-dynamic-workflows `parseWorkflowScript` /
// `runWorkflow` (see setup-workflow-runtime.mjs) -- only the network-calling
// leaf (the subagent runner) is mocked.
//
// Run with:
//   node --preserve-symlinks --test agent/review-lite/test/review-lite.test.mjs

import assert from "node:assert/strict";
import test from "node:test";
import { importRealWorkflowRuntime } from "./setup-workflow-runtime.mjs";
import { generateReviewLiteWorkflow, MAX_DIFF_CHARS, CANDIDATE_CAP } from "../review-lite.ts";

const { parseWorkflowScript, runWorkflow } = await importRealWorkflowRuntime();
const SCRIPT = generateReviewLiteWorkflow();

// ---- sanity: the real parser accepts the generated script -----------------

test("real parseWorkflowScript accepts the generated script and meta", () => {
  const { meta, body } = parseWorkflowScript(SCRIPT);
  assert.equal(meta.name, "review-lite");
  assert.deepEqual(
    meta.phases.map((p) => p.title),
    ["Find", "Verify", "Report"],
  );
  assert.ok(body.length > 0);
});

// ---- mock runner ------------------------------------------------------

/**
 * Builds a WorkflowAgentRunner (see workflow.ts's WorkflowAgentRunner
 * interface: `run(prompt, options) => Promise<unknown>`) from an ordered
 * list of call handlers keyed by label. Records every call for assertions.
 */
function makeMockAgent(handlersByLabel) {
  const calls = [];
  return {
    calls,
    runner: {
      async run(prompt, options) {
        calls.push({ label: options.label, model: options.model, prompt, schema: options.schema });
        const handler = handlersByLabel[options.label];
        if (!handler) {
          throw new Error(`unexpected agent call with label "${options.label}" (no mock handler registered)`);
        }
        return handler(prompt, options);
      },
    },
  };
}

const SAMPLE_DIFF = `diff --git a/src/foo.js b/src/foo.js
index 1111111..2222222 100644
--- a/src/foo.js
+++ b/src/foo.js
@@ -10,7 +10,7 @@ function foo(x) {
   if (x == null) {
     return null;
   }
-  return bar(x);
+  return bar(x, x);
 }
`;

async function run(args, handlersByLabel, extraOptions = {}) {
  const { runner, calls } = makeMockAgent(handlersByLabel);
  const result = await runWorkflow(SCRIPT, {
    args,
    agent: runner,
    persistLogs: false,
    ...extraOptions,
  });
  // The workflow script runs in a separate vm realm, so returned arrays/objects
  // are not `instanceof` this realm's Array/Object -- assert.deepEqual/deepStrictEqual
  // in newer Node treat that as a mismatch even when structurally identical.
  // Round-tripping through JSON normalizes to this realm's plain objects.
  return { result: JSON.parse(JSON.stringify(result.result)), calls };
}

// ---- 1. no diff supplied: never a clean review -----------------------

test("missing diff input is reported as incomplete, not clean, and calls no agents", async () => {
  const { result, calls } = await run({}, {});
  assert.equal(result.status, "incomplete");
  assert.equal(result.reason, "no_diff_supplied");
  assert.equal(calls.length, 0);
});

// ---- 2. both finders empty -> clean, exactly 2 calls, no verifier -----

test("no findings from either finder -> clean status, exactly 2 agent calls, verifier skipped", async () => {
  const { result, calls } = await run(
    { diff: SAMPLE_DIFF, diffSource: "git diff HEAD" },
    {
      "A-correctness": async () => ({ candidates: [] }),
      "B-cross-file": async () => ({ candidates: [] }),
    },
  );
  assert.equal(result.status, "clean");
  assert.equal(result.totalRaw, 0);
  assert.equal(calls.length, 2);
  assert.deepEqual(
    calls.map((c) => c.label).sort(),
    ["A-correctness", "B-cross-file"],
  );
});

// ---- 3. exact model routing + call count when candidates exist --------

test("exact model routing: Opus 5.5 medium finders, GPT 6.1 Sol low verifier, exactly 3 calls total", async () => {
  const { result, calls } = await run(
    { diff: SAMPLE_DIFF, diffSource: "git diff HEAD" },
    {
      "A-correctness": async () => ({
        candidates: [{ file: "src/foo.js", line: 13, summary: "extra arg to bar", failure_scenario: "bar ignores 2nd arg" }],
      }),
      "B-cross-file": async () => ({ candidates: [] }),
      "verify-batch": async () => ({
        verdicts: [{ id: "c1", verdict: "CONFIRMED", reason: "traced in diff" }],
      }),
    },
  );
  assert.equal(calls.length, 3);
  const byLabel = Object.fromEntries(calls.map((c) => [c.label, c]));
  assert.equal(byLabel["A-correctness"].model, "anthropic/claude-opus-5-5:medium");
  assert.equal(byLabel["B-cross-file"].model, "anthropic/claude-opus-5-5:medium");
  assert.equal(byLabel["verify-batch"].model, "openai-codex/gpt-6.1-sol:low");
  // Verifier must NOT receive the entire diff, only excerpts + explicit independent-check instruction.
  assert.ok(!byLabel["verify-batch"].prompt.includes(SAMPLE_DIFF));
  assert.match(byLabel["verify-batch"].prompt, /independently use your read-only file\/grep tools/);
  assert.equal(result.status, "findings");
  assert.equal(result.findings.length, 1);
  assert.equal(result.findings[0].verdict, "CONFIRMED");
});

// ---- 4. REFUTED findings are excluded from the reportable list --------

test("REFUTED verdict is excluded from findings but still counted in totals", async () => {
  const { result } = await run(
    { diff: SAMPLE_DIFF },
    {
      "A-correctness": async () => ({
        candidates: [{ file: "src/foo.js", line: 13, summary: "extra arg", failure_scenario: "x" }],
      }),
      "B-cross-file": async () => ({ candidates: [] }),
      "verify-batch": async () => ({ verdicts: [{ id: "c1", verdict: "REFUTED", reason: "already handled" }] }),
    },
  );
  assert.equal(result.status, "clean");
  assert.equal(result.totalDeduped, 1);
  assert.equal(result.findings.length, 0);
});

test("PLAUSIBLE findings stay unresolved, never confirmed or clean", async () => {
  const { result } = await run({ diff: SAMPLE_DIFF }, {
    "A-correctness": async () => ({ candidates: [{ file: "src/foo.js", line: 13, summary: "uncertain", failure_scenario: "possible failure" }] }),
    "B-cross-file": async () => ({ candidates: [] }),
    "verify-batch": async () => ({ verdicts: [{ id: "c1", verdict: "PLAUSIBLE" }] }),
  });
  assert.equal(result.status, "incomplete");
  assert.equal(result.findings.length, 0);
  assert.equal(result.unresolved.length, 1);
  assert.match(result.report, /uncertain or unverified/);
});

// ---- 5. dedup + cap at 5, correctness prioritized over cross-file ------

test("dedup collapses identical candidates and caps at 5, prioritizing correctness", async () => {
  const dupe = { file: "src/a.js", line: 1, summary: "same issue same issue same issue text", failure_scenario: "x" };
  const correctnessCandidates = [
    dupe,
    dupe, // exact duplicate -> deduped
    { file: "src/b.js", line: 2, summary: "issue b", failure_scenario: "x" },
    { file: "src/c.js", line: 3, summary: "issue c", failure_scenario: "x" },
    { file: "src/d.js", line: 4, summary: "issue d", failure_scenario: "x" },
  ];
  const crossFileCandidates = [
    { file: "src/e.js", line: 5, summary: "issue e", failure_scenario: "x" },
    { file: "src/f.js", line: 6, summary: "issue f", failure_scenario: "x" },
  ];
  const { result: result2 } = await run(
    { diff: SAMPLE_DIFF },
    {
      "A-correctness": async () => ({ candidates: correctnessCandidates }),
      "B-cross-file": async () => ({ candidates: crossFileCandidates }),
      "verify-batch": async (prompt) => {
        const ids = [...prompt.matchAll(/ID: (c\d+)/g)].map((m) => m[1]);
        return { verdicts: ids.map((id) => ({ id, verdict: "CONFIRMED", reason: "" })) };
      },
    },
  );
  assert.equal(result2.totalRaw, 7); // 5 + 2, dedup not yet applied
  assert.equal(result2.totalDeduped, 6); // one exact duplicate removed
  assert.equal(result2.totalCarried, CANDIDATE_CAP);
  assert.equal(result2.omittedCount, 1);
  assert.equal(result2.status, "incomplete");
  // Correctness-angle candidates (a/b/c/d, deduped to 4) must all be present before any cross-file one.
  const files = result2.findings.map((f) => f.file);
  assert.deepEqual(files.slice(0, 4).sort(), ["src/a.js", "src/b.js", "src/c.js", "src/d.js"]);
  assert.equal(files.length, 5);
});

// ---- 6. missing finder coverage never becomes "clean" ------------------

test("a finder returning null is recorded as missing coverage, never as zero findings, and forces non-clean status", async () => {
  const { result, calls } = await run(
    { diff: SAMPLE_DIFF },
    {
      "A-correctness": async () => null, // simulates exhausted recoverable failure
      "B-cross-file": async () => ({ candidates: [] }),
    },
  );
  assert.equal(calls.length, 2);
  assert.equal(result.status, "incomplete");
  assert.deepEqual(result.missingCoverage, ["A-correctness"]);
  assert.equal(result.report.includes("missing coverage"), true);
});

test("both finders returning null -> no verifier call, status incomplete, both angles flagged missing", async () => {
  const { result, calls } = await run(
    { diff: SAMPLE_DIFF },
    {
      "A-correctness": async () => null,
      "B-cross-file": async () => null,
    },
  );
  assert.equal(calls.length, 2);
  assert.equal(result.status, "incomplete");
  assert.deepEqual(result.missingCoverage.sort(), ["A-correctness", "B-cross-file"]);
});

// ---- 7. verifier returning null (failed coverage) is never silently clean

test("verifier call returning null marks all candidates unverified and forces status incomplete", async () => {
  const { result } = await run(
    { diff: SAMPLE_DIFF },
    {
      "A-correctness": async () => ({
        candidates: [{ file: "src/foo.js", line: 13, summary: "s", failure_scenario: "f" }],
      }),
      "B-cross-file": async () => ({ candidates: [] }),
      "verify-batch": async () => null,
    },
  );
  assert.equal(result.status, "incomplete");
  assert.equal(result.verifierIncomplete, true);
  assert.equal(result.findings.length, 0);
  assert.equal(result.unresolved[0].verdict, "UNVERIFIED-INVALID_OUTPUT");
});

// ---- 8. duplicate / missing / unknown verifier ids are never silently dropped

test("duplicate verifier ids force incomplete status instead of silently accepting one", async () => {
  const { result } = await run(
    { diff: SAMPLE_DIFF },
    {
      "A-correctness": async () => ({
        candidates: [
          { file: "a.js", line: 1, summary: "s1", failure_scenario: "f1" },
          { file: "b.js", line: 2, summary: "s2", failure_scenario: "f2" },
        ],
      }),
      "B-cross-file": async () => ({ candidates: [] }),
      "verify-batch": async () => ({
        verdicts: [
          { id: "c1", verdict: "CONFIRMED" },
          { id: "c1", verdict: "REFUTED" }, // duplicate id
          { id: "c2", verdict: "CONFIRMED" },
        ],
      }),
    },
  );
  assert.equal(result.status, "incomplete");
  assert.equal(result.verifierIncomplete, true);
  assert.ok(result.verifierIssues.some((m) => m.includes("duplicate id")));
});

test("unknown verifier id forces incomplete status", async () => {
  const { result } = await run(
    { diff: SAMPLE_DIFF },
    {
      "A-correctness": async () => ({ candidates: [{ file: "a.js", line: 1, summary: "s1", failure_scenario: "f1" }] }),
      "B-cross-file": async () => ({ candidates: [] }),
      "verify-batch": async () => ({ verdicts: [{ id: "c1", verdict: "CONFIRMED" }, { id: "c99", verdict: "CONFIRMED" }] }),
    },
  );
  assert.equal(result.status, "incomplete");
  assert.ok(result.verifierIssues.some((m) => m.includes("unknown id")));
});

test("missing verifier id (fewer verdicts than candidates) forces incomplete status", async () => {
  const { result } = await run(
    { diff: SAMPLE_DIFF },
    {
      "A-correctness": async () => ({
        candidates: [
          { file: "a.js", line: 1, summary: "s1", failure_scenario: "f1" },
          { file: "b.js", line: 2, summary: "s2", failure_scenario: "f2" },
        ],
      }),
      "B-cross-file": async () => ({ candidates: [] }),
      "verify-batch": async () => ({ verdicts: [{ id: "c1", verdict: "CONFIRMED" }] }), // c2 omitted
    },
  );
  assert.equal(result.status, "incomplete");
  assert.ok(result.verifierIssues.some((m) => m.includes("omitted ids")));
});

// ---- 9. oversized diff is truncated, surfaced, and never "clean" -------

test("oversized diff is truncated, flagged, and forces status incomplete even with zero findings", async () => {
  const bigDiff = SAMPLE_DIFF + "x".repeat(MAX_DIFF_CHARS + 5000);
  const { result } = await run(
    { diff: bigDiff, diffSource: "git diff HEAD" },
    {
      "A-correctness": async () => ({ candidates: [] }),
      "B-cross-file": async () => ({ candidates: [] }),
    },
  );
  assert.equal(result.diffTruncated, true);
  assert.equal(result.status, "incomplete");
  assert.match(result.report, /truncated/i);
});
