return {
  "tpope/vim-fugitive",
  cmd = {
    "G",
    "Git",
    "Gdiffsplit",
    "Gvdiffsplit",
    "Gread",
    "Gwrite",
    "Gedit",
    "Gclog",
    "Glog",
  },
  keys = {
    { "<leader>gs", "<cmd>Git<cr>", desc = "[G]it [S]tatus" },
    { "<leader>gb", "<cmd>Git blame<cr>", desc = "[G]it [B]lame" },
    { "<leader>gd", "<cmd>Gdiffsplit<cr>", desc = "[G]it [D]iff split" },
    { "<leader>gl", "<cmd>Git log<cr>", desc = "[G]it [L]og" },
  },
}
