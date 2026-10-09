# Local node_modules patches

Some customizations live in **installed package source** under
`~/.pi/agent/npm/node_modules/`. Those are wiped whenever the package is
updated or reinstalled (`pi update`, etc.). This folder lets you re-apply them.

## Windows-only workaround

This fixes the `pi-patty-bg-tasks` extension, not Pi itself. It selects Git Bash
on Windows, disables Windows process detachment (avoiding stray consoles), hides
child windows, and handles spawn errors safely. The reference targets **1.1.6**,
which is pinned in the shared settings. Do not apply it on Mac/Linux.

Keep this until an unpatched replacement has passed isolated Windows shell and
background-job checks. Package metadata alone does not prove the fix is obsolete.
The patched package's MIT license is retained beside the reference source.

## What's patched

| Package | File | Change |
| --- | --- | --- |
| `pi-patty-bg-tasks` | `src/spawn.ts` | Windows bash fix: `resolveShell()` + `detached:!isWin` + `windowsHide` |

`refs/` holds known-good copies of each patched file.

## Re-apply after an update

```bash
bash ~/.pi/agent/patches/apply-patches.sh --check   # report only, no writes
bash ~/.pi/agent/patches/apply-patches.sh           # apply (backs up as *.prepatch.bak)
```

Then restart pi.

The script is idempotent: it skips files that already contain the patch marker,
backs up the target before overwriting, and **refuses to apply when the installed
package version differs** from the version each ref was captured against. If you
see a version warning, diff the new upstream file against `refs/`, re-apply the
customization to the new version, and re-capture it before trusting the copy:

```bash
# after reviewing/re-patching the installed file, refresh the ref:
cp "~/.pi/agent/npm/node_modules/<pkg>/src/<file>.ts" \
   "~/.pi/agent/patches/refs/<pkg>/src/<file>.ts"
```

## NOT patched here (safe user files, survive updates)

- `~/.pi/agent/themes/gruvbox-{light,dark}.json`
- `~/.pi/agent/settings.json`
- `~/.pi/agent/extensions/pi-footer/index.ts` — custom footer extension
  (model · thinking · cwd(branch) · ctx% + MCP/LSP/permission status line).
  Auto-discovered from `~/.pi/agent/extensions/`; a first-class extension, not
  a node_modules patch — nothing to reapply after updates.
