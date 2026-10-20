-- Telescope picker listing changed files with a unified-diff preview.
--
-- <CR> opens the side-by-side diff tab (view.lua) at the selected file,
-- <C-e> edits the file, <C-s> toggles it staged/unstaged and refreshes.

local git = require("custom.git_changes.git")

local M = {}

local STATUS_HL = {
  M = "Changed",
  T = "Changed",
  U = "Changed",
  A = "Added",
  ["?"] = "Added",
  D = "Removed",
}

---Open the picker for changes in `root` relative to `base`.
---@param root string Repository root.
---@param base string Ref to diff against.
---@param label string Human-readable name of `base`.
function M.open(root, base, label)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local previewers = require("telescope.previewers")
  local putils = require("telescope.previewers.utils")
  local entry_display = require("telescope.pickers.entry_display")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local files = git.changes(root, base)
  if #files == 0 then
    vim.notify("No changes vs " .. label, vim.log.levels.INFO)
    return
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 1 },
      { width = 1 },
      { width = 6 },
      { width = 6 },
      { remaining = true },
    },
  })

  local function make_finder()
    local staged = git.staged(root)
    return finders.new_table({
      results = files,
      entry_maker = function(e)
        return {
          value = e,
          ordinal = e.path,
          display = function()
            return displayer({
              { e.status, STATUS_HL[e.status] },
              { staged[e.path] and "S" or " ", "Special" },
              { e.added and ("+" .. e.added) or "bin", "Added" },
              { e.removed and ("-" .. e.removed) or "", "Removed" },
              e.path,
            })
          end,
        }
      end,
    })
  end

  local previewer = previewers.new_buffer_previewer({
    title = "Diff",
    define_preview = function(self, entry)
      local bufnr = self.state.bufnr
      vim.system(
        git.diff_cmd(base, entry.value),
        { cwd = root, text = true },
        vim.schedule_wrap(function(res)
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end
          local lines = vim.split(res.stdout or "", "\n", { plain = true })
          if lines[#lines] == "" then
            table.remove(lines)
          end
          if #lines == 0 then
            lines = { "(no textual diff)" }
          end
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
          putils.highlighter(bufnr, "diff")
        end)
      )
    end,
  })

  ---Index into `files` of the selected entry.
  ---@return integer?
  local function selected_index()
    local sel = action_state.get_selected_entry()
    if not sel then
      return nil
    end
    for i, e in ipairs(files) do
      if e.path == sel.value.path then
        return i
      end
    end
  end

  pickers
    .new({}, {
      prompt_title = "Git changes vs " .. label,
      results_title = "<CR> diff  <C-e> edit  <C-s> stage/unstage",
      finder = make_finder(),
      sorter = conf.generic_sorter({}),
      previewer = previewer,
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local idx = selected_index()
          actions.close(prompt_bufnr)
          if idx then
            require("custom.git_changes.view").open({
              root = root,
              base = base,
              label = label,
              files = files,
              idx = idx,
            })
          end
        end)

        map({ "i", "n" }, "<C-e>", function()
          local idx = selected_index()
          if not idx then
            return
          end
          if files[idx].status == "D" then
            vim.notify("File was deleted", vim.log.levels.WARN)
            return
          end
          actions.close(prompt_bufnr)
          vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. files[idx].path))
        end, { desc = "Edit file" })

        map({ "i", "n" }, "<C-s>", function()
          local idx = selected_index()
          if not idx then
            return
          end
          local staged = git.toggle_stage(root, files[idx].path)
          vim.notify(
            (staged and "Staged " or "Unstaged ") .. files[idx].path,
            vim.log.levels.INFO
          )
          files = git.changes(root, base)
          action_state
            .get_current_picker(prompt_bufnr)
            :refresh(make_finder(), { reset_prompt = false })
        end, { desc = "Stage/unstage file" })

        return true
      end,
    })
    :find()
end

return M
