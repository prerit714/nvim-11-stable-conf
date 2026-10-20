-- Diff tabpage for stepping through a list of changed files.
--
-- Two layouts, toggled with <leader>gv (the choice persists across opens):
--   inline (default): one window with the real working-tree file. Added and
--     changed lines are highlighted and removed lines are drawn above them
--     as virtual lines, recomputed as you edit.
--   split: native side-by-side diff mode, base version (read-only scratch)
--     on the left, working tree on the right, so ]c/[c, do/dp work.
-- Only one diff tab exists at a time; reopening reuses it.
--
-- The working-tree file is shown immediately; the base version arrives
-- asynchronously from `git show`. A generation counter discards results for
-- a file the user has already moved past. Buffer-local maps that the view
-- shadows (e.g. gitsigns' ]c/[c) are saved and restored afterwards.

local git = require("custom.git_changes.git")

local M = {}

---@alias GitChanges.Layout "inline"|"split"

---@class GitChanges.SavedMap
---@field buf integer
---@field lhs string
---@field prev table? maparg() dict of the buffer-local map we shadowed.

---@class GitChanges.ViewState
---@field tab integer Tabpage handle.
---@field win integer Main window (working-tree side).
---@field left integer? Base-version window, only in the split layout.
---@field root string Repository root.
---@field base string Ref the files are diffed against.
---@field label string Human-readable name of `base`.
---@field files GitChanges.Entry[] Files to cycle through.
---@field idx integer Index into `files` of the file being shown.
---@field gen integer Bumped on every render to drop stale async results.
---@field base_lines string[]? Base version of the current file, once loaded.
---@field hunks integer[] 1-based start rows of inline hunks.
---@field decorated integer? Buffer carrying inline extmarks.
---@field mapped GitChanges.SavedMap[] Buffer-local maps we set.

---@type GitChanges.ViewState?
local state = nil

---@type GitChanges.Layout
local layout = "inline"

local NS = vim.api.nvim_create_namespace("git_changes_inline")
local AUGROUP = "GitChangesView"
local INLINE_AUGROUP = "GitChangesInline"

---@param s string
---@return string
local function escape_stl(s)
  return (s:gsub("%%", "%%%%"))
end

---Whether the diff tab and its main window still exist.
---@return boolean
local function is_open()
  return state ~= nil
    and vim.api.nvim_tabpage_is_valid(state.tab)
    and vim.api.nvim_win_is_valid(state.win)
end

---@return boolean
local function left_valid()
  return state ~= nil
    and state.left ~= nil
    and vim.api.nvim_win_is_valid(state.left)
end

---Remove inline extmarks and their redraw autocmds.
local function clear_inline()
  pcall(vim.api.nvim_del_augroup_by_name, INLINE_AUGROUP)
  if not state then
    return
  end
  if state.decorated and vim.api.nvim_buf_is_valid(state.decorated) then
    vim.api.nvim_buf_clear_namespace(state.decorated, NS, 0, -1)
  end
  state.decorated = nil
  state.hunks = {}
end

---Remove our buffer-local maps and restore whatever they shadowed.
local function unmap_all()
  if not state then
    return
  end
  for i = #state.mapped, 1, -1 do
    local m = state.mapped[i]
    if vim.api.nvim_buf_is_valid(m.buf) then
      pcall(vim.keymap.del, "n", m.lhs, { buffer = m.buf })
      if m.prev then
        vim.api.nvim_buf_call(m.buf, function()
          pcall(vim.fn.mapset, m.prev)
        end)
      end
    end
  end
  state.mapped = {}
end

---Set a buffer-local normal-mode map, remembering any map it shadows.
---@param buf integer
---@param lhs string
---@param rhs function
---@param desc string
local function map(buf, lhs, rhs, desc)
  local s = assert(state)
  local prev = vim.api.nvim_buf_call(buf, function()
    return vim.fn.maparg(lhs, "n", false, true)
  end)
  if vim.tbl_isempty(prev) or prev.buffer ~= 1 then
    prev = nil
  end
  table.insert(s.mapped, { buf = buf, lhs = lhs, prev = prev })
  vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
end

---@param buf integer
local function map_view_keys(buf)
  map(buf, "]f", function()
    M.step(1)
  end, "Git changes: next file")
  map(buf, "[f", function()
    M.step(-1)
  end, "Git changes: previous file")
  map(buf, "q", M.close, "Git changes: close diff tab")
  map(buf, "<leader>gv", M.toggle_layout, "Git changes: toggle inline/split")
  if layout == "inline" then
    map(buf, "]c", function()
      M.hunk(1)
    end, "Git changes: next hunk")
    map(buf, "[c", function()
      M.hunk(-1)
    end, "Git changes: previous hunk")
  end
end

---Fresh read-only scratch buffer holding `lines`.
---@param lines string[]
---@param path string Used to detect the filetype.
---@return integer buf
local function scratch(lines, path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  local ft = vim.filetype.match({ filename = path, buf = buf })
  if ft then
    vim.bo[buf].filetype = ft
  end
  return buf
end

---Replace the contents of a read-only scratch buffer.
---@param buf integer
---@param lines string[]
local function set_scratch_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

---Show `buf` in `win` and give it a (non-colliding) name.
---@param win integer
---@param buf integer
---@param name string
local function show_scratch(win, buf, name)
  -- Name only after the previous scratch buffer (bufhidden=wipe) has been
  -- replaced, so names never collide.
  vim.api.nvim_win_set_buf(win, buf)
  pcall(vim.api.nvim_buf_set_name, buf, name)
end

---Set the winbars for the current entry and layout.
---@param s GitChanges.ViewState
---@param entry GitChanges.Entry
local function set_winbars(s, entry)
  local path = escape_stl(entry.path)
  local side = entry.status == "D" and "Deleted" or "Working tree"
  local pos = ("[%d/%d]"):format(s.idx, #s.files)
  if layout == "inline" then
    vim.wo[s.win].winbar = (
      "%%#DiffAdd# %s -> %s %%* %s  %s"
      .. "  %%#Comment#]f/[f files  ]c/[c hunks  <leader>gv split"
      .. "  q close%%*"
    ):format(escape_stl(s.label), side, path, pos)
    return
  end
  vim.wo[s.win].winbar = (
    "%%#DiffAdd# %s %%* %s  %s"
    .. "  %%#Comment#]f/[f files  ]c/[c hunks  <leader>gv inline"
    .. "  q close%%*"
  ):format(side, path, pos)
  if left_valid() then
    vim.wo[s.left].winbar = ("%%#DiffDelete# %s %%* %s"):format(
      escape_stl(s.label),
      path
    )
  end
end

---Create or close the left window to match `layout`.
---@param s GitChanges.ViewState
local function ensure_layout(s)
  if layout == "split" then
    if not left_valid() then
      s.left = vim.api.nvim_win_call(s.win, function()
        vim.cmd("leftabove vsplit")
        return vim.api.nvim_get_current_win()
      end)
    end
  else
    if left_valid() then
      vim.api.nvim_win_close(s.left, true)
    end
    s.left = nil
  end
end

---Text-area width of `win` (excluding number/sign columns).
---@param win integer
---@return integer
local function text_width(win)
  local info = vim.fn.getwininfo(win)[1]
  return info.width - info.textoff
end

---Draw inline hunks in the main window's buffer from `state.base_lines`.
local function decorate()
  local s = state
  if not s or not s.base_lines or not is_open() then
    return
  end
  local buf = vim.api.nvim_win_get_buf(s.win)
  if s.decorated and vim.api.nvim_buf_is_valid(s.decorated) then
    vim.api.nvim_buf_clear_namespace(s.decorated, NS, 0, -1)
  end
  s.decorated = buf
  s.hunks = {}

  local line_count = vim.api.nvim_buf_line_count(buf)
  local entry = s.files[s.idx]
  if entry.status == "D" then
    for row = 0, line_count - 1 do
      vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
        line_hl_group = "DiffDelete",
      })
    end
    s.hunks = { 1 }
    return
  end

  local width = text_width(s.win)
  local tab = string.rep(" ", vim.bo[buf].tabstop)
  ---@param lines string[]
  local function virt_lines(lines)
    local out = {}
    for _, line in ipairs(lines) do
      local text = line:gsub("\t", tab)
      local pad = width - vim.fn.strdisplaywidth(text)
      if pad > 0 then
        text = text .. string.rep(" ", pad)
      end
      table.insert(out, { { text, "DiffDelete" } })
    end
    return out
  end

  ---@param lines string[]
  local function join(lines)
    return #lines == 0 and "" or table.concat(lines, "\n") .. "\n"
  end

  local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local hunks = vim.text.diff(join(s.base_lines), join(current), {
    result_type = "indices",
    linematch = 60,
  })
  ---@cast hunks integer[][]

  for _, h in ipairs(hunks) do
    local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
    for row = sb - 1, sb + cb - 2 do
      vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
        line_hl_group = "DiffAdd",
      })
    end
    if ca > 0 then
      -- Removed lines go above the hunk's first new line; a pure deletion
      -- goes below the line it follows (or above row 0 at the file start).
      local row, above
      if cb > 0 then
        row, above = sb - 1, true
      elseif sb == 0 then
        row, above = 0, true
      else
        row, above = sb - 1, false
      end
      row = math.max(math.min(row, line_count - 1), 0)
      vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
        virt_lines = virt_lines(vim.list_slice(s.base_lines, sa, sa + ca - 1)),
        virt_lines_above = above,
      })
    end
    table.insert(s.hunks, math.max(math.min(sb, line_count), 1))
  end
end

---Redraw inline hunks (debounced) when the buffer or window size changes.
---@param buf integer
local function attach_inline_autocmds(buf)
  local group = vim.api.nvim_create_augroup(INLINE_AUGROUP, { clear = true })
  local pending = false
  local function schedule_redraw()
    if pending then
      return
    end
    pending = true
    vim.defer_fn(function()
      pending = false
      if layout == "inline" then
        decorate()
      end
    end, 100)
  end
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = buf,
    desc = "Redraw git-changes inline diff",
    callback = schedule_redraw,
  })
  vim.api.nvim_create_autocmd("WinResized", {
    group = group,
    desc = "Re-pad git-changes inline diff",
    callback = schedule_redraw,
  })
end

---Show `state.files[state.idx]` in the diff tab.
local function render()
  local s = assert(state)
  s.gen = s.gen + 1
  local gen = s.gen
  local entry = s.files[s.idx]

  vim.api.nvim_set_current_tabpage(s.tab)
  vim.cmd("diffoff!")
  unmap_all()
  clear_inline()
  s.base_lines = nil
  ensure_layout(s)

  -- Main window: working tree, or a placeholder for deleted files (filled
  -- with the base version in the inline layout).
  if entry.status == "D" then
    show_scratch(
      s.win,
      scratch({}, entry.path),
      "gitchanges://deleted/" .. entry.path
    )
  else
    -- bufadd + win_set_buf instead of :edit: never prompts or reloads when
    -- the buffer has unsaved changes (e.g. re-rendering after a toggle).
    local ok, err = pcall(function()
      local buf = vim.fn.bufadd(s.root .. "/" .. entry.path)
      vim.bo[buf].buflisted = true
      vim.api.nvim_win_set_buf(s.win, buf)
    end)
    if not ok then
      git.notify(("cannot open %s: %s"):format(entry.path, err))
    end
  end
  local main_buf = vim.api.nvim_win_get_buf(s.win)

  -- Left window (split only): base version, filled asynchronously.
  local left_buf
  if s.left then
    left_buf = scratch({}, entry.path)
    show_scratch(
      s.left,
      left_buf,
      "gitchanges://" .. s.label .. "/" .. entry.path
    )
  end

  set_winbars(s, entry)
  map_view_keys(main_buf)
  if left_buf then
    map_view_keys(left_buf)
  end
  vim.api.nvim_set_current_win(s.win)

  git.async(function()
    local lines = git.show(s.root, s.base, entry.path)
    if state ~= s or s.gen ~= gen or not is_open() then
      return
    end
    s.base_lines = lines

    if layout == "split" then
      if
        not (left_buf and vim.api.nvim_buf_is_valid(left_buf) and left_valid())
      then
        return
      end
      set_scratch_lines(left_buf, lines)
      for _, win in ipairs({ s.left, s.win }) do
        vim.api.nvim_win_call(win, function()
          vim.cmd.diffthis()
        end)
      end
      vim.api.nvim_win_call(s.win, function()
        vim.cmd("normal! gg")
        pcall(vim.cmd, "normal! ]c")
      end)
      return
    end

    if entry.status == "D" and vim.api.nvim_buf_is_valid(main_buf) then
      set_scratch_lines(main_buf, lines)
    end
    decorate()
    attach_inline_autocmds(main_buf)
    if s.hunks[1] then
      vim.api.nvim_win_set_cursor(s.win, { s.hunks[1], 0 })
    end
  end)
end

---Create the diff tabpage with its main window.
---@return GitChanges.ViewState
local function create_tab()
  vim.cmd("tabnew")
  vim.bo.bufhidden = "wipe"
  local tab = vim.api.nvim_get_current_tabpage()
  local win = vim.api.nvim_get_current_win()

  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    desc = "Clean up git-changes view state when its tab closes",
    callback = function()
      if state and not vim.api.nvim_tabpage_is_valid(state.tab) then
        unmap_all()
        clear_inline()
        state = nil
        vim.api.nvim_del_augroup_by_id(group)
      end
    end,
  })

  ---@diagnostic disable-next-line: missing-fields
  return { tab = tab, win = win, gen = 0, hunks = {}, mapped = {} }
end

---Open (or reuse) the diff tab at `files[idx]`.
---@param opts { root: string, base: string, label: string, files: GitChanges.Entry[], idx: integer }
function M.open(opts)
  if not is_open() then
    unmap_all()
    clear_inline()
    state = create_tab()
  end
  local s = assert(state)
  s.root = opts.root
  s.base = opts.base
  s.label = opts.label
  s.files = opts.files
  s.idx = opts.idx
  render()
end

---Root/base of the diff tab when it is the current tabpage, so the picker
---can be reopened against the same base.
---@return { root: string, base: string, label: string }?
function M.current()
  if is_open() and vim.api.nvim_get_current_tabpage() == state.tab then
    return { root = state.root, base = state.base, label = state.label }
  end
end

---Move `delta` files forward/backward, wrapping around.
---@param delta integer
function M.step(delta)
  if not is_open() or #state.files == 0 then
    return
  end
  state.idx = (state.idx - 1 + delta) % #state.files + 1
  render()
end

---Jump to the next (delta > 0) or previous inline hunk, wrapping around.
---@param delta integer
function M.hunk(delta)
  if not is_open() or #state.hunks == 0 then
    return
  end
  local hunks = state.hunks
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if delta > 0 then
    for _, row in ipairs(hunks) do
      if row > cur then
        target = row
        break
      end
    end
    target = target or hunks[1]
  else
    for i = #hunks, 1, -1 do
      if hunks[i] < cur then
        target = hunks[i]
        break
      end
    end
    target = target or hunks[#hunks]
  end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

---Switch between the inline and split layouts.
function M.toggle_layout()
  layout = layout == "inline" and "split" or "inline"
  if is_open() then
    render()
  end
end

---Close the diff tab.
function M.close()
  if not state then
    return
  end
  local tab = state.tab
  unmap_all()
  clear_inline()
  state = nil
  pcall(vim.api.nvim_del_augroup_by_name, AUGROUP)
  if not vim.api.nvim_tabpage_is_valid(tab) then
    return
  end
  vim.api.nvim_set_current_tabpage(tab)
  vim.cmd("diffoff!")
  if #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd("tabclose")
  else
    vim.cmd("only")
    vim.wo.winbar = ""
  end
end

return M
