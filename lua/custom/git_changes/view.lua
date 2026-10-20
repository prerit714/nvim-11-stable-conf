-- Side-by-side diff tabpage for stepping through a list of changed files.
--
-- Left window: read-only scratch buffer with the file at the base ref.
-- Right window: the real working-tree file (editable; saving updates the
-- diff). Both use native diff mode, so ]c/[c, do/dp and diff folds work.
-- Only one diff tab exists at a time; reopening reuses it.

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
---@field mapped integer[] Buffers carrying our buffer-local maps.

---@type GitChanges.ViewState?
local state = nil

local MAP_KEYS = { "]f", "[f", "q", "<leader>gc" }

---@param s string
---@return string
local function escape_stl(s)
  return (s:gsub("%%", "%%%%"))
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
  map("<leader>gc", function()
    if state then
      require("custom.git_changes.picker").open(
        state.root,
        state.base,
        state.label
      )
    end
  end, "Git changes: reopen picker")
  table.insert(state.mapped, buf)
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

---Show `state.files[state.idx]` in the diff tab.
local function render()
  local s = assert(state)
  local entry = s.files[s.idx]
  vim.api.nvim_set_current_tabpage(s.tab)
  vim.cmd("diffoff!")
  unmap_all()

  -- Left: base version. Name the buffer only after it replaces the previous
  -- scratch buffer (which wipes on hide) so names never collide.
  local left_buf = scratch(git.show(s.root, s.base, entry.path), entry.path)
  vim.api.nvim_win_set_buf(s.left, left_buf)
  pcall(
    vim.api.nvim_buf_set_name,
    left_buf,
    "gitchanges://" .. s.label .. "/" .. entry.path
  )

  -- Right: working tree, or an empty placeholder for deleted files.
  local right_buf
  if entry.status == "D" then
    right_buf = scratch({}, entry.path)
    vim.api.nvim_win_set_buf(s.right, right_buf)
    pcall(
      vim.api.nvim_buf_set_name,
      right_buf,
      "gitchanges://deleted/" .. entry.path
    )
  else
    vim.api.nvim_win_call(s.right, function()
      vim.cmd.edit(vim.fn.fnameescape(s.root .. "/" .. entry.path))
    end)
    right_buf = vim.api.nvim_win_get_buf(s.right)
  end

  for _, win in ipairs({ s.left, s.right }) do
    vim.api.nvim_win_call(win, function()
      vim.cmd.diffthis()
    end)
  end

  local path = escape_stl(entry.path)
  vim.wo[s.left].winbar = "%#DiffDelete# "
    .. escape_stl(s.label)
    .. " %* "
    .. path
  vim.wo[s.right].winbar = ("%%#DiffAdd# %s %%* %s  [%d/%d]  %%#Comment#]f/[f files  ]c/[c hunks  q close%%*"):format(
    entry.status == "D" and "Deleted" or "Working tree",
    path,
    s.idx,
    #s.files
  )

  map_buffer(left_buf)
  map_buffer(right_buf)

  -- Land on the first hunk of the working-tree side.
  vim.api.nvim_set_current_win(s.right)
  vim.cmd("normal! gg")
  pcall(vim.cmd, "normal! ]c")
end

---Open (or reuse) the diff tab at `files[idx]`.
---@param opts { root: string, base: string, label: string, files: GitChanges.Entry[], idx: integer }
function M.open(opts)
  if
    not (
      state
      and vim.api.nvim_tabpage_is_valid(state.tab)
      and vim.api.nvim_win_is_valid(state.left)
      and vim.api.nvim_win_is_valid(state.right)
    )
  then
    unmap_all()
    vim.cmd("tabnew")
    vim.bo.bufhidden = "wipe"
    local tab = vim.api.nvim_get_current_tabpage()
    local right = vim.api.nvim_get_current_win()
    vim.cmd("leftabove vsplit")
    local left = vim.api.nvim_get_current_win()
    state = {
      tab = tab,
      left = left,
      right = right,
      mapped = {},
    }

    local group = vim.api.nvim_create_augroup("GitChangesView", {})
    vim.api.nvim_create_autocmd("TabClosed", {
      group = group,
      callback = function()
        if state and not vim.api.nvim_tabpage_is_valid(state.tab) then
          unmap_all()
          state = nil
          vim.api.nvim_del_augroup_by_id(group)
        end
      end,
    })
  end

  state.root = opts.root
  state.base = opts.base
  state.label = opts.label
  state.files = opts.files
  state.idx = opts.idx
  render()
end

---Move `delta` files forward/backward, wrapping around.
---@param delta integer
function M.step(delta)
  if not state or #state.files == 0 then
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
  if vim.api.nvim_tabpage_is_valid(tab) then
    vim.api.nvim_set_current_tabpage(tab)
    vim.cmd("diffoff!")
    if #vim.api.nvim_list_tabpages() > 1 then
      vim.cmd("tabclose")
    else
      vim.cmd("only")
      vim.wo.winbar = ""
    end
  end
  state = nil
  pcall(vim.api.nvim_del_augroup_by_name, "GitChangesView")
end

return M
