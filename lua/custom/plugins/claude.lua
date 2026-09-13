-- Local (dependency-free) lazy spec that lazy-loads the Claude float on
-- <leader>3, mirroring the opencode launcher on <leader>A.
---@type LazySpec
return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/claude-lazy",
  name = "claude",
  keys = {
    {
      "<leader>3",
      function()
        require("custom.claude").toggle()
      end,
      desc = "Claude (TUI)",
    },
  },
}
