-- Local (dependency-free) lazy spec for reviewing working-tree changes:
-- a Telescope picker of changed files with diff previews, opening a
-- side-by-side diff tab (logic in lua/custom/git_changes/).
---@type LazySpec
return {
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/git-changes-lazy",
  name = "git-changes",
  dependencies = { "nvim-telescope/telescope.nvim" },
  cmd = "GitChanges",
  keys = {
    {
      "<leader>gc",
      function()
        require("custom.git_changes").open()
      end,
      desc = "[G]it [C]hanges (uncommitted)",
    },
    {
      "<leader>gC",
      function()
        require("custom.git_changes").open_branch()
      end,
      desc = "[G]it [C]hanges (whole branch)",
    },
  },
  config = function()
    local git = require("custom.git_changes.git")

    -- Command-line completion must answer synchronously, so serve refs from
    -- a cache that is refreshed asynchronously (on load and on every
    -- completion request) instead of shelling out while the user waits.
    local refs = { "HEAD", "HEAD~1", "HEAD~2", "HEAD~3" }
    local function refresh_refs()
      local root = git.root()
      if not root then
        return
      end
      git.async(function()
        local ok, out = git.run(root, {
          "for-each-ref",
          "--format=%(refname:short)",
          "refs/heads",
          "refs/remotes",
          "refs/tags",
        })
        if ok then
          refs = { "HEAD", "HEAD~1", "HEAD~2", "HEAD~3" }
          vim.list_extend(refs, vim.split(out, "\n", { trimempty = true }))
        end
      end)
    end
    refresh_refs()

    vim.api.nvim_create_user_command("GitChanges", function(args)
      require("custom.git_changes").open(args.args)
    end, {
      nargs = "?",
      desc = "Pick files changed vs a ref (default HEAD)",
      complete = function(lead)
        refresh_refs()
        return vim.tbl_filter(function(r)
          return vim.startswith(r, lead)
        end, refs)
      end,
    })
  end,
}
