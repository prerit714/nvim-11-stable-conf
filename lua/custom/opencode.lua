-- Lazygit-style floating terminal for the opencode TUI.
--
-- Thin wrapper over the shared float-terminal launcher (see float_term.lua):
-- opens `opencode` in a centered, resize-aware float (bound to <leader>A in
-- lua/custom/plugins/opencode.lua). Reuses a single terminal buffer across
-- toggles and auto-closes when the process exits.
---@type FloatTerm
return require("custom.float_term").create({
  command = "opencode",
  name = "OpenCodeFloat",
})
