-- Local (dependency-free) lazy spec that lazy-loads the Cursor agent float on
-- <leader>a, mirroring how lazygit gets its own launcher key.
return {
  dir = vim.fn.stdpath("config"),
  name = "cursor-agent",
  keys = {
    {
      "<leader>a",
      function()
        require("custom.cursor_agent").toggle()
      end,
      desc = "Cursor [A]gent (TUI)",
    },
  },
}
