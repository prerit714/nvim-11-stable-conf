-- Task runner / job management. Lives under the free <leader>O prefix so it
-- never collides with <leader>o (Oil). Overseer's own task-list window keeps
-- its built-in buffer-local keys (including q), so there are no global clashes.
---@type LazySpec
return {
  "stevearc/overseer.nvim",
  cmd = {
    "OverseerToggle",
    "OverseerOpen",
    "OverseerClose",
    "OverseerRun",
    "OverseerRunCmd",
    "OverseerQuickAction",
    "OverseerInfo",
    "OverseerBuild",
    "OverseerClearCache",
  },
  opts = {},
  keys = {
    { "<leader>Ot", "<cmd>OverseerToggle<cr>", desc = "[O]verseer [t]oggle" },
    { "<leader>Or", "<cmd>OverseerRun<cr>", desc = "[O]verseer [r]un" },
    {
      "<leader>OR",
      "<cmd>OverseerRunCmd<cr>",
      desc = "[O]verseer [R]un command",
    },
    {
      "<leader>Oa",
      "<cmd>OverseerQuickAction<cr>",
      desc = "[O]verseer quick [a]ction",
    },
    { "<leader>Oi", "<cmd>OverseerInfo<cr>", desc = "[O]verseer [i]nfo" },
    { "<leader>Ob", "<cmd>OverseerBuild<cr>", desc = "[O]verseer [b]uild" },
    {
      "<leader>Oc",
      "<cmd>OverseerClearCache<cr>",
      desc = "[O]verseer [c]lear cache",
    },
  },
}
