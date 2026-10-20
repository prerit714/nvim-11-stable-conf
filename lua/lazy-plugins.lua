require("lazy").setup({
  {
    "NMAC427/guess-indent.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      filetype_exclude = { "netrw", "tutor", "html" },
    },
  },

  require("kickstart.plugins.gitsigns"),

  require("kickstart.plugins.which-key"),

  require("kickstart.plugins.lspconfig"),

  require("kickstart.plugins.conform"),

  require("kickstart.plugins.blink-cmp"),

  require("kickstart.plugins.tokyonight"),

  require("kickstart.plugins.todo-comments"),

  require("kickstart.plugins.mini"),

  require("kickstart.plugins.treesitter"),

  require("kickstart.plugins.indent_line"),
  require("kickstart.plugins.lint"),
  require("kickstart.plugins.autopairs"),

  { import = "custom.plugins" },
}, {
  performance = {
    rtp = {
      -- Unused runtime plugins; oil.nvim replaces netrw as the file explorer.
      disabled_plugins = {
        "gzip",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  ui = {
    icons = {
      cmd = "cmd ",
      config = "cfg ",
      event = "evt ",
      ft = "ft ",
      init = "init ",
      import = "imp ",
      keys = "keys ",
      lazy = "lazy ",
      loaded = "*",
      not_loaded = "o",
      plugin = "plug ",
      runtime = "rt ",
      require = "req ",
      source = "src ",
      start = "start ",
      task = "task ",
      list = { "-", "-", "-", "-" },
    },
  },
})
