---@type LazySpec
return {
  "MagicDuck/grug-far.nvim",
  config = function()
    require("grug-far").setup({})
  end,
  keys = {
    {
      "<leader>sR",
      function()
        require("grug-far").open()
      end,
      mode = { "n" },
      desc = "[S]earch and [R]eplace (grug-far)",
    },
    {
      "<leader>sR",
      function()
        require("grug-far").with_visual_selection()
      end,
      mode = { "v" },
      desc = "[S]earch and [R]eplace selection (grug-far)",
    },
  },
}
