-- Timeboxing: short countdown timers (in minutes) that alert when time is up.
--
-- Several timers can run at once. Each one is a one-shot `vim.uv` timer, so
-- nothing ever blocks the UI; the callback is scheduled back onto the main
-- loop before touching any Neovim API. Timers are stopped and closed when they
-- fire, when they are cancelled, and on VimLeavePre.
--
-- Entry points: `start`, `list`, `cancel`, `cancel_all`, `pick_cancel`,
-- `prompt_start`, `statusline`, and `setup` (creates `:Timebox`).

local M = {}

local uv = vim.uv or vim.loop

---A single running countdown.
---@class Timebox.Timer
---@field id integer Monotonic id, unique for this session.
---@field label string User label ("" when none was given).
---@field minutes number Requested duration in minutes.
---@field deadline integer `uv.now()` value (ms) at which the timer fires.
---@field handle uv.uv_timer_t Underlying libuv timer handle.

---Running timers keyed by id.
---@type table<integer, Timebox.Timer>
local timers = {}

---Last id handed out by `start`.
local next_id = 0

---Stop and close a libuv timer handle, ignoring already-closed handles.
---@param handle uv.uv_timer_t?
---@return nil
local function close_handle(handle)
  if handle and not handle:is_closing() then
    handle:stop()
    handle:close()
  end
end

---Format a duration in minutes for messages ("25 min", "0.5 min").
---@param minutes number
---@return string
local function fmt_minutes(minutes)
  return string.format(
    "%s min",
    (string.format("%.2f", minutes):gsub("%.?0+$", ""))
  )
end

---Format remaining milliseconds as MM:SS (or H:MM:SS for an hour or more).
---@param ms integer
---@return string
local function fmt_remaining(ms)
  local secs = math.max(0, math.ceil(ms / 1000))
  local h = math.floor(secs / 3600)
  local m = math.floor((secs % 3600) / 60)
  local s = secs % 60
  if h > 0 then
    return string.format("%d:%02d:%02d", h, m, s)
  end
  return string.format("%02d:%02d", m, s)
end

---Human-readable name for a timer, used in messages and pickers.
---@param t Timebox.Timer
---@return string
local function describe(t)
  local name = t.label ~= "" and t.label or ("timer #" .. t.id)
  return string.format("%s (%s)", name, fmt_minutes(t.minutes))
end

---Running timers sorted by deadline (soonest first).
---@return Timebox.Timer[]
local function sorted()
  local list = vim.tbl_values(timers)
  table.sort(list, function(a, b)
    return a.deadline < b.deadline
  end)
  return list
end

---Ring the terminal bell; harmless where there is no terminal (e.g. GUIs).
---@return nil
local function bell()
  pcall(vim.api.nvim_chan_send, vim.v.stderr, "\a")
end

---Called on the main loop when a timer's deadline is reached.
---@param id integer
---@return nil
local function finish(id)
  local t = timers[id]
  if not t then
    return -- Cancelled between the libuv callback and this scheduled call.
  end
  timers[id] = nil
  close_handle(t.handle)
  bell()
  vim.notify(
    string.format("Timebox done: %s is up!", describe(t)),
    vim.log.levels.WARN,
    { title = "Timebox" }
  )
  pcall(vim.cmd, "redrawstatus")
end

---Start a countdown timer.
---@param minutes number Duration in minutes (> 0, decimals allowed).
---@param label string? Optional task label.
---@return integer? id Timer id, or nil when the input was invalid.
function M.start(minutes, label)
  minutes = tonumber(minutes)
  if not minutes or minutes ~= minutes or minutes <= 0 or minutes > 24 * 60 then
    vim.notify(
      "Timebox: minutes must be a number between 0 and 1440",
      vim.log.levels.ERROR
    )
    return nil
  end

  local handle = uv.new_timer()
  if not handle then
    vim.notify("Timebox: could not create a timer", vim.log.levels.ERROR)
    return nil
  end

  next_id = next_id + 1
  local id = next_id
  local ms = math.max(1, math.floor(minutes * 60 * 1000 + 0.5))
  uv.update_time()
  timers[id] = {
    id = id,
    label = vim.trim(label or ""),
    minutes = minutes,
    deadline = uv.now() + ms,
    handle = handle,
  }
  handle:start(ms, 0, function()
    vim.schedule(function()
      finish(id)
    end)
  end)

  vim.notify(
    string.format("Timebox started: %s", describe(timers[id])),
    vim.log.levels.INFO
  )
  pcall(vim.cmd, "redrawstatus")
  return id
end

---Cancel one timer by id.
---@param id integer
---@return boolean cancelled False when no such timer is running.
function M.cancel(id)
  local t = timers[id]
  if not t then
    return false
  end
  timers[id] = nil
  close_handle(t.handle)
  vim.notify(string.format("Timebox cancelled: %s", describe(t)))
  pcall(vim.cmd, "redrawstatus")
  return true
end

---Cancel every running timer.
---@param silent boolean? Skip the notification (used on exit).
---@return integer count Number of timers cancelled.
function M.cancel_all(silent)
  local count = 0
  for id, t in pairs(timers) do
    timers[id] = nil
    close_handle(t.handle)
    count = count + 1
  end
  if not silent then
    vim.notify(string.format("Timebox: cancelled %d timer(s)", count))
    pcall(vim.cmd, "redrawstatus")
  end
  return count
end

---One line per running timer, soonest first ("#1 12:34 left  Write tests (25 min)").
---@return string[]
function M.lines()
  uv.update_time()
  local now = uv.now()
  local out = {}
  for _, t in ipairs(sorted()) do
    table.insert(
      out,
      string.format(
        "#%d %s left  %s",
        t.id,
        fmt_remaining(t.deadline - now),
        describe(t)
      )
    )
  end
  return out
end

---Notify a list of running timers with time remaining.
---@return nil
function M.list()
  local lines = M.lines()
  if #lines == 0 then
    vim.notify("Timebox: no timers running")
    return
  end
  vim.notify("Timebox:\n" .. table.concat(lines, "\n"))
end

---Pick a running timer with `vim.ui.select` and cancel it.
---@return nil
function M.pick_cancel()
  local list = sorted()
  if #list == 0 then
    vim.notify("Timebox: no timers running")
    return
  end
  uv.update_time()
  local now = uv.now()
  vim.ui.select(list, {
    prompt = "Cancel timebox",
    ---@param t Timebox.Timer
    format_item = function(t)
      return string.format(
        "%s left  %s",
        fmt_remaining(t.deadline - now),
        describe(t)
      )
    end,
  }, function(choice)
    if choice then
      M.cancel(choice.id)
    end
  end)
end

---Prompt for minutes, then a label, and start a timer.
---@return nil
function M.prompt_start()
  vim.ui.input({ prompt = "Timebox minutes: " }, function(minutes)
    if minutes == nil or vim.trim(minutes) == "" then
      return -- Aborted.
    end
    if not tonumber(minutes) then
      vim.notify("Timebox: not a number: " .. minutes, vim.log.levels.ERROR)
      return
    end
    vim.ui.input({ prompt = "Timebox label (optional): " }, function(label)
      if label == nil then
        return -- Aborted.
      end
      M.start(tonumber(minutes), label)
    end)
  end)
end

---Statusline snippet for the timer closest to finishing, e.g.
---"T 12:34 Write tests +1", or "" when nothing is running. Cheap: no sorting.
---@return string
function M.statusline()
  local soonest, count = nil, 0
  for _, t in pairs(timers) do
    count = count + 1
    if not soonest or t.deadline < soonest.deadline then
      soonest = t
    end
  end
  if not soonest then
    return ""
  end
  local s = "T " .. fmt_remaining(soonest.deadline - uv.now())
  if soonest.label ~= "" then
    -- Escape `%` so a label can't inject statusline format items.
    s = s .. " " .. soonest.label:gsub("%%", "%%%%")
  end
  if count > 1 then
    s = s .. " +" .. (count - 1)
  end
  return s
end

---Handle `:Timebox` arguments.
---@param args string Raw `<args>` string.
---@return nil
local function command(args)
  args = vim.trim(args)
  local first, rest = args:match("^(%S*)%s*(.-)$")
  if first == "" or first == "list" then
    M.list()
  elseif first == "cancel" then
    if rest == "all" then
      M.cancel_all()
    elseif rest == "" then
      M.pick_cancel()
    else
      vim.notify(
        "Timebox: usage is :Timebox cancel [all]",
        vim.log.levels.ERROR
      )
    end
  elseif tonumber(first) then
    M.start(tonumber(first), rest)
  else
    vim.notify(
      "Timebox: usage is :Timebox {minutes} [label] | list | cancel [all]",
      vim.log.levels.ERROR
    )
  end
end

---Completion for `:Timebox`.
---@param arglead string
---@param cmdline string
---@return string[]
local function complete(arglead, cmdline)
  local words = vim.split(vim.trim(cmdline), "%s+")
  -- Count the word currently being typed (cmdline ends in a space => new word).
  local n = #words + (cmdline:match("%s$") and 1 or 0)
  local candidates = {}
  if n == 2 then
    candidates = { "list", "cancel", "5", "15", "25", "50" }
  elseif n == 3 and words[2] == "cancel" then
    candidates = { "all" }
  end
  return vim.tbl_filter(function(c)
    return vim.startswith(c, arglead)
  end, candidates)
end

---Create `:Timebox` and the VimLeavePre cleanup. Safe to call more than once.
---@return nil
function M.setup()
  vim.api.nvim_create_user_command("Timebox", function(opts)
    command(opts.args)
  end, {
    nargs = "*",
    complete = complete,
    desc = "Timebox: {minutes} [label] | list | cancel [all]",
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("custom-timebox", { clear = true }),
    desc = "Stop and close all timebox timers",
    callback = function()
      M.cancel_all(true)
    end,
  })
end

return M
