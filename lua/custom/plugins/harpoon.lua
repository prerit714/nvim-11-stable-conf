return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  opts = {
    menu = {
      width = vim.api.nvim_win_get_width(0) - 4,
    },
    settings = {
      save_on_toggle = true,
    },
  },
  keys = function()
    local keys = {
      {
        "<leader>.",
        function()
          require("harpoon"):list():add()
        end,
        desc = "[Harpoon] Tag current buffer",
      },
      {
        "<leader>h",
        function()
          local harpoon = require("harpoon")
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = "[Harpoon] Show Quick Menu",
      },
      {
        "H",
        function()
          require("harpoon"):list():prev({ ui_nav_wrap = true })
        end,
        desc = "[Harpoon] Goto previous buffer",
      },
      {
        "L",
        function()
          require("harpoon"):list():next({ ui_nav_wrap = true })
        end,
        desc = "[Harpoon] Goto next buffer",
      },
    }

    for i = 1, 5 do
      table.insert(keys, {
        "<leader>" .. i,
        function()
          require("harpoon"):list():select(i)
        end,
        desc = "[Harpoon] Go to buffer" .. i,
      })
    end
    return keys
  end,
}
