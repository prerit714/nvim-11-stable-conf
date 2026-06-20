return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  config = function(_, opts)
    require("fff").setup(opts)
  end,
  opts = {
    layout = {
      height = 0.8,
      width = 0.8,
      prompt_position = "bottom",
      preview_position = "right",
      preview_size = 0.5,
    },
    preview = {
      enabled = true,
      line_numbers = true,
    },
    frecency = {
      enabled = true,
    },
    keymaps = {
      close = "<Esc>",
      select = "<CR>",
      select_split = "<C-s>",
      select_vsplit = "<C-v>",
      select_tab = "<C-t>",
      move_up = { "<Up>", "<C-p>" },
      move_down = { "<Down>", "<C-n>" },
      preview_scroll_up = "<C-u>",
      preview_scroll_down = "<C-d>",
      toggle_select = "<Tab>",
      send_to_quickfix = "<C-q>",
    },
  },
  lazy = false,
  keys = {
    {
      "<leader>sf",
      function()
        require("fff").find_files()
      end,
      desc = "[S]earch [F]iles",
    },
    {
      "ff",
      function()
        require("fff").find_files()
      end,
      desc = "FFFind files",
    },
    {
      "<leader>sg",
      function()
        require("fff").live_grep()
      end,
      desc = "[S]earch by [G]rep",
    },
    {
      "fg",
      function()
        require("fff").live_grep()
      end,
      desc = "LiFFFe grep",
    },
    {
      "fz",
      function()
        require("fff").live_grep({
          grep = {
            modes = { "fuzzy", "plain" },
          },
        })
      end,
      desc = "Live fffuzy grep",
    },
    {
      "<leader>sw",
      function()
        require("fff").live_grep({ query = vim.fn.expand("<cword>") })
      end,
      desc = "[S]earch current [W]ord",
    },
    {
      "fc",
      function()
        require("fff").live_grep({ query = vim.fn.expand("<cword>") })
      end,
      desc = "Search current word",
    },
    {
      "<leader>sn",
      function()
        require("fff").find_files_in_dir(vim.fn.stdpath("config"))
      end,
      desc = "[S]earch [N]eovim files",
    },
    {
      "<leader>s.",
      function()
        require("fff").find_files()
      end,
      desc = "[S]earch Recent Files",
    },
    {
      "<leader><leader>",
      function()
        local buffers = vim.fn.getbufinfo({ buflisted = 1 })
        local items = {}
        for _, buf in ipairs(buffers) do
          if buf.name ~= "" then
            table.insert(items, buf.name)
          end
        end
        vim.ui.select(items, {
          prompt = "Select Buffer:",
        }, function(choice)
          if choice then
            vim.cmd("buffer " .. vim.fn.fnameescape(choice))
          end
        end)
      end,
      desc = "[ ] Find existing buffers",
    },
  },
}
