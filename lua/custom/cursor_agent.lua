-- Lazygit-style floating terminal for the Cursor agent TUI.
--
-- Opens `cursor-agent` in a centered floating window, reuses a single terminal
-- buffer across toggles, and closes the window automatically when the process
-- exits. Only buffer-local maps are set on the agent terminal so the global
-- `q` (macro record) and other keys are never shadowed elsewhere.

local M = {}

-- Command run inside the float. Overridable if the binary is named differently.
M.command = "cursor-agent"

local state = {
  buf = nil,
  win = nil,
  job = nil,
}

local function buf_valid()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

local function win_valid()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function float_config()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  return {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = (vim.o.winborder ~= nil and vim.o.winborder ~= "")
        and vim.o.winborder
      or "single",
  }
end

local function set_buffer_keymaps(buf)
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

function M.hide()
  if win_valid() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  -- The agent TUI paints the whole float; force a redraw so no stale cells are
  -- left behind on the window we return to.
  vim.schedule(function()
    pcall(vim.cmd, "redraw!")
  end)
end

local function open_window()
  state.win = vim.api.nvim_open_win(state.buf, true, float_config())
  vim.wo[state.win].winfixbuf = true
end

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

  state.job = vim.fn.termopen(M.command, {
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

function M.toggle()
  if win_valid() then
    M.hide()
  else
    M.open()
  end
end

return M
