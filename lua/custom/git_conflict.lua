-- Merge-conflict helpers that work on conflict markers in any buffer: a plain
-- conflicted file or the middle (working-copy) window of fugitive's 3-way
-- `:Gvdiffsplit!`.
--
-- `resolve(choice)` replaces the conflict under the cursor with ours, theirs,
-- both or none. In a diff window with no marker under the cursor it falls
-- back to `:diffget //2` / `//3` (fugitive's ours/theirs buffers). Conflicts
-- are highlighted inline (ours / base / theirs) with key hints, refreshed on
-- read/write and, for buffers that have conflicts, as they are edited.
-- Supports the diff3/zdiff3 conflict style (`|||||||` base section).

local M = {}

local NS = vim.api.nvim_create_namespace("git_conflict")
local MAX_LINES = 20000

---Line numbers (1-based) of one conflict's markers.
---@class GitConflict.Block
---@field start integer `<<<<<<<` line.
---@field base integer? `|||||||` line (diff3/zdiff3 style only).
---@field sep integer `=======` line.
---@field finish integer `>>>>>>>` line.

---@alias GitConflict.Choice "ours"|"theirs"|"both"|"none"

---@param msg string
---@param level integer?
local function notify(msg, level)
  vim.notify("[git-conflict] " .. msg, level or vim.log.levels.WARN)
end

---Parse every complete conflict block in `lines`.
---@param lines string[]
---@return GitConflict.Block[]
local function parse(lines)
  local out, cur = {}, nil
  for i, line in ipairs(lines) do
    if line:find("^<<<<<<<") then
      cur = { start = i }
    elseif cur then
      if not cur.sep and line:find("^|||||||") then
        cur.base = i
      elseif not cur.sep and line:find("^=======%s*$") then
        cur.sep = i
      elseif cur.sep and line:find("^>>>>>>>") then
        cur.finish = i
        table.insert(out, cur)
        cur = nil
      end
    end
  end
  return out
end

---Cheap check before parsing: does any line start a conflict?
---@param lines string[]
---@return boolean
local function has_markers(lines)
  if #lines == 0 then
    return false
  end
  return lines[1]:find("^<<<<<<<") ~= nil
    or table.concat(lines, "\n"):find("\n<<<<<<<", 1, true) ~= nil
end

---@param buf integer
---@return string[]
local function buf_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

---@param buf integer
---@param from integer 1-based first line.
---@param to integer 1-based last line (inclusive).
---@param hl string
local function hl_lines(buf, from, to, hl)
  for lnum = from, to do
    vim.api.nvim_buf_set_extmark(buf, NS, lnum - 1, 0, {
      line_hl_group = hl,
      priority = 10,
    })
  end
end

---@param buf integer
---@param lnum integer 1-based.
---@param hint string
local function marker(buf, lnum, hint)
  vim.api.nvim_buf_set_extmark(buf, NS, lnum - 1, 0, {
    line_hl_group = "DiffText",
    virt_text = { { "  " .. hint, "Comment" } },
    virt_text_pos = "eol",
    priority = 10,
  })
end

---Re-highlight the conflicts in `buf`.
---@param buf integer
function M.refresh(buf)
  if
    not vim.api.nvim_buf_is_valid(buf)
    or vim.bo[buf].buftype ~= ""
    or vim.api.nvim_buf_line_count(buf) > MAX_LINES
  then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  local lines = buf_lines(buf)
  local blocks = has_markers(lines) and parse(lines) or {}
  vim.b[buf].git_conflicts = #blocks
  for _, c in ipairs(blocks) do
    marker(buf, c.start, "ours: <leader>go")
    hl_lines(buf, c.start + 1, (c.base or c.sep) - 1, "DiffAdd")
    if c.base then
      marker(buf, c.base, "base")
      hl_lines(buf, c.base + 1, c.sep - 1, "DiffDelete")
    end
    marker(buf, c.sep, "both: <leader>ga | none: <leader>gx")
    hl_lines(buf, c.sep + 1, c.finish - 1, "DiffChange")
    marker(buf, c.finish, "theirs: <leader>gt")
  end
end

---Resolve the conflict under the cursor.
---@param choice GitConflict.Choice
function M.resolve(choice)
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = buf_lines(buf)
  local block
  for _, c in ipairs(parse(lines)) do
    if c.start <= row and row <= c.finish then
      block = c
      break
    end
  end

  if not block then
    if vim.wo.diff and (choice == "ours" or choice == "theirs") then
      -- Fugitive's 3-way split names the sides //2 (ours) and //3 (theirs).
      local ok, err =
        pcall(vim.cmd, "diffget " .. (choice == "ours" and "//2" or "//3"))
      if not ok then
        notify(tostring(err), vim.log.levels.ERROR)
      end
      return
    end
    notify("no conflict under cursor")
    return
  end

  local ours =
    vim.list_slice(lines, block.start + 1, (block.base or block.sep) - 1)
  local theirs = vim.list_slice(lines, block.sep + 1, block.finish - 1)
  local replacement = ({
    ours = ours,
    theirs = theirs,
    both = vim.list_extend(vim.list_extend({}, ours), theirs),
    none = {},
  })[choice]

  vim.api.nvim_buf_set_lines(
    buf,
    block.start - 1,
    block.finish,
    false,
    replacement
  )
  local last = math.max(vim.api.nvim_buf_line_count(buf), 1)
  vim.api.nvim_win_set_cursor(0, { math.min(block.start, last), 0 })
  if vim.wo.diff then
    vim.cmd("diffupdate")
  end
  M.refresh(buf)

  local left = vim.b[buf].git_conflicts or 0
  if left == 0 then
    notify(
      "all conflicts resolved; <leader>gw stages the file",
      vim.log.levels.INFO
    )
  end
end

---Jump to the next (dir > 0) or previous conflict, wrapping around.
---@param dir integer
function M.jump(dir)
  if vim.fn.search("^<<<<<<<", dir > 0 and "w" or "bw") == 0 then
    notify("no conflicts in buffer", vim.log.levels.INFO)
  end
end

---Install the highlighting autocmds (cheap; called at startup).
function M.setup()
  local group = vim.api.nvim_create_augroup("GitConflict", { clear = true })
  vim.api.nvim_create_autocmd(
    { "BufReadPost", "BufWritePost", "FileChangedShellPost" },
    {
      group = group,
      desc = "Highlight git conflict markers",
      callback = function(args)
        M.refresh(args.buf)
      end,
    }
  )

  -- Only buffers known to contain conflicts are rescanned while editing.
  local pending = {}
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = group,
    desc = "Refresh git conflict highlights while resolving",
    callback = function(args)
      local buf = args.buf
      if (vim.b[buf].git_conflicts or 0) == 0 or pending[buf] then
        return
      end
      pending[buf] = true
      vim.defer_fn(function()
        pending[buf] = nil
        M.refresh(buf)
      end, 150)
    end,
  })
end

return M
