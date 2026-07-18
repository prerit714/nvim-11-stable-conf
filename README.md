# nvim-11-stable-conf

A personalized, stable Neovim configuration built on top of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim), optimized for Neovim 0.11+. It is minimal yet powerful, with sensible defaults, modern LSP integration, and a curated set of plugins for a smooth editing experience.

---

## Requirements

- [Neovim](https://neovim.io/) >= **0.11.0**
- [Git](https://git-scm.com/)
- [Nerd Font](https://www.nerdfonts.com/) (for icons and glyphs)
- A C compiler (for `nvim-treesitter` parsers)

---

## Installation

### Linux / macOS

```bash
git clone git@github.com:prerit714/nvim-11-stable-conf.git ~/.config/nvim
```

Then start Neovim:

```bash
nvim
```

`lazy.nvim` will automatically bootstrap itself and install all plugins on the first run.

---

## Structure

```
~/.config/nvim/
├── init.lua                 # Entry point
├── lua/
│   ├── options.lua          # Vim options, indentation rules, transparency
│   ├── keymaps.lua          # Custom keymaps
│   ├── lazy-bootstrap.lua   # Plugin manager bootstrap
│   ├── lazy-plugins.lua     # Plugin definitions
│   ├── kickstart/
│   │   └── plugins/         # Core plugins (LSP, Treesitter, etc.)
│   └── custom/
│       └── plugins/         # User-defined plugins
├── doc/                     # Documentation
└── lazy-lock.json           # Plugin lockfile
```

---

## Key Features

- **Plugin Manager:** [lazy.nvim](https://github.com/folke/lazy.nvim) — fast, modern, and lockfile-friendly
- **LSP:** [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) + [blink.cmp](https://github.com/Saghen/blink.cmp) for completion
- **Formatting:** [conform.nvim](https://github.com/stevearc/conform.nvim)
- **Linting:** [nvim-lint](https://github.com/mfussenegger/nvim-lint)
- **Git:** [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) + [lazygit](https://github.com/kdheepak/lazygit.nvim)
- **Fuzzy Finder:** [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- **File Tree:** [oil.nvim](https://github.com/stevearc/oil.nvim)
- **Treesitter:** [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- **AI Copilot:** [copilot.lua](https://github.com/zbirenbaum/copilot.lua) (disabled by default on startup)
- **Harpoon:** [harpoon](https://github.com/ThePrimeagen/harpoon) for quick file navigation
- **API Testing:** [kulala](https://github.com/mistweaverco/kulala.nvim)
- **Search & Replace:** [grug-far](https://github.com/MagicDuck/grug-far.nvim)
- **Markdown Preview:** [render-markdown](https://github.com/MeanderingProgrammer/render-markdown.nvim)
- **Color Scheme:** Tokyonight (with transparent background support)

---

## Key Mappings

| Key | Mode | Action |
|-----|------|--------|
| `<leader>` | Normal | Space |
| `jk` / `kj` | Insert | Exit insert mode |
| `<Esc>` | Normal | Clear search highlight |
| `<C-h/j/k/l>` | Normal | Navigate splits |
| `<leader>w` | Normal | Toggle word wrap |
| `<leader>q` | Normal | Open diagnostic quickfix |
| `<leader>d` | Normal | Open diagnostic float |
| `<Esc><Esc>` | Terminal | Exit terminal mode |

> Use `<leader>?` or run `:WhichKey` to explore more mappings dynamically.

---

## Filetype Indentation

This configuration enforces consistent indentation across languages:

| Language | Indent |
|----------|--------|
| JS/TS, CSS, SCSS, Vue, Svelte, YAML, JSON, Lua, HTML | 2 spaces |
| Python, Rust, PHP, Markdown, Groovy, XML | 4 spaces |
| Go, Templ | Tabs |
| Make | Tabs (no expand) |

---

## About the Neovim Version Used

```
NVIM v0.11.6
Build type: Release
LuaJIT 2.1.1741730670
```

---

## License

This project is released under the [MIT License](LICENSE).

---

> Inspired by [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) and tailored for daily use.
