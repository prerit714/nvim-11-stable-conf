-- Local (dependency-free) lazy spec that lazy-loads the Codex float on
-- <leader>c, mirroring the cursor-agent launcher on <leader>a.
---@type LazySpec
return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/codex-lazy",
  name = "codex",
  keys = {
    {
      "<leader>c",
      function()
        require("custom.codex").toggle()
      end,
      desc = "Codex (TUI)",
    },
  },
}
