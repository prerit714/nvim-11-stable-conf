-- Telescope picker listing changed files with a unified-diff preview.
--
-- <CR> opens the side-by-side diff tab (view.lua) at the selected file,
-- <C-e> edits the file, <C-s> toggles it staged/unstaged and refreshes.
-- Diff previews are produced asynchronously and cached per path for the
-- lifetime of the picker.

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

---@param out string
---@return string[]
local function to_lines(out)
  local lines = vim.split(out, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  if #lines == 0 then
    lines = { "(no textual diff)" }
  end
  return lines
end

---Build and show the Telescope picker for an already-fetched file list.
---@param root string
---@param base string
---@param label string
---@param files GitChanges.Entry[]
local function show(root, base, label, files)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local previewers = require("telescope.previewers")
  local putils = require("telescope.previewers.utils")
  local entry_display = require("telescope.pickers.entry_display")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  ---@type table<string, string[]>
  local preview_cache = {}

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

  ---@param e GitChanges.Entry
  local function added_text(e)
    if e.status == "?" then
      return "new"
    end
    return e.added and ("+" .. e.added) or "bin"
  end

  local function make_finder()
    return finders.new_table({
      results = files,
      ---@param e GitChanges.Entry
      entry_maker = function(e)
        return {
          value = e,
          ordinal = e.path,
          display = function()
            return displayer({
              { e.status, STATUS_HL[e.status] },
              { e.staged and "S" or " ", "Special" },
              { added_text(e), "Added" },
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
      local path = entry.value.path

      local function fill(lines)
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
          putils.highlighter(bufnr, "diff")
        end
      end

      if preview_cache[path] then
        fill(preview_cache[path])
        return
      end
      vim.system(
        git.diff_cmd(base, entry.value),
        { cwd = root, text = true },
        vim.schedule_wrap(function(res)
          preview_cache[path] = to_lines(res.stdout or "")
          fill(preview_cache[path])
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
            git.notify("file was deleted", vim.log.levels.WARN)
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
          local path = files[idx].path
          git.async(function()
            local staged = git.toggle_stage(root, path)
            git.notify(
              (staged and "staged " or "unstaged ") .. path,
              vim.log.levels.INFO
            )
            local updated = git.changes(root, base)
            if not vim.api.nvim_buf_is_valid(prompt_bufnr) then
              return
            end
            files = updated
            preview_cache = {}
            -- Leave our coroutine before handing control to Telescope,
            -- which runs its own plenary.async coroutines.
            vim.schedule(function()
              local picker = action_state.get_current_picker(prompt_bufnr)
              if picker then
                picker:refresh(make_finder(), { reset_prompt = false })
              end
            end)
          end)
        end, { desc = "Stage/unstage file" })

        return true
      end,
    })
    :find()
end

---Open the picker for changes in `root` relative to `base`.
---Must be called from a coroutine started by `git.async`.
---@param root string Repository root.
---@param base string Ref to diff against.
---@param label string Human-readable name of `base`.
function M.open(root, base, label)
  local files = git.changes(root, base)
  if #files == 0 then
    git.notify("no changes vs " .. label, vim.log.levels.INFO)
    return
  end
  -- Leave our coroutine before handing control to Telescope, which runs its
  -- own plenary.async coroutines.
  vim.schedule(function()
    show(root, base, label, files)
  end)
end

return M
