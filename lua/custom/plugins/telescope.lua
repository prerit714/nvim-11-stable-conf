-- fff.nvim is the primary picker for file-oriented operations (find files,
-- live grep, buffers). Telescope is the fallback for everything fff does not
-- cover: help tags, keymaps, diagnostics, resume, in-file/open-file search,
-- LSP pickers (see lspconfig.lua) and `vim.ui.select` (telescope-ui-select).
---@type LazySpec
return {
  {
    "nvim-telescope/telescope.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
      { "nvim-telescope/telescope-ui-select.nvim" },
      { "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
    },
    -- Declared as lazy keys so they work before VeryLazy fires and load
    -- telescope on first use.
    keys = {
      {
        "<leader>sh",
        function()
          require("telescope.builtin").help_tags()
        end,
        desc = "[S]earch [H]elp",
      },
      {
        "<leader>sk",
        function()
          require("telescope.builtin").keymaps()
        end,
        desc = "[S]earch [K]eymaps",
      },
      {
        "<leader>ss",
        function()
          require("telescope.builtin").builtin()
        end,
        desc = "[S]earch [S]elect Telescope",
      },
      {
        "<leader>sd",
        function()
          require("telescope.builtin").diagnostics()
        end,
        desc = "[S]earch [D]iagnostics",
      },
      {
        "<leader>s.",
        function()
          require("telescope.builtin").oldfiles()
        end,
        desc = "[S]earch Recent Files",
      },
      {
        "<leader>sr",
        function()
          require("telescope.builtin").resume()
        end,
        desc = "[S]earch [R]esume",
      },
      {
        "<leader>/",
        function()
          require("telescope.builtin").current_buffer_fuzzy_find(
            require("telescope.themes").get_dropdown({
              winblend = 10,
              previewer = false,
            })
          )
        end,
        desc = "[/] Fuzzily search in current buffer",
      },
      {
        "<leader>s/",
        function()
          require("telescope.builtin").live_grep({
            grep_open_files = true,
            prompt_title = "Live Grep in Open Files",
          })
        end,
        desc = "[S]earch [/] in Open Files",
      },
    },
    config = function()
      require("telescope").setup({
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown(),
          },
        },
        defaults = {
          file_ignore_patterns = {
            "^.git/",
            "^node_modules/",
            "^dist/",
            "^build/",
            "^.DS_Store",
            "^-lock.json",
            "^.out",
          },
          hidden = true,
        },
        pickers = {
          find_files = {
            hidden = true,
          },
        },
      })

      pcall(require("telescope").load_extension, "fzf")
      pcall(require("telescope").load_extension, "ui-select")
    end,
  },
}
