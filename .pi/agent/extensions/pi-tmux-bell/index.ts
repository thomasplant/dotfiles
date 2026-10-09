/**
 * pi-tmux-bell — ring the terminal bell when Pi needs you.
 *
 * Inside tmux, a bell from a window you're not looking at sets that window's
 * bell flag, which ~/.config/tmux/tmux.conf shows as a ✔ until you visit it.
 * (The "working" dot comes from Pi's OSC 9;4 progress setting, not from here.)
 *
 * Rings only inside tmux, where tmux turns it into a silent status-bar marker
 * (bell-action none); outside tmux it would reach the terminal as a real beep.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function bell(): void {
	if (process.env.TMUX) process.stdout.write("\x07");
}

export default function piTmuxBell(pi: ExtensionAPI) {
	// Pi has fully finished: no retry, compaction or queued work will follow.
	// Skip runs you aborted yourself (Escape) - you're already looking.
	pi.on("agent_settled", (event) => {
		if (!event.aborted) bell();
	});

	// Pi is blocked on a question (e.g. a permission prompt).
	pi.on("ui_prompt_start", () => {
		bell();
	});
}
