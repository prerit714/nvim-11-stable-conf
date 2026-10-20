-- Async wrappers over the git CLI used by the changes picker.
--
-- Nothing here blocks the UI: `run` must be called inside a coroutine started
-- by `async`, and it yields until the git process exits. Results are resumed
-- through `vim.schedule`, so code after a `run` always executes on the main
-- loop and may call any API. Every command runs with `cwd` set to the
-- repository root so root-relative paths from git can be passed straight back.

local M = {}

---One changed file relative to a base ref.
---@class GitChanges.Entry
---@field status string Single letter: M, A, D, T, U, or ? for untracked.
---@field path string Path relative to the repository root.
---@field added integer? Lines added (nil for binary or untracked files).
---@field removed integer? Lines removed (nil for binary or untracked files).
---@field staged boolean Whether the file has changes in the index.

---Report a failure in a consistent way.
---@param msg string
---@param level integer? vim.log.levels value (defaults to ERROR).
function M.notify(msg, level)
  vim.notify("[git-changes] " .. msg, level or vim.log.levels.ERROR)
end

---Run `fn` in a new coroutine, reporting any error it raises.
---@param fn fun()
function M.async(fn)
  local co = coroutine.create(function()
    xpcall(fn, function(err)
      M.notify(debug.traceback(tostring(err), 2))
    end)
  end)
  local ok, err = coroutine.resume(co)
  if not ok then
    M.notify(tostring(err))
  end
end

---argv for a git invocation.
---@param args string[]
---@return string[]
function M.cmd(args)
  return vim.list_extend({ "git", "--no-pager" }, args)
end

---Start several git commands concurrently and yield until all finish.
---Must be called from a coroutine started by `async`.
---@param root string Working directory.
---@param list string[][] One argument list per command.
---@return { ok: boolean, out: string }[] results In the order of `list`.
function M.run_all(root, list)
  local co = assert(coroutine.running(), "git.run_all outside M.async")
  local results, pending = {}, #list
  for i, args in ipairs(list) do
    local ok, err = pcall(
      vim.system,
      M.cmd(args),
      { cwd = root, text = true },
      function(res)
        results[i] = { ok = res.code == 0, out = res.stdout or "" }
        pending = pending - 1
        if pending == 0 then
          vim.schedule(function()
            coroutine.resume(co)
          end)
        end
      end
    )
    -- vim.system throws synchronously when git is missing.
    if not ok then
      error("failed to run git: " .. tostring(err), 0)
    end
  end
  coroutine.yield()
  return results
end

---Run one git command and yield until it exits.
---@param root string
---@param args string[]
---@return boolean ok, string stdout
function M.run(root, args)
  local res = M.run_all(root, { args })[1]
  return res.ok, res.out
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

---Repository root for the current buffer (or Neovim's cwd), found without
---spawning a process. Nil outside a repository.
---@return string?
function M.root()
  return vim.fs.root(0, ".git") or vim.fs.root(assert(vim.uv.cwd()), ".git")
end

---Whether `ref` resolves to a commit.
---@param root string
---@param ref string
---@return boolean
function M.is_ref(root, ref)
  return (
    M.run(root, { "rev-parse", "--verify", "--quiet", ref .. "^{commit}" })
  )
end

---Merge-base of HEAD with the default branch (origin/HEAD, main, master),
---falling back to HEAD when none of them exist.
---@param root string
---@return string base Commit hash or "HEAD".
---@return string label Human-readable name for the base.
function M.default_base(root)
  local candidates = {}
  local ok, out = M.run(
    root,
    { "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" }
  )
  if ok and vim.trim(out) ~= "" then
    table.insert(candidates, vim.trim(out))
  end
  vim.list_extend(candidates, { "main", "master", "origin/main" })

  for _, ref in ipairs(candidates) do
    local mb_ok, mb = M.run(root, { "merge-base", "HEAD", ref })
    if mb_ok and vim.trim(mb) ~= "" then
      return vim.trim(mb), "merge-base(" .. ref .. ")"
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
  local res = M.run_all(root, {
    { "diff", "--name-status", "--no-renames", "-z", base, "--" },
    { "diff", "--numstat", "--no-renames", "-z", base, "--" },
    { "ls-files", "--others", "--exclude-standard", "-z" },
    { "diff", "--cached", "--name-only", "-z" },
  })
  if not res[1].ok then
    error("git diff failed against " .. base, 0)
  end

  local staged = {}
  for _, path in ipairs(split_nul(res[4].out)) do
    staged[path] = true
  end

  ---@type table<string, GitChanges.Entry>
  local by_path = {}
  local fields = split_nul(res[1].out)
  for i = 1, #fields - 1, 2 do
    local path = fields[i + 1]
    by_path[path] = {
      status = fields[i]:sub(1, 1),
      path = path,
      staged = staged[path] == true,
    }
  end

  for _, rec in ipairs(split_nul(res[2].out)) do
    local added, removed, path = rec:match("^(%S+)\t(%S+)\t(.*)$")
    local entry = path and by_path[path]
    if entry then
      entry.added = tonumber(added)
      entry.removed = tonumber(removed)
    end
  end

  for _, path in ipairs(split_nul(res[3].out)) do
    by_path[path] = { status = "?", path = path, staged = false }
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
  local ok, out = M.run(root, { "show", base .. ":" .. path })
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
    return M.cmd({
      "diff",
      "--no-color",
      "--no-index",
      "--",
      "/dev/null",
      entry.path,
    })
  end
  return M.cmd({ "diff", "--no-color", "--no-renames", base, "--", entry.path })
end

---Stage `path` if it has unstaged (or untracked) changes, otherwise unstage
---it.
---@param root string
---@param path string
---@return boolean staged True when the file ended up staged.
function M.toggle_stage(root, path)
  local _, out = M.run(root, { "status", "--porcelain=v1", "-z", "--", path })
  -- Porcelain v1: "XY path"; Y (worktree column) is non-blank when there is
  -- something left to stage ("?" for untracked files).
  local worktree = out:sub(2, 2)
  if worktree ~= "" and worktree ~= " " then
    local ok = M.run(root, { "add", "-A", "--", path })
    if not ok then
      error("git add failed for " .. path, 0)
    end
    return true
  end
  local ok = M.run(root, { "restore", "--staged", "--", path })
  if not ok then
    error("git restore --staged failed for " .. path, 0)
  end
  return false
end

return M
