-- Reusable lazygit-style floating-terminal launcher for CLI TUIs.
--
-- `create` returns an independent launcher: its own terminal buffer/window/job
-- state and its own VimResized autocmd, so multiple TUIs (e.g. cursor-agent and
-- opencode) can each be toggled without clobbering one another. Only
-- buffer-local maps are set on each terminal, so global keys (macro `q`, etc.)
-- are never shadowed elsewhere.

local M = {}

---Runtime handles for a single reused terminal session.
---@class FloatTermState
---@field buf integer? Terminal buffer handle, or nil when none exists.
---@field win integer? Float window handle, or nil when hidden/closed.
---@field job integer? termopen job id, or nil when not running.

---A floating-terminal launcher for one CLI command.
---@class FloatTerm
---@field command string Executable launched inside the float.
---@field open fun(): nil Launch (or re-show) the float, starting the CLI if needed.
---@field hide fun(): nil Hide the float, keeping the terminal session alive.
---@field toggle fun(): nil Toggle the float open/closed.
---@field on_resize fun(): nil Re-center/resize the float to the current editor.

---Options accepted by `create`.
---@class FloatTerm.Opts
---@field command string Executable to run inside the float.
---@field name string Unique augroup name (one launcher per name).

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

---Create an independent floating-terminal launcher.
---@param opts FloatTerm.Opts
---@return FloatTerm
function M.create(opts)
  ---@type FloatTermState
  local state = { buf = nil, win = nil, job = nil }

  local term = { command = opts.command }

  ---@return boolean valid True when the terminal buffer handle is live.
  local function buf_valid()
    return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
  end

  ---@return boolean valid True when the float window handle is live.
  local function win_valid()
    return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
  end

  ---Open the float over the current (or reused) terminal buffer.
  ---@return nil
  local function open_window()
    state.win = vim.api.nvim_open_win(state.buf, true, float_config())
    vim.wo[state.win].winfixbuf = true
  end

  ---Close (hide) the float, keeping the terminal session/buffer alive.
  ---@return nil
  function term.hide()
    if win_valid() then
      vim.api.nvim_win_close(state.win, true)
    end
    state.win = nil
    -- The TUI paints the whole float; force a redraw so no stale cells are
    -- left behind on the window we return to.
    vim.schedule(function()
      pcall(function()
        vim.cmd("redraw!")
      end)
    end)
  end

  -- Keep the float centered and sized to the editor when it (or the GUI, e.g.
  -- Neovide) is resized. termopen reflows the terminal contents automatically
  -- once the window geometry changes.
  ---@return nil
  function term.on_resize()
    if win_valid() then
      vim.api.nvim_win_set_config(state.win, float_geometry())
    end
  end

  ---Register the buffer-local maps on the terminal buffer only.
  ---@param buf integer Terminal buffer handle to attach the maps to.
  ---@return nil
  local function set_buffer_keymaps(buf)
    ---@type vim.keymap.set.Opts
    local map_opts = { buffer = buf, silent = true, nowait = true }

    -- Normal-mode `q` hides the float (buffer-local only, so global macro `q`
    -- stays intact everywhere else).
    vim.keymap.set(
      "n",
      "q",
      function()
        term.hide()
      end,
      vim.tbl_extend("force", map_opts, { desc = "Close floating terminal" })
    )

    -- Match the existing terminal-escape convention from lua/keymaps.lua.
    vim.keymap.set(
      "t",
      "<Esc><Esc>",
      "<C-\\><C-n>",
      vim.tbl_extend("force", map_opts, { desc = "Leave terminal mode" })
    )
    vim.keymap.set(
      "t",
      "<C-\\><C-n>",
      "<C-\\><C-n>",
      vim.tbl_extend("force", map_opts, { desc = "Leave terminal mode" })
    )
  end

  ---Launch (or re-show) the float, starting the CLI if needed.
  ---@return nil
  function term.open()
    if vim.fn.executable(term.command) ~= 1 then
      vim.notify(
        string.format("float_term: '%s' is not on PATH.", term.command),
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

    -- Fresh terminal buffer running the command.
    state.buf = vim.api.nvim_create_buf(false, true)
    open_window()

    ---@diagnostic disable-next-line: deprecated
    state.job = vim.fn.termopen(term.command, {
      ---@return nil
      on_exit = function()
        state.job = nil
        -- Drop the buffer so the next toggle starts a clean session.
        if buf_valid() then
          vim.api.nvim_buf_delete(state.buf, { force = true })
        end
        state.buf = nil
        term.hide()
      end,
    })

    set_buffer_keymaps(state.buf)
    vim.cmd("startinsert")
  end

  ---Toggle the float: hide it when visible, otherwise open it.
  ---@return nil
  function term.toggle()
    if win_valid() then
      term.hide()
    else
      term.open()
    end
  end

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup(opts.name, { clear = true }),
    desc = "Keep the " .. opts.name .. " float centered on resize",
    callback = function()
      term.on_resize()
    end,
  })

  return term
end

return M
