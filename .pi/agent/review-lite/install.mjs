// Saves review-lite as a USER-tier saved workflow so it is available from any
// project (not just this .pi cwd), the same storage tier `/workflows save
// <name>` writes to when you pick "user" in the navigator. Uses the real
// installed @quintinshaw/pi-dynamic-workflows storage module directly
// (dist/workflow-saved.js), so the on-disk format is guaranteed compatible
// with the installed package's own reader/writer.
//
// Usage:
//   node agent/review-lite/install.mjs
//
// Re-run any time after editing review-lite.ts to refresh the saved copy.
// Safe to re-run: it overwrites only the user-tier `review-lite` row.

import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { generateReviewLiteWorkflow } from "./review-lite.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIST = join(
  __dirname,
  "..",
  "npm",
  "node_modules",
  "@quintinshaw",
  "pi-dynamic-workflows",
  "dist",
  "workflow-saved.js",
);

const { createWorkflowStorage } = await import(pathToFileURL(PACKAGE_DIST).href);

const storage = createWorkflowStorage(process.cwd());
const saved = storage.save(
  {
    name: "review-lite",
    description:
      "Two parallel reviewers (anthropic/claude-opus-5-5:medium: correctness, cross-file impact) + one batched " +
      "verifier (openai-codex/gpt-6.1-sol:low), max 5 deduplicated findings, deterministic report. " +
      "args: { diff, diffSource }.",
    script: generateReviewLiteWorkflow(),
  },
  "user",
);

console.log(`Saved review-lite to the USER tier: ${saved.path}`);
console.log("Available from any project as a saved workflow named 'review-lite'.");
console.log("Restart Pi (or /reload) to register it as a /review-lite slash command in a running session.");
