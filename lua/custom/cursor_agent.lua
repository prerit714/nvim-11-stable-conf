-- Lazygit-style floating terminal for the Cursor agent TUI.
--
-- Thin wrapper over the shared float-terminal launcher (see float_term.lua):
-- opens `cursor-agent` in a centered, resize-aware float (bound to <leader>a in
-- lua/custom/plugins/cursor-agent.lua). Reuses a single terminal buffer across
-- toggles and auto-closes when the process exits.
---@type FloatTerm
return require("custom.float_term").create({
  command = "cursor-agent",
  name = "CursorAgentFloat",
})
