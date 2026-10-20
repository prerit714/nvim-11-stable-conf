-- loki.nvim: read-only rendered markdown view in the external `loki` TUI.
-- The plugin ships the Go source and a build.lua that compiles `bin/loki`
-- (lazy.nvim runs it on install/update; needs Go). A `loki` on PATH, or
-- vim.g.loki_cmd, takes precedence over that binary.
-- <leader>M is buffer-local to markdown buffers (lazy `ft` keys); `:Loki [file]`
-- works anywhere. <leader>m* is avoided: <leader>m is harpoon's quick menu and
-- a longer map under it would make that key wait for 'timeoutlen'.
---@type LazySpec
return {
  "prerit714/loki.nvim",
  cmd = "Loki",
  keys = {
    {
      "<leader>M",
      function()
        require("loki").open()
      end,
      ft = "markdown",
      desc = "[M]arkdown view (loki)",
    },
  },
}
