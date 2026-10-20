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
    vim.api.nvim_create_user_command("GitChanges", function(args)
      require("custom.git_changes").open(args.args)
    end, {
      nargs = "?",
      desc = "Pick files changed vs a ref (default HEAD)",
      complete = function(lead)
        local out = vim
          .system({
            "git",
            "for-each-ref",
            "--format=%(refname:short)",
            "refs/heads",
            "refs/remotes",
            "refs/tags",
          }, { text = true })
          :wait().stdout or ""
        local refs = { "HEAD", "HEAD~1", "HEAD~2", "HEAD~3" }
        vim.list_extend(refs, vim.split(out, "\n", { trimempty = true }))
        return vim.tbl_filter(function(r)
          return vim.startswith(r, lead)
        end, refs)
      end,
    })
  end,
}
