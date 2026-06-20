return {
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require("tokyonight").setup({
        transparent = true,
        styles = {
          comments = { italic = false },
        },
      })

      vim.cmd.colorscheme("tokyonight-night")
    end,
  },
}
