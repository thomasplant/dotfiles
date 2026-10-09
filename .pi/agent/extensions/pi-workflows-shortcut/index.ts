import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Open the existing navigator without changing the editor or invoking a model. */
export default function workflowsShortcut(pi: ExtensionAPI) {
  pi.registerShortcut("ctrl+alt+w", {
    description: "Open workflows navigator",
    handler: async (ctx) => {
      if (ctx.mode !== "tui") return;
      const available = pi.getCommands().some(
        (command) => command.name === "workflows" && command.source === "extension",
      );
      if (!available) {
        ctx.ui.notify("The /workflows command is unavailable. Check that pi-dynamic-workflows is enabled.", "warning");
        return;
      }
      // Opt into command dispatch: without this flag the text would reach the LLM.
      // Extension commands dispatch before streaming-message queue handling.
      pi.sendUserMessage("/workflows", {
        expandPromptTemplates: true,
        deliverAs: "followUp",
      });
    },
  });
}
