vim.o.number = true

vim.o.mouse = "a"

vim.o.showmode = false

vim.schedule(function()
  vim.o.clipboard = "unnamedplus"
end)

vim.o.breakindent = true

vim.o.undofile = true

vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.signcolumn = "yes"

vim.o.updatetime = 250

vim.o.timeoutlen = 300

vim.o.splitright = true
vim.o.splitbelow = true

vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.o.inccommand = "split"

vim.o.cursorline = true

vim.o.scrolloff = 10

vim.o.confirm = true

vim.cmd([[
  highlight Normal guibg=NONE ctermbg=NONE
  highlight NonText guibg=NONE ctermbg=NONE
  highlight SignColumn guibg=NONE ctermbg=NONE
  highlight NormalFloat guibg=NONE ctermbg=NONE
  highlight FloatBorder guibg=NONE ctermbg=NONE
]])

vim.o.wrap = false
vim.o.colorcolumn = "80"

---@diagnostic disable-next-line: param-type-mismatch
vim.api.nvim_create_autocmd("VimResized", {
  pattern = "*",
  callback = function()
    vim.cmd("wincmd =")
  end,
})

vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { silent = true })

local indent_group =
  vim.api.nvim_create_augroup("FileTypeIndent", { clear = true })

vim.filetype.add({
  extension = {
    prisma = "prisma",
  },
})

local filetype_settings = {
  javascript = {
    expandtab = true,
    shiftwidth = 2,
    tabstop = 2,
    softtabstop = 2,
  },
  typescript = {
    expandtab = true,
    shiftwidth = 2,
    tabstop = 2,
    softtabstop = 2,
  },
  typescriptreact = {
    expandtab = true,
    shiftwidth = 2,
    tabstop = 2,
    softtabstop = 2,
  },
  css = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },
  scss = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },
  json = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },
  yaml = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },
  vue = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },
  svelte = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },
  prisma = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },

  python = { expandtab = true, shiftwidth = 4, tabstop = 4, softtabstop = 4 },

  lua = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },

  go = { expandtab = false, shiftwidth = 4, tabstop = 4, softtabstop = 4 },
  templ = { expandtab = false, shiftwidth = 4, tabstop = 4, softtabstop = 4 },

  c = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },
  cpp = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },

  rust = { expandtab = true, shiftwidth = 4, tabstop = 4, softtabstop = 4 },

  java = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },

  sh = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },
  bash = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },
  zsh = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },

  ruby = { expandtab = true, shiftwidth = 2, tabstop = 2, softtabstop = 2 },

  php = { expandtab = true, shiftwidth = 4, tabstop = 4, softtabstop = 4 },

  markdown = { expandtab = true, shiftwidth = 4, tabstop = 4, softtabstop = 4 },

  make = { expandtab = false, shiftwidth = 4, tabstop = 4, softtabstop = 0 },

  xml = { expandtab = true, shiftwidth = 4, tabstop = 4, softtabstop = 4 },
  html = { expandtab = true, shiftwidth = 4, tabstop = 4, softtabstop = 4 },

  groovy = { expandtab = true, shiftwidth = 4, tabstop = 4, softtabstop = 4 },
}

local function set_indent_settings(settings)
  for option, value in pairs(settings) do
    vim.opt_local[option] = value
  end
end

for filetype, settings in pairs(filetype_settings) do
  vim.api.nvim_create_autocmd("FileType", {
    group = indent_group,
    pattern = filetype,
    callback = function()
      set_indent_settings(settings)
    end,
    desc = string.format("Set indentation for %s files", filetype),
  })
end
