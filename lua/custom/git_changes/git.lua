-- Thin synchronous wrappers over the git CLI used by the changes picker.
--
-- Every command runs with `cwd` set to the repository root so paths returned
-- by git (always root-relative) can be passed straight back to it.

local M = {}

---One changed file relative to a base ref.
---@class GitChanges.Entry
---@field status string Single letter: M, A, D, T, U, or ? for untracked.
---@field path string Path relative to the repository root.
---@field added integer? Lines added (nil for binary files).
---@field removed integer? Lines removed (nil for binary files).

---Run git synchronously.
---@param args string[] Arguments after `git`.
---@param cwd string? Working directory (defaults to Neovim's cwd).
---@return boolean ok, string stdout
local function run(args, cwd)
  local cmd = vim.list_extend({ "git", "--no-pager" }, args)
  local res = vim.system(cmd, { cwd = cwd, text = true }):wait()
  return res.code == 0, res.stdout or ""
end

---Split NUL-separated output, dropping the trailing empty field.
---@param out string
---@return string[]
local function split_nul(out)
  local fields = vim.split(out, "\0", { plain = true })
  if fields[#fields] == "" then
    table.remove(fields)
  end
  return fields
end

---Repository root for Neovim's cwd, or nil outside a repository.
---@return string?
function M.root()
  local ok, out = run({ "rev-parse", "--show-toplevel" })
  if not ok then
    return nil
  end
  return vim.trim(out)
end

---Whether `ref` resolves to a commit.
---@param root string
---@param ref string
---@return boolean
function M.is_ref(root, ref)
  return (run({ "rev-parse", "--verify", "--quiet", ref .. "^{commit}" }, root))
end

---Merge-base of HEAD with the default branch (origin/HEAD, main, master),
---falling back to HEAD when none of them exist.
---@param root string
---@return string base Commit hash or "HEAD".
---@return string label Human-readable name for the base.
function M.default_base(root)
  local candidates = {}
  local ok, out = run(
    { "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" },
    root
  )
  if ok and vim.trim(out) ~= "" then
    table.insert(candidates, vim.trim(out))
  end
  vim.list_extend(candidates, { "main", "master", "origin/main" })

  for _, ref in ipairs(candidates) do
    if M.is_ref(root, ref) then
      local mb_ok, mb = run({ "merge-base", "HEAD", ref }, root)
      if mb_ok and vim.trim(mb) ~= "" then
        return vim.trim(mb), "merge-base(" .. ref .. ")"
      end
    end
  end
  return "HEAD", "HEAD"
end

---Files changed in the working tree relative to `base`, including untracked
---files, sorted by path.
---@param root string
---@param base string
---@return GitChanges.Entry[]
function M.changes(root, base)
  local by_path = {}

  local _, names =
    run({ "diff", "--name-status", "--no-renames", "-z", base, "--" }, root)
  local fields = split_nul(names)
  for i = 1, #fields - 1, 2 do
    local status = fields[i]:sub(1, 1)
    by_path[fields[i + 1]] = { status = status, path = fields[i + 1] }
  end

  local _, nums =
    run({ "diff", "--numstat", "--no-renames", "-z", base, "--" }, root)
  for _, rec in ipairs(split_nul(nums)) do
    local added, removed, path = rec:match("^(%S+)\t(%S+)\t(.*)$")
    local entry = path and by_path[path]
    if entry then
      entry.added = tonumber(added)
      entry.removed = tonumber(removed)
    end
  end

  local _, untracked =
    run({ "ls-files", "--others", "--exclude-standard", "-z" }, root)
  for _, path in ipairs(split_nul(untracked)) do
    local n = 0
    local fd = io.open(root .. "/" .. path, "rb")
    if fd then
      for _ in fd:lines() do
        n = n + 1
      end
      fd:close()
    end
    by_path[path] = { status = "?", path = path, added = n, removed = 0 }
  end

  local list = vim.tbl_values(by_path)
  table.sort(list, function(a, b)
    return a.path < b.path
  end)
  return list
end

---Contents of `path` at `base` as lines, or {} when it does not exist there.
---@param root string
---@param base string
---@param path string
---@return string[]
function M.show(root, base, path)
  local ok, out = run({ "show", base .. ":" .. path }, root)
  if not ok then
    return {}
  end
  local lines = vim.split(out, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  return lines
end

---argv producing a unified diff of one entry (used by the previewer).
---@param base string
---@param entry GitChanges.Entry
---@return string[]
function M.diff_cmd(base, entry)
  if entry.status == "?" then
    return {
      "git",
      "--no-pager",
      "diff",
      "--no-color",
      "--no-index",
      "--",
      "/dev/null",
      entry.path,
    }
  end
  return {
    "git",
    "--no-pager",
    "diff",
    "--no-color",
    "--no-renames",
    base,
    "--",
    entry.path,
  }
end

---Paths currently staged in the index.
---@param root string
---@return table<string, boolean>
function M.staged(root)
  local _, out = run({ "diff", "--cached", "--name-only", "-z" }, root)
  local set = {}
  for _, path in ipairs(split_nul(out)) do
    set[path] = true
  end
  return set
end

---Stage `path` if it has unstaged changes, otherwise unstage it.
---@param root string
---@param path string
---@return boolean staged True when the file ended up staged.
function M.toggle_stage(root, path)
  local _, unstaged = run({ "diff", "--name-only", "-z", "--", path }, root)
  local _, untracked = run(
    { "ls-files", "--others", "--exclude-standard", "-z", "--", path },
    root
  )
  if unstaged ~= "" or untracked ~= "" then
    run({ "add", "-A", "--", path }, root)
    return true
  end
  run({ "restore", "--staged", "--", path }, root)
  return false
end

return M
