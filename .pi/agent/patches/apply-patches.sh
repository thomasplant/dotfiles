#!/usr/bin/env bash
#
# Re-apply local pi customizations that live in installed package source under
# node_modules (wiped by `pi update` / reinstall). Idempotent and safe:
#   - skips a file if the patch marker is already present,
#   - backs up the target (<file>.prepatch.bak) before overwriting,
#   - refuses to apply if the installed package version differs from what the
#     ref was captured against (upstream may have changed the file).
#
# Usage:
#   bash ~/.pi/agent/patches/apply-patches.sh          # apply
#   bash ~/.pi/agent/patches/apply-patches.sh --check   # report only, no writes
#
set -uo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NM="$AGENT_DIR/npm/node_modules"
REFS="$AGENT_DIR/patches/refs"
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

# target-relpath | package-dir | captured-version | marker-string
PATCHES=(
	"pi-patty-bg-tasks/src/spawn.ts|pi-patty-bg-tasks|1.1.6|resolveShell"
)

applied=0
skipped=0
warned=0
missing=0
drifted=0

pkg_version() {
	# Read version straight from package.json (avoids node's Git-bash path issues).
	grep -m1 '"version"' "$1/package.json" 2>/dev/null |
		sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' ||
		echo "?"
}

for entry in "${PATCHES[@]}"; do
	IFS='|' read -r rel pkg capver marker <<<"$entry"
	target="$NM/$rel"
	ref="$REFS/$rel"

	if [ ! -f "$ref" ]; then
		echo "MISSING REF   $rel  (no reference copy at $ref)"
		missing=$((missing + 1))
		continue
	fi
	if [ ! -f "$target" ]; then
		echo "NO TARGET     $rel  (package not installed?)"
		missing=$((missing + 1))
		continue
	fi

	curver="$(pkg_version "$NM/$pkg")"
	version_match=1
	if [ "$curver" != "$capver" ]; then
		echo "⚠ VERSION      $pkg installed=$curver captured=$capver — review $rel before trusting the copy"
		warned=$((warned + 1))
		version_match=0
	fi

	if grep -q "$marker" "$target"; then
		echo "OK (present)  $rel"
		skipped=$((skipped + 1))
		continue
	fi

	if [ "$version_match" = "0" ]; then
		echo "SKIP (drift)  $rel"
		drifted=$((drifted + 1))
		continue
	fi

	if [ "$CHECK_ONLY" = "1" ]; then
		echo "WOULD APPLY   $rel"
		applied=$((applied + 1))
		continue
	fi

	cp "$target" "$target.prepatch.bak"
	cp "$ref" "$target"
	echo "APPLIED       $rel  (backup: $rel.prepatch.bak)"
	applied=$((applied + 1))
done

echo "---"
echo "applied/would-apply=$applied  already-present=$skipped  drift-skipped=$drifted  version-warnings=$warned  missing=$missing"
[ "$CHECK_ONLY" = "1" ] && echo "(check mode: no files written)"
echo "Restart pi after applying."
