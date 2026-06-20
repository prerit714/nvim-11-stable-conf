return {
  "stevearc/oil.nvim",
  opts = {
    default_file_explorer = true,
    view_options = {
      show_hidden = true,
    },
  },
  keys = {
    { "<leader>o", "<cmd>Oil<cr>", desc = "Open Oil file explorer" },
  },
}
