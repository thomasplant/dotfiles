// Bootstraps a tiny local node_modules of Windows junctions so this test
// suite can `import()` the REAL installed @quintinshaw/pi-dynamic-workflows
// runtime (parseWorkflowScript / runWorkflow) plus its peer/dev deps, without
// copying or modifying anything under the installed node_modules trees.
//
// Why junctions: pi-dynamic-workflows's dist/agent.js statically imports
// @earendil-works/pi-coding-agent, which lives in a *different* installed
// location (agent/npm/node_modules) than the package itself would look for
// it. Node's ESM resolver also resolves symlinks to their real path before
// doing node_modules lookup (unless --preserve-symlinks is set), so a plain
// symlink silently breaks resolution again. Windows junctions + running node
// with --preserve-symlinks makes `import()` resolve node_modules relative to
// the *link* location, which is what lets one cache directory see both
// installed trees at once.
//
// This is test-only infrastructure. It never touches the installed
// node_modules directories themselves.

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const CACHE_DIR = join(__dirname, ".rt-linkcache");
const NODE_MODULES = join(CACHE_DIR, "node_modules");

const AGENT_HOME = join(homedir(), ".pi", "agent");
const PI_DYNAMIC_WORKFLOWS = join(AGENT_HOME, "npm", "node_modules", "@quintinshaw", "pi-dynamic-workflows");
// pi-coding-agent (the CLI host) is installed globally via npm, not under
// agent/npm/node_modules -- resolve it from the global npm prefix instead of
// hardcoding a path so this works on any machine.
const GLOBAL_NPM_ROOT = execFileSync("npm", ["root", "-g"], { shell: true }).toString().trim();
const PI_CODING_AGENT = join(GLOBAL_NPM_ROOT, "@earendil-works", "pi-coding-agent");
const ACORN = join(AGENT_HOME, "npm", "node_modules", "acorn");
const TYPEBOX = join(AGENT_HOME, "npm", "node_modules", "typebox");

const LINKS = [
  { target: PI_DYNAMIC_WORKFLOWS, link: join(NODE_MODULES, "@quintinshaw", "pi-dynamic-workflows") },
  { target: PI_CODING_AGENT, link: join(NODE_MODULES, "@earendil-works", "pi-coding-agent") },
  { target: ACORN, link: join(NODE_MODULES, "acorn") },
  { target: TYPEBOX, link: join(NODE_MODULES, "typebox") },
];

function junction(target, link) {
  if (existsSync(link)) return;
  mkdirSync(dirname(link), { recursive: true });
  if (!existsSync(target)) {
    throw new Error(
      `Cannot set up workflow test runtime: expected installed path missing: ${target}. ` +
        `Is @quintinshaw/pi-dynamic-workflows installed via 'pi install'?`,
    );
  }
  execFileSync("powershell.exe", [
    "-NoProfile",
    "-Command",
    `New-Item -ItemType Junction -Path '${link}' -Target '${target}' | Out-Null`,
  ]);
}

/** Ensure the junction cache exists; safe to call repeatedly. */
export function ensureWorkflowRuntimeLinks() {
  for (const { target, link } of LINKS) junction(target, link);
}

/** Import the real installed workflow.js (parseWorkflowScript, runWorkflow) through the link cache. */
export async function importRealWorkflowRuntime() {
  ensureWorkflowRuntimeLinks();
  const entry = join(NODE_MODULES, "@quintinshaw", "pi-dynamic-workflows", "dist", "workflow.js");
  return import(pathToFileURL(entry).href);
}
