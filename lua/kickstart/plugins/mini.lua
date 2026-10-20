---@type LazySpec
return {
  {
    "echasnovski/mini.nvim",
    config = function()
      require("mini.ai").setup({ n_lines = 500 })

      require("mini.surround").setup()

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
                strings = { search, "%2l:%-2v", clock },
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
