-- Local (dependency-free) lazy spec for pinned project directories
-- (lua/custom/pinned_dirs.lua). The auto-cd autocmd is installed from `init`
-- so it works from startup; the start screen itself is set up in mini.lua.

---Build a key handler that calls a function on the pinned_dirs module.
---@param fn string Name of the `custom.pinned_dirs` function to call.
---@return fun(): nil
local function call(fn)
  return function()
    require("custom.pinned_dirs")[fn]()
  end
end

---@type LazySpec
return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/pinned-dirs-lazy",
  name = "pinned-dirs",
  init = function()
    require("custom.pinned_dirs").setup()
  end,
  keys = {
    { "<leader>pp", call("toggle"), desc = "Pin: toggle current [P]roject" },
    { "<leader>pl", call("pick"), desc = "Pin: [L]ist pinned dirs (cd)" },
    {
      "<leader>ps",
      function()
        require("mini.starter").open()
      end,
      desc = "Pin: open [S]tart screen",
    },
  },
}
