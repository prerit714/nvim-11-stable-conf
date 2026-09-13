# nvim-11-stable-conf

A personalized, stable Neovim configuration built on top of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim), optimized for the latest stable Neovim. It is minimal yet powerful, with sensible defaults, modern LSP integration, a fully text-based UI (no icons / Nerd Font required), and a curated set of plugins for a smooth editing experience.

---

## Requirements

- [Neovim](https://neovim.io/) — **latest stable** (>= **0.12.0**)
- [Git](https://git-scm.com/)
- A C compiler and the [`tree-sitter` CLI](https://github.com/tree-sitter/tree-sitter) (for `nvim-treesitter` parsers)

> This config is entirely text-based, so a Nerd Font is **not** required.

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
- **Git:** [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) + [lazygit](https://github.com/kdheepak/lazygit.nvim) + [vim-fugitive](https://github.com/tpope/vim-fugitive)
- **Fuzzy Finder:** [fff.nvim](https://github.com/dmtrKovalenko/fff.nvim) for file/grep operations, with [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) as the fallback picker
- **File Tree:** [oil.nvim](https://github.com/stevearc/oil.nvim)
- **Treesitter:** [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- **AI Copilot:** [copilot.lua](https://github.com/zbirenbaum/copilot.lua) (disabled by default on startup)
- **Harpoon:** [harpoon](https://github.com/ThePrimeagen/harpoon) for quick file navigation
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

This config targets the **latest stable** Neovim (the Cloud Agent environment
installs it from the `stable` release channel). It has been validated on:

```
NVIM v0.12.5
Build type: Release
LuaJIT 2.1.1774638290
```

---

## License

This project is released under the [MIT License](LICENSE).

---

> Inspired by [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) and tailored for daily use.
