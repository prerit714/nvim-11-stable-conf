-- Local (dependency-free) lazy spec that lazy-loads the opencode float on
-- <leader>A, mirroring the cursor-agent launcher on <leader>a.
---@type LazySpec
return {
  -- Distinct dir from the cursor-agent local spec so lazy.nvim treats this as
  -- its own plugin instead of merging them (lazy keys plugins by `dir`).
  dir = vim.fn.stdpath("config") .. "/lua/custom",
  name = "opencode",
  keys = {
    {
      "<leader>A",
      function()
        require("custom.opencode").toggle()
      end,
      desc = "opencode (TUI)",
    },
  },
}
