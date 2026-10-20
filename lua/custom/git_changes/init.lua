-- Review working-tree changes (e.g. edits made by an AI agent) from Neovim.
--
-- `open` lists files changed vs a ref in a Telescope picker with diff
-- previews; selecting one opens a side-by-side diff tab (see view.lua).
-- All git work is async, so the keypress returns immediately and the picker
-- appears once git answers. Keys and :GitChanges live in
-- lua/custom/plugins/git-changes.lua.

local git = require("custom.git_changes.git")

local M = {}

-- git's well-known empty tree, used as the base before the first commit.
local EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

---@return string?
local function repo_root()
  local root = git.root()
  if not root then
    git.notify("not inside a git repository", vim.log.levels.WARN)
  end
  return root
end

---Pick changes vs `ref`. Without a ref this is HEAD (all uncommitted
---changes), or the diff tab's base when called from inside the diff tab.
---@param ref string?
function M.open(ref)
  local current = require("custom.git_changes.view").current()
  if (ref == nil or ref == "") and current then
    git.async(function()
      require("custom.git_changes.picker").open(
        current.root,
        current.base,
        current.label
      )
    end)
    return
  end

  local root = repo_root()
  if not root then
    return
  end
  ref = (ref and ref ~= "") and ref or "HEAD"
  git.async(function()
    local base, label = ref, ref
    if not git.is_ref(root, ref) then
      if ref ~= "HEAD" then
        git.notify("unknown ref: " .. ref)
        return
      end
      base, label = EMPTY_TREE, "empty tree"
    end
    require("custom.git_changes.picker").open(root, base, label)
  end)
end

---Pick changes vs the merge-base with the default branch (whole branch).
function M.open_branch()
  local root = repo_root()
  if not root then
    return
  end
  git.async(function()
    local base, label = git.default_base(root)
    if base == "HEAD" and not git.is_ref(root, "HEAD") then
      base, label = EMPTY_TREE, "empty tree"
    end
    require("custom.git_changes.picker").open(root, base, label)
  end)
end

return M
