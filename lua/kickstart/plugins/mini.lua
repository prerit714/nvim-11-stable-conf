---@type LazySpec
return {
  {
    "echasnovski/mini.nvim",
    config = function()
      require("mini.ai").setup({ n_lines = 500 })

      require("mini.surround").setup()

      -- Start screen (auto-opens on `nvim` / Neovide with no file args).
      -- Pinned project dirs come first; see lua/custom/pinned_dirs.lua.
      local starter = require("mini.starter")
      local pinned_dirs = require("custom.pinned_dirs")
      starter.setup({
        header = function()
          return "Neovim\n" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
        end,
        items = {
          pinned_dirs.starter_items(),
          starter.sections.recent_files(8, false, true),
          {
            section = "Actions",
            name = "Find file",
            action = function()
              require("fff").find_files()
            end,
          },
          { section = "Actions", name = "Oil (cwd)", action = "Oil" },
          {
            section = "Actions",
            name = "Pin/unpin project",
            action = pinned_dirs.toggle,
          },
          starter.sections.builtin_actions(),
        },
        footer = "<leader>pp pin/unpin   <leader>pl pinned dirs   "
          .. "<leader>ps start screen",
        content_hooks = {
          starter.gen_hook.adding_bullet("- "),
          starter.gen_hook.aligning("center", "center"),
        },
      })

      local statusline = require("mini.statusline")

      statusline.setup({
        use_icons = false,
        content = {
          active = function()
            local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
            local git = statusline.section_git({ trunc_width = 40 })
            local diff = statusline.section_diff({ trunc_width = 75 })
            local diagnostics =
              statusline.section_diagnostics({ trunc_width = 75 })
            local lsp = statusline.section_lsp({ trunc_width = 75 })
            local filename = statusline.section_filename({ trunc_width = 140 })
            local fileinfo = statusline.section_fileinfo({ trunc_width = 120 })
            local search = statusline.section_searchcount({ trunc_width = 75 })
            -- Always show the wall-clock time in IST (UTC+05:30, no DST),
            -- regardless of the machine's local timezone.
            local ist_offset = 5 * 3600 + 30 * 60
            local clock = os.date("!%H:%M:%S", os.time() + ist_offset) .. " IST"
            -- Soonest running timebox; only read once the module is loaded
            -- (i.e. a timer was started), so startup never pays for it.
            local timebox = package.loaded["custom.timebox"]
                and package.loaded["custom.timebox"].statusline()
              or ""

            return statusline.combine_groups({
              { hl = mode_hl, strings = { mode } },
              {
                hl = "MiniStatuslineDevinfo",
                strings = { git, diff, diagnostics, lsp },
              },
              "%<",
              { hl = "MiniStatuslineFilename", strings = { filename } },
              "%=",
              { hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
              {
                hl = mode_hl,
                strings = { search, "%2l:%-2v", timebox, clock },
              },
            })
          end,
        },
      })

      -- Redraw the statusline once per second so the IST clock stays current.
      local timer = assert((vim.uv or vim.loop).new_timer())
      timer:start(
        1000,
        1000,
        vim.schedule_wrap(function()
          pcall(function()
            vim.cmd("redrawstatus")
          end)
        end)
      )
    end,
  },
}
