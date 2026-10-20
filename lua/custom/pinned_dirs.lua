-- Pinned project directories: a persisted list shown on the mini.starter
-- start screen. Picking one makes it Neovim's global cwd, and entering a file
-- inside a pinned dir switches the cwd to that dir.
--
-- Required at startup by mini.lua (start screen items) and the pinned-dirs
-- lazy spec (`setup`), so keep the top level free of work: the JSON file is
-- only read on first use.

local M = {}

local is_win = vim.fn.has("win32") == 1
local store_path = vim.fn.stdpath("data") .. "/pinned_dirs.json"

---Cached pinned dirs (absolute, normalized), in pin order.
---@type string[]|nil
local pins = nil

---Absolute, `/`-separated path without a trailing slash.
---@param path string
---@return string
local function normalize(path)
  local abs = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  -- Keep the slash of a bare root ("/" or "C:/").
  if #abs > 1 and not abs:match("^%a:/$") then
    abs = abs:gsub("/+$", "")
  end
  return abs
end

---Comparison key: Windows paths are case-insensitive.
---@param path string Normalized path.
---@return string
local function key(path)
  return is_win and path:lower() or path
end

---Whether `dir` is `path` or one of its ancestors (both normalized).
---@param dir string
---@param path string
---@return boolean
local function contains(dir, path)
  local d, p = key(dir), key(path)
  if p == d then
    return true
  end
  local prefix = d:sub(-1) == "/" and d or d .. "/"
  return p:sub(1, #prefix) == prefix
end

---@return string[]
local function load()
  if pins then
    return pins
  end
  pins = {}
  local ok, lines = pcall(vim.fn.readfile, store_path)
  if ok and #lines > 0 then
    local decoded_ok, decoded =
      pcall(vim.json.decode, table.concat(lines, "\n"))
    if decoded_ok and type(decoded) == "table" then
      for _, dir in ipairs(decoded) do
        if type(dir) == "string" then
          table.insert(pins, normalize(dir))
        end
      end
    end
  end
  return pins
end

---@return nil
local function save()
  vim.fn.mkdir(vim.fn.fnamemodify(store_path, ":h"), "p")
  vim.fn.writefile({ vim.json.encode(load()) }, store_path)
end

---Refresh the start screen if it is the current buffer.
---@return nil
local function refresh_starter()
  if vim.bo.filetype == "ministarter" and _G.MiniStarter then
    _G.MiniStarter.refresh()
  end
end

---Pinned dirs that still exist on disk.
---@return string[]
function M.list()
  return vim.tbl_filter(function(dir)
    local stat = vim.uv.fs_stat(dir)
    return stat ~= nil and stat.type == "directory"
  end, load())
end

---Longest pinned dir containing `path`, if any.
---@param path string
---@return string|nil
function M.owner(path)
  path = normalize(path)
  local best = nil
  for _, dir in ipairs(load()) do
    if contains(dir, path) and (not best or #dir > #best) then
      best = dir
    end
  end
  return best
end

---Project root for the current buffer: the start screen uses the cwd, Oil the
---directory it shows, files their git root (else their folder).
---@return string
function M.current_root()
  local ft = vim.bo.filetype
  if ft == "ministarter" then
    return normalize(assert(vim.uv.cwd()))
  end
  if ft == "oil" then
    local ok, dir = pcall(function()
      return require("oil").get_current_dir()
    end)
    if ok and dir then
      return normalize(dir)
    end
  end
  local name = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype == "" and name ~= "" and not name:match("^%a%a+://") then
    return normalize(vim.fs.root(0, ".git") or vim.fs.dirname(name))
  end
  return normalize(assert(vim.uv.cwd()))
end

---Make `dir` the global cwd (a no-op when it already is).
---@param dir string
---@return nil
function M.cd(dir)
  dir = normalize(dir)
  if key(normalize(vim.fn.getcwd(-1, -1))) == key(dir) then
    return
  end
  -- Global :cd fires DirChanged with scope "global", which fff.nvim uses to
  -- re-index; harpoon lists are keyed by cwd and follow along.
  vim.cmd.cd({ args = { dir }, mods = { silent = true } })
end

---cd into a pinned dir and open the file picker there.
---@param dir string
---@return nil
function M.open(dir)
  M.cd(dir)
  refresh_starter()
  require("fff").find_files()
end

---Pin the current project root (and cd into it), or unpin it if pinned.
---@return nil
function M.toggle()
  local root = M.current_root()
  local list = load()
  for i, dir in ipairs(list) do
    if key(dir) == key(root) then
      table.remove(list, i)
      save()
      vim.notify("[pinned_dirs] unpinned " .. root, vim.log.levels.INFO)
      refresh_starter()
      return
    end
  end
  table.insert(list, root)
  save()
  M.cd(root)
  vim.notify("[pinned_dirs] pinned " .. root, vim.log.levels.INFO)
  refresh_starter()
end

---Pick a pinned dir, cd into it and open the file picker.
---@return nil
function M.pick()
  local dirs = M.list()
  if #dirs == 0 then
    vim.notify("[pinned_dirs] nothing pinned yet", vim.log.levels.WARN)
    return
  end
  vim.ui.select(dirs, {
    prompt = "Pinned dirs:",
    format_item = function(dir)
      return vim.fn.fnamemodify(dir, ":~")
    end,
  }, function(choice)
    if choice then
      M.open(choice)
    end
  end)
end

---mini.starter items source; evaluated on every open/refresh.
---@return fun(): table[]
function M.starter_items()
  return function()
    local items = {}
    for _, dir in ipairs(M.list()) do
      table.insert(items, {
        section = "Pinned",
        name = vim.fn.fnamemodify(dir, ":~"),
        action = function()
          M.open(dir)
        end,
      })
    end
    if #items == 0 then
      items[1] = {
        section = "Pinned",
        name = "Nothing pinned: <leader>pp pins the current project",
        action = "",
      }
    end
    return items
  end
end

---Install the auto-cd autocmd: entering a file inside a pinned dir makes that
---dir the global cwd.
---@return nil
function M.setup()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("PinnedDirs", { clear = true }),
    callback = function(args)
      -- Only real files: skips terminals, oil://, fugitive://, gitchanges://.
      if vim.bo[args.buf].buftype ~= "" then
        return
      end
      local name = vim.api.nvim_buf_get_name(args.buf)
      if name == "" or name:match("^%a%a+://") then
        return
      end
      -- Respect window/tab-local directories (:lcd / :tcd).
      if vim.fn.haslocaldir() ~= 0 then
        return
      end
      local dir = M.owner(name)
      if dir then
        M.cd(dir)
      end
    end,
    desc = "cd to the pinned dir containing the current file",
  })
end

return M
