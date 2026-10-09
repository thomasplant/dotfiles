# Agent Notes

## Environment

- Use the current platform's shell conventions. On Windows, the bash tool uses Git-for-Windows through the patched pi-patty-bg-tasks extension; bash, bash_bg, jobs, and monitor work normally.
- Package updates can overwrite that Windows shell fix. For ENOENT, missing output, or popup consoles, read ~/.pi/agent/patches/README.md; reapply with bash ~/.pi/agent/patches/apply-patches.sh, restart Pi, and verify with echo test123. Changing shellPath alone does not fix this extension override.
- Local extensions: ~/.pi/agent/extensions/. Installed package source: ~/.pi/agent/npm/node_modules/. For setup/appearance history only, read ~/.pi/agent/notes/pi-setup-history.md; do not preload it for ordinary coding.

## Context and verification preferences

- Keep investigation scoped: read applicable area instructions and relevant code sections, not unrelated modules or full logs. Read unchanged guidance once per session/scope unless it is no longer available in context. Preserve security, correctness, and verification requirements.
- Before runtime verification, provide a short numbered checklist with actions and expected results. Ask whether the user will perform it or wants targeted agent assistance, unless already specified. Use meaningful checkpoints, not interruptions for every routine tool call.
- For agent-assisted browser checks, prefer the user's existing connected tab. Let the user navigate to the target and confirm ready; open a new tab only if needed and agreed. Avoid automated login/menu traversal, repeated broad snapshots/screenshots, and polling. Perform the agreed targeted checks; use fuller automation only when requested or its scope is agreed.
- Record each check as passed, failed, or unverified, and distinguish user verification from agent verification. Navigation alone is not a pass; do not replace required tests or weaken verification gates.
