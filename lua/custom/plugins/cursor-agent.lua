-- Local (dependency-free) lazy spec that lazy-loads the Cursor agent float on
-- <leader>1, mirroring how lazygit gets its own launcher key.
---@type LazySpec
return {
  dir = vim.fn.stdpath("config"),
  name = "cursor-agent",
  keys = {
    {
      "<leader>1",
      function()
        require("custom.cursor_agent").toggle()
      end,
      desc = "Cursor [A]gent (TUI)",
    },
  },
}
