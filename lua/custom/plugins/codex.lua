-- Local (dependency-free) lazy spec that lazy-loads the Codex float on
-- <leader>4, mirroring the cursor-agent launcher on <leader>a.
---@type LazySpec
return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/codex-lazy",
  name = "codex",
  keys = {
    {
      "<leader>4",
      function()
        require("custom.codex").toggle()
      end,
      desc = "Codex (TUI)",
    },
  },
}
