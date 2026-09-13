-- Lazygit-style floating terminal for the Codex TUI.
--
-- Thin wrapper over the shared float-terminal launcher (see float_term.lua):
-- opens `codex` in a centered, resize-aware float (bound to <leader>c in
-- lua/custom/plugins/codex.lua). Reuses a single terminal buffer across
-- toggles and auto-closes when the process exits.
---@type FloatTerm
return require("custom.float_term").create({
  command = "codex",
  name = "CodexFloat",
})
