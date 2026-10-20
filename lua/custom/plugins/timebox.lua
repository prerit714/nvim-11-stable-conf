-- Local (dependency-free) lazy spec for timeboxing countdown timers. Loads on
-- `:Timebox` or any <leader>T key; the command is created in `config`.

---Build a key handler that calls a function on the timebox module.
---@param fn string Name of the `custom.timebox` function to call.
---@param ... any Arguments forwarded to it.
---@return fun(): nil
local function call(fn, ...)
  local args = { ... }
  return function()
    require("custom.timebox")[fn](unpack(args))
  end
end

---@type LazySpec
return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/timebox-lazy",
  name = "timebox",
  cmd = "Timebox",
  keys = {
    { "<leader>Ts", call("prompt_start"), desc = "Timebox: [S]tart (prompt)" },
    { "<leader>Tl", call("list"), desc = "Timebox: [L]ist running" },
    { "<leader>Tc", call("pick_cancel"), desc = "Timebox: [C]ancel one" },
    { "<leader>T5", call("start", 5), desc = "Timebox: start 5 min" },
    { "<leader>T1", call("start", 15), desc = "Timebox: start 15 min" },
    { "<leader>T2", call("start", 25), desc = "Timebox: start 25 min" },
  },
  config = function()
    require("custom.timebox").setup()
  end,
}
