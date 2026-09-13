vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set(
  "n",
  "<leader>q",
  vim.diagnostic.setloclist,
  { desc = "Open diagnostic [Q]uickfix list" }
)

vim.keymap.set(
  "t",
  "<Esc><Esc>",
  "<C-\\><C-n>",
  { desc = "Exit terminal mode" }
)

vim.keymap.set(
  "n",
  "<C-h>",
  "<C-w><C-h>",
  { desc = "Move focus to the left window" }
)
vim.keymap.set(
  "n",
  "<C-l>",
  "<C-w><C-l>",
  { desc = "Move focus to the right window" }
)
vim.keymap.set(
  "n",
  "<C-j>",
  "<C-w><C-j>",
  { desc = "Move focus to the lower window" }
)
vim.keymap.set(
  "n",
  "<C-k>",
  "<C-w><C-k>",
  { desc = "Move focus to the upper window" }
)

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup(
    "kickstart-highlight-yank",
    { clear = true }
  ),
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.keymap.set("i", "jk", "<Esc>", {
  silent = true,
})

vim.keymap.set("i", "kj", "<Esc>", {
  silent = true,
})

local toggle_wrap = function()
  vim.wo.wrap = not vim.wo.wrap
  if vim.wo.wrap then
    vim.notify("[toggle_wrap] word wrap enabled", vim.log.levels.WARN)
  else
    vim.notify("[toggle_wrap] word wrap disabled", vim.log.levels.WARN)
  end
end

vim.keymap.set("n", "<leader>w", toggle_wrap)

-- Neovide-only: adjust the font size (zoom) at runtime with Ctrl + + / Ctrl + -.
-- vim.g.neovide is set only when running inside Neovide, so these mappings do
-- not exist in the terminal or other GUIs. Zoom is done via the scale factor so
-- it works regardless of which guifont (if any) is configured.
if vim.g.neovide then
  vim.g.neovide_scale_factor = vim.g.neovide_scale_factor or 1.0

  local function change_scale_factor(delta)
    vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
  end

  local modes = { "n", "i", "v" }

  -- `+` is Shift+`=`, so also bind `<C-=>` for keyboards/layouts where pressing
  -- Ctrl with the unshifted key is more convenient.
  for _, lhs in ipairs({ "<C-+>", "<C-=>" }) do
    vim.keymap.set(modes, lhs, function()
      change_scale_factor(1.1)
    end, { desc = "Neovide: increase font size" })
  end

  vim.keymap.set(modes, "<C-->", function()
    change_scale_factor(1 / 1.1)
  end, { desc = "Neovide: decrease font size" })
end
