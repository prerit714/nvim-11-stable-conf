-- Side-by-side diff tabpage for stepping through a list of changed files.
--
-- Left window: read-only scratch buffer with the file at the base ref.
-- Right window: the real working-tree file (editable; saving updates the
-- diff). Both use native diff mode, so ]c/[c, do/dp and diff folds work.
-- Only one diff tab exists at a time; reopening reuses it.
--
-- The working-tree side is shown immediately; the base side is filled in
-- once `git show` returns. A generation counter discards results for a file
-- the user has already moved past.

local git = require("custom.git_changes.git")

local M = {}

---@class GitChanges.ViewState
---@field tab integer Tabpage handle.
---@field left integer Window showing the base version.
---@field right integer Window showing the working-tree version.
---@field root string Repository root.
---@field base string Ref the files are diffed against.
---@field label string Human-readable name of `base`.
---@field files GitChanges.Entry[] Files to cycle through.
---@field idx integer Index into `files` of the file being shown.
---@field gen integer Bumped on every render to drop stale async results.
---@field mapped integer[] Buffers carrying our buffer-local maps.

---@type GitChanges.ViewState?
local state = nil

local AUGROUP = "GitChangesView"
local MAP_KEYS = { "]f", "[f", "q" }

---@param s string
---@return string
local function escape_stl(s)
  return (s:gsub("%%", "%%%%"))
end

---Whether the diff tab and both of its windows still exist.
---@return boolean
local function is_open()
  return state ~= nil
    and vim.api.nvim_tabpage_is_valid(state.tab)
    and vim.api.nvim_win_is_valid(state.left)
    and vim.api.nvim_win_is_valid(state.right)
end

---Remove our buffer-local maps from every buffer we put them on.
local function unmap_all()
  if not state then
    return
  end
  for _, buf in ipairs(state.mapped) do
    if vim.api.nvim_buf_is_valid(buf) then
      for _, lhs in ipairs(MAP_KEYS) do
        pcall(vim.keymap.del, "n", lhs, { buffer = buf })
      end
    end
  end
  state.mapped = {}
end

---@param buf integer
local function map_buffer(buf)
  local s = assert(state)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
  end
  map("]f", function()
    M.step(1)
  end, "Git changes: next file")
  map("[f", function()
    M.step(-1)
  end, "Git changes: previous file")
  map("q", M.close, "Git changes: close diff tab")
  table.insert(s.mapped, buf)
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

---Set both winbars for the current entry.
---@param s GitChanges.ViewState
---@param entry GitChanges.Entry
local function set_winbars(s, entry)
  local path = escape_stl(entry.path)
  vim.wo[s.left].winbar = ("%%#DiffDelete# %s %%* %s"):format(
    escape_stl(s.label),
    path
  )
  vim.wo[s.right].winbar = (
    "%%#DiffAdd# %s %%* %s  [%d/%d]"
    .. "  %%#Comment#]f/[f files  ]c/[c hunks  q close%%*"
  ):format(
    entry.status == "D" and "Deleted" or "Working tree",
    path,
    s.idx,
    #s.files
  )
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

  -- Left: placeholder until `git show` returns. Name the buffer only after it
  -- replaces the previous scratch buffer (which wipes on hide) so names never
  -- collide.
  local left_buf = scratch({}, entry.path)
  vim.api.nvim_win_set_buf(s.left, left_buf)
  pcall(
    vim.api.nvim_buf_set_name,
    left_buf,
    "gitchanges://" .. s.label .. "/" .. entry.path
  )

  -- Right: working tree, or an empty placeholder for deleted files.
  if entry.status == "D" then
    local buf = scratch({}, entry.path)
    vim.api.nvim_win_set_buf(s.right, buf)
    pcall(vim.api.nvim_buf_set_name, buf, "gitchanges://deleted/" .. entry.path)
  else
    local ok, err = pcall(vim.api.nvim_win_call, s.right, function()
      vim.cmd.edit(vim.fn.fnameescape(s.root .. "/" .. entry.path))
    end)
    if not ok then
      git.notify(("cannot open %s: %s"):format(entry.path, err))
    end
  end
  local right_buf = vim.api.nvim_win_get_buf(s.right)

  set_winbars(s, entry)
  map_buffer(left_buf)
  map_buffer(right_buf)
  vim.api.nvim_set_current_win(s.right)

  git.async(function()
    local lines = git.show(s.root, s.base, entry.path)
    if
      state ~= s
      or s.gen ~= gen
      or not is_open()
      or not vim.api.nvim_buf_is_valid(left_buf)
    then
      return
    end
    set_scratch_lines(left_buf, lines)
    for _, win in ipairs({ s.left, s.right }) do
      vim.api.nvim_win_call(win, function()
        vim.cmd.diffthis()
      end)
    end
    -- Land on the first hunk of the working-tree side.
    vim.api.nvim_win_call(s.right, function()
      vim.cmd("normal! gg")
      pcall(vim.cmd, "normal! ]c")
    end)
  end)
end

---Create the diff tabpage with its two windows.
---@return GitChanges.ViewState
local function create_tab()
  vim.cmd("tabnew")
  vim.bo.bufhidden = "wipe"
  local tab = vim.api.nvim_get_current_tabpage()
  local right = vim.api.nvim_get_current_win()
  vim.cmd("leftabove vsplit")
  local left = vim.api.nvim_get_current_win()

  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    desc = "Forget git-changes view state when its tab closes",
    callback = function()
      if state and not vim.api.nvim_tabpage_is_valid(state.tab) then
        unmap_all()
        state = nil
        vim.api.nvim_del_augroup_by_id(group)
      end
    end,
  })

  ---@diagnostic disable-next-line: missing-fields
  return { tab = tab, left = left, right = right, gen = 0, mapped = {} }
end

---Open (or reuse) the diff tab at `files[idx]`.
---@param opts { root: string, base: string, label: string, files: GitChanges.Entry[], idx: integer }
function M.open(opts)
  if not is_open() then
    unmap_all()
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

---Close the diff tab.
function M.close()
  if not state then
    return
  end
  local tab = state.tab
  unmap_all()
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
