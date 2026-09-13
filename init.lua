vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.cmd([[
  highlight Normal guibg=NONE ctermbg=NONE
  highlight NonText guibg=NONE ctermbg=NONE
  highlight SignColumn guibg=NONE ctermbg=NONE
  highlight NormalFloat guibg=NONE ctermbg=NONE
  highlight FloatBorder guibg=NONE ctermbg=NONE
]])

vim.g.have_nerd_font = false
vim.o.winborder = "single"
require("options")
require("keymaps")
require("lazy-bootstrap")
require("lazy-plugins")
