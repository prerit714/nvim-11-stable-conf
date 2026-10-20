-- vim-fugitive plus merge-conflict tooling (lua/custom/git_conflict.lua).
--
-- Conflict workflow:
--   <leader>gq  load every conflict in the repo into the quickfix list
--   <leader>gm  3-way split: ours (//2) | working copy | theirs (//3)
--   ]x / [x     next / previous conflict in the buffer
--   <leader>go / gt / ga / gx  take ours / theirs / both / none for the
--               conflict under the cursor (works with or without the split)
--   <leader>gw  stage the file (marks it resolved), then :only to exit
---@type LazySpec
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
  init = function()
    -- Conflict highlighting must be active before fugitive loads.
    require("custom.git_conflict").setup()
  end,
  keys = {
    { "<leader>gs", "<cmd>Git<cr>", desc = "[G]it [S]tatus" },
    { "<leader>gb", "<cmd>Git blame<cr>", desc = "[G]it [B]lame" },
    { "<leader>gd", "<cmd>Gvdiffsplit<cr>", desc = "[G]it [D]iff split" },
    { "<leader>gl", "<cmd>Git log<cr>", desc = "[G]it [L]og" },
    {
      "<leader>gm",
      "<cmd>Gvdiffsplit!<cr>",
      desc = "[G]it [M]erge: 3-way split (ours | result | theirs)",
    },
    {
      "<leader>gq",
      "<cmd>Git mergetool<cr>",
      desc = "[G]it conflicts to [Q]uickfix",
    },
    {
      "<leader>gw",
      "<cmd>Gwrite<cr>",
      desc = "[G]it [W]rite: stage file (mark resolved)",
    },
    {
      "<leader>go",
      function()
        require("custom.git_conflict").resolve("ours")
      end,
      desc = "[G]it conflict: take [O]urs",
    },
    {
      "<leader>gt",
      function()
        require("custom.git_conflict").resolve("theirs")
      end,
      desc = "[G]it conflict: take [T]heirs",
    },
    {
      "<leader>ga",
      function()
        require("custom.git_conflict").resolve("both")
      end,
      desc = "[G]it conflict: take [A]ll (ours then theirs)",
    },
    {
      "<leader>gx",
      function()
        require("custom.git_conflict").resolve("none")
      end,
      desc = "[G]it conflict: delete both sides",
    },
    {
      "]x",
      function()
        require("custom.git_conflict").jump(1)
      end,
      desc = "Next git conflict",
    },
    {
      "[x",
      function()
        require("custom.git_conflict").jump(-1)
      end,
      desc = "Previous git conflict",
    },
  },
}
