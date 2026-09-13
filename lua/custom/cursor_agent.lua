-- Lazygit-style floating terminal for the Cursor agent TUI.
--
-- Opens `cursor-agent` in a centered floating window, reuses a single terminal
-- buffer across toggles, and closes the window automatically when the process
-- exits. Only buffer-local maps are set on the agent terminal so the global
-- `q` (macro record) and other keys are never shadowed elsewhere.

---@class CursorAgent
---@field command string Executable launched inside the float.
local M = {}

-- Command run inside the float. Overridable if the binary is named differently.
M.command = "cursor-agent"

---Runtime handles for the single reused agent session.
---@class CursorAgentState
---@field buf integer? Terminal buffer handle, or nil when none exists.
---@field win integer? Float window handle, or nil when hidden/closed.
---@field job integer? termopen job id, or nil when not running.
local state = {
  buf = nil,
  win = nil,
  job = nil,
}

---@return boolean valid True when the terminal buffer handle is live.
local function buf_valid()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

---@return boolean valid True when the float window handle is live.
local function win_valid()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- Geometry only (relative/size/position), recomputed from the current editor
-- dimensions so it stays valid across live resizes.
---@return vim.api.keyset.win_config geometry Centered ~90% editor-relative rect.
local function float_geometry()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  return {
    relative = "editor",
    width = math.max(width, 1),
    height = math.max(height, 1),
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
  }
end

---Full window config for `nvim_open_win`: geometry plus chrome (style/border).
---@return vim.api.keyset.win_config config
local function float_config()
  local config = float_geometry()
  config.style = "minimal"
  config.border = (vim.o.winborder ~= nil and vim.o.winborder ~= "")
      and vim.o.winborder
    or "single"
  return config
end

-- Keep the float centered and sized to the editor when it (or the GUI, e.g.
-- Neovide) is resized. termopen reflows the terminal contents automatically
-- once the window geometry changes.
---@return nil
function M.on_resize()
  if win_valid() then
    vim.api.nvim_win_set_config(state.win, float_geometry())
  end
end

---Register the buffer-local maps on the agent terminal buffer only.
---@param buf integer Terminal buffer handle to attach the maps to.
---@return nil
local function set_buffer_keymaps(buf)
  ---@type vim.keymap.set.Opts
  local opts = { buffer = buf, silent = true, nowait = true }

  -- Normal-mode `q` hides the float (buffer-local only, so global macro `q`
  -- stays intact everywhere else).
  vim.keymap.set("n", "q", function()
    M.hide()
  end, vim.tbl_extend("force", opts, { desc = "Close Cursor Agent float" }))

  -- Match the existing terminal-escape convention from lua/keymaps.lua.
  vim.keymap.set(
    "t",
    "<Esc><Esc>",
    "<C-\\><C-n>",
    vim.tbl_extend("force", opts, { desc = "Leave terminal mode" })
  )
  vim.keymap.set(
    "t",
    "<C-\\><C-n>",
    "<C-\\><C-n>",
    vim.tbl_extend("force", opts, { desc = "Leave terminal mode" })
  )
end

---Close (hide) the float, keeping the terminal session/buffer alive.
---@return nil
function M.hide()
  if win_valid() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  -- The agent TUI paints the whole float; force a redraw so no stale cells are
  -- left behind on the window we return to.
  vim.schedule(function()
    pcall(function()
      vim.cmd("redraw!")
    end)
  end)
end

---Open the float over the current (or reused) agent buffer.
---@return nil
local function open_window()
  state.win = vim.api.nvim_open_win(state.buf, true, float_config())
  vim.wo[state.win].winfixbuf = true
end

---Launch (or re-show) the Cursor agent float, starting the CLI if needed.
---@return nil
function M.open()
  if vim.fn.executable(M.command) ~= 1 then
    vim.notify(
      string.format(
        "cursor_agent: '%s' is not on PATH. Install the Cursor CLI first.",
        M.command
      ),
      vim.log.levels.ERROR
    )
    return
  end

  if buf_valid() then
    -- Reuse the existing terminal buffer/session.
    open_window()
    vim.cmd("startinsert")
    return
  end

  -- Fresh terminal buffer running the agent.
  state.buf = vim.api.nvim_create_buf(false, true)
  open_window()

  ---@diagnostic disable-next-line: deprecated
  state.job = vim.fn.termopen(M.command, {
    ---@return nil
    on_exit = function()
      state.job = nil
      -- Drop the buffer so the next toggle starts a clean session.
      if buf_valid() then
        vim.api.nvim_buf_delete(state.buf, { force = true })
      end
      state.buf = nil
      M.hide()
    end,
  })

  set_buffer_keymaps(state.buf)
  vim.cmd("startinsert")
end

---Toggle the float: hide it when visible, otherwise open it.
---@return nil
function M.toggle()
  if win_valid() then
    M.hide()
  else
    M.open()
  end
end

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("CursorAgentFloat", { clear = true }),
  desc = "Keep the Cursor Agent float centered on resize",
  callback = function()
    M.on_resize()
  end,
})

return M
