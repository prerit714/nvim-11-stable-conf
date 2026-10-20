-- Review working-tree changes (e.g. edits made by an AI agent) from Neovim.
--
-- `open` lists files changed vs a ref in a Telescope picker with diff
-- previews; selecting one opens a side-by-side diff tab (see view.lua).
-- Keys and the :GitChanges command live in lua/custom/plugins/git-changes.lua.

local git = require("custom.git_changes.git")

local M = {}

-- git's well-known empty tree, used as the base before the first commit.
local EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

---@return string?
local function repo_root()
  local root = git.root()
  if not root then
    vim.notify("Not inside a git repository", vim.log.levels.WARN)
  end
  return root
end

---Pick changes vs `ref` (default HEAD: all uncommitted changes).
---@param ref string?
function M.open(ref)
  local root = repo_root()
  if not root then
    return
  end
  ref = (ref and ref ~= "") and ref or "HEAD"
  if not git.is_ref(root, ref) then
    if ref ~= "HEAD" then
      vim.notify("Unknown ref: " .. ref, vim.log.levels.ERROR)
      return
    end
    require("custom.git_changes.picker").open(root, EMPTY_TREE, "empty tree")
    return
  end
  require("custom.git_changes.picker").open(root, ref, ref)
end

---Pick changes vs the merge-base with the default branch (whole branch).
function M.open_branch()
  local root = repo_root()
  if not root then
    return
  end
  local base, label = git.default_base(root)
  if base == "HEAD" and not git.is_ref(root, "HEAD") then
    base, label = EMPTY_TREE, "empty tree"
  end
  require("custom.git_changes.picker").open(root, base, label)
end

return M
