---@type LazySpec
return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  config = function(_, opts)
    require("fff").setup(opts)

    -- Keep the picker fully text-based: fff has no icon toggle and pulls
    -- file-type glyphs from mini.icons / nvim-web-devicons when available, so
    -- neutralize its icon provider to render plain filenames only.
    local icons = require("fff.file_picker.icons")
    -- Intentionally override fff's icon provider with no-op stubs.
    ---@diagnostic disable-next-line: duplicate-set-field
    icons.get_icon = function()
      return nil, nil
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    icons.get_directory_icon = function()
      return nil, nil
    end
  end,
  opts = {
    -- Plain-text prompt instead of the default emoji glyph.
    prompt = "> ",
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
      "<leader>sg",
      function()
        require("fff").live_grep()
      end,
      desc = "[S]earch by [G]rep",
    },
    {
      "<leader>sz",
      function()
        require("fff").live_grep({
          grep = {
            modes = { "fuzzy", "plain" },
          },
        })
      end,
      desc = "[S]earch with fu[Z]zy grep",
    },
    {
      "<leader>sw",
      function()
        require("fff").live_grep({ query = vim.fn.expand("<cword>") })
      end,
      desc = "[S]earch current [W]ord",
    },
    {
      "<leader>sn",
      function()
        require("fff").find_files_in_dir(vim.fn.stdpath("config"))
      end,
      desc = "[S]earch [N]eovim files",
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
