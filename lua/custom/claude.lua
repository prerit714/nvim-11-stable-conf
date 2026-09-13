-- Lazygit-style floating terminal for the Claude Code TUI.
--
-- Thin wrapper over the shared float-terminal launcher (see float_term.lua):
-- opens `claude` in a centered, resize-aware float (bound to <leader>C in
-- lua/custom/plugins/claude.lua). Reuses a single terminal buffer across
-- toggles and auto-closes when the process exits.
---@type FloatTerm
return require("custom.float_term").create({
  command = "claude",
  name = "ClaudeFloat",
})
