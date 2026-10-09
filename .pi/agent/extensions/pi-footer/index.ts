/**
 * pi-footer — minimal custom footer.
 *
 * Replaces @narumitw/pi-statusline. Renders:
 *
 *   line 0: a dim full-width rule, separating whatever's above (chat, or a
 *           belowEditor widget like pi-lens) from the footer
 *   line 1: a full-width highlighted "card" bar (Codex-CLI inspired) —
 *           model · thinking level · cwd(branch) · ctx N%
 *   line 2: extension statuses (MCP / LSP / permission mode), plain, as-is
 *
 * See ~/.pi/agent/patches/README.md for why this exists instead of patching
 * pi-statusline's node_modules source: this is a first-class ctx.ui.setFooter()
 * extension, so it survives `pi update` with no reapply step.
 */
import { sep } from "node:path";
import type {
	ExtensionAPI,
	Theme,
	ThinkingLevel,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type ThemeColorName =
	| "accent"
	| "success"
	| "warning"
	| "error"
	| "muted"
	| "dim"
	| "text";

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const UNBOLD = "\x1b[22m";

// Neutral panel background (tuned neutral gray in this user's gruvbox theme,
// see AGENTS.md) — reused here so the bar reads as a quiet card, not a
// colorful pill.
const BAR_BG = "toolSuccessBg" as const;

const THINKING_COLOR: Record<ThinkingLevel, ThemeColorName> = {
	off: "dim",
	minimal: "muted",
	low: "muted",
	medium: "accent",
	high: "warning",
	xhigh: "error",
	max: "error",
};

function shortenModel(model: string): string {
	return model
		.replace(/^claude-/, "")
		.replace(/^gpt-/, "gpt ")
		.replace(/-20\d{6}$/, "")
		.replace(/-latest$/, "");
}

function formatCwd(cwd: string, home: string | undefined): string {
	if (!home) return cwd;
	if (cwd === home) return "~";
	const prefix = home.endsWith(sep) ? home : `${home}${sep}`;
	return cwd.startsWith(prefix) ? `~${sep}${cwd.slice(prefix.length)}` : cwd;
}

function contextColor(percent: number | null | undefined): ThemeColorName {
	if (percent === null || percent === undefined) return "dim";
	if (percent >= 90) return "error";
	if (percent >= 70) return "warning";
	return "success";
}

interface BarSegment {
	text: string;
	color?: ThemeColorName;
	bold?: boolean;
}

/** Render a full-width single-background bar (Codex-style card), no per-segment pills. */
function renderBar(
	theme: Theme,
	width: number,
	segments: BarSegment[],
): string {
	if (width <= 0) return "";
	let raw = theme.getBgAnsi(BAR_BG) + theme.getFgAnsi("text");
	for (const seg of segments) {
		if (seg.color) raw += theme.getFgAnsi(seg.color);
		if (seg.bold) raw += BOLD;
		raw += seg.text;
		if (seg.bold) raw += UNBOLD;
		if (seg.color) raw += theme.getFgAnsi("text");
	}
	const truncated = truncateToWidth(raw, width, "");
	const pad = Math.max(0, width - visibleWidth(truncated));
	return truncated + " ".repeat(pad) + RESET;
}

export default function pi_footer(pi: ExtensionAPI) {
	let requestRender: (() => void) | undefined;
	const refresh = () => requestRender?.();

	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const branchUnsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose() {
					branchUnsub();
					requestRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					const home = process.env.HOME || process.env.USERPROFILE;
					const model = shortenModel(ctx.model?.id ?? "no-model");
					const thinking = pi.getThinkingLevel();
					const branch = footerData.getGitBranch();
					const cwd = formatCwd(ctx.cwd, home) + (branch ? `(${branch})` : "");
					const usage = ctx.getContextUsage();
					const pct = usage?.percent ?? null;
					const ctxLabel = pct === null ? "ctx ?" : `ctx ${pct.toFixed(0)}%`;

					const rule = width > 0 ? theme.fg("dim", "─".repeat(width)) : "";

					const bar = renderBar(theme, width, [
						{ text: ` ${model} ` },
						{ text: "· " },
						{ text: thinking, color: THINKING_COLOR[thinking], bold: true },
						{ text: " · " },
						{ text: cwd },
						{ text: " · " },
						{ text: ctxLabel, color: contextColor(pct) },
						{ text: " " },
					]);

					const lines = [rule, bar];

					const statuses = footerData.getExtensionStatuses();
					if (statuses.size > 0) {
						const line2 = Array.from(statuses.entries())
							.sort(([a], [b]) => a.localeCompare(b))
							.map(([, text]) => text)
							.join(theme.fg("dim", " · "));
						lines.push(truncateToWidth(line2, width, theme.fg("dim", "…")));
					}
					return lines;
				},
			};
		});
	});

	pi.on("session_shutdown", (_event, ctx) => {
		ctx.ui.setFooter(undefined);
		requestRender = undefined;
	});

	pi.on("model_select", refresh);
	pi.on("thinking_level_select", refresh);
	pi.on("agent_start", refresh);
	pi.on("agent_end", refresh);
	pi.on("turn_start", refresh);
	pi.on("turn_end", refresh);
}
