# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Neovim config (Lua) derived from kickstart.nvim, targeting the latest stable Neovim (>= 0.12 — the unpinned `nvim-treesitter` `main` branch depends on 0.12 APIs). There is no build and no test suite; "verifying" a change means loading it in Neovim.

## Commands

```sh
# Format Lua (uses stylua.toml: 80 cols, 2-space indent, double quotes, call parens always)
stylua .
stylua --check .

# Headless smoke test: load the whole config and surface startup errors
nvim --headless "+qa"

# Install/update plugins headlessly
nvim --headless "+Lazy! sync" +qa

# Health checks (includes lua/kickstart/health.lua)
nvim --headless "+checkhealth" +qa
```

`.cursor/install.sh` is the idempotent Linux cloud-agent setup: installs Neovim stable, stylua, the tree-sitter CLI, mise tools (`mise.toml`: bun, go, node), `cursor-agent`, symlinks the repo to `~/.config/nvim`, and bootstraps plugins + parsers headlessly.

## Architecture

Load order from `init.lua`: sets leader to space and transparent highlights, then `options` → `keymaps` → `lazy-bootstrap` (clones lazy.nvim) → `lazy-plugins`.

- `lua/lazy-plugins.lua` explicitly `require`s each `kickstart.plugins.*` spec, then `{ import = "custom.plugins" }` auto-imports **every** file in `lua/custom/plugins/`. New kickstart-style plugins must be added to the list by hand; new custom plugins just need a file in `lua/custom/plugins/` returning a `LazySpec`.
- The config is deliberately text-only (`vim.g.have_nerd_font = false`, ASCII lazy.nvim UI icons in `lazy-plugins.lua`). Don't introduce Nerd Font glyphs or icon dependencies.
- Filetype indentation is enforced by a `FileType` autocmd table in `lua/options.lua`, not by per-ftplugin files.
- Formatting (`conform.lua`) has format-on-save disabled via a local `autoformat = false`; formatting is manual on `<leader>bf`. Formatter/linter binaries are installed through Mason's `ensure_installed` list in `lspconfig.lua`.
- `lazy-lock.json` is gitignored, so plugin versions are not pinned in the repo.

### AI TUI floating terminals

Four CLIs (`cursor-agent`, `opencode`, `claude`, `codex`) open in lazygit-style floats on `<leader>1`–`<leader>4`. This spans three layers:

1. `lua/custom/float_term.lua` — the shared launcher. `create({ command, name })` returns an independent `{ open, hide, toggle, on_resize }` object with its own buffer/window/job state and its own `VimResized` augroup. It reuses the terminal buffer across toggles, deletes it when the process exits, and sets only buffer-local maps (`q` in normal mode hides; `<Esc><Esc>` leaves terminal mode).
2. `lua/custom/<tool>.lua` — a one-line wrapper calling `float_term.create` for that CLI.
3. `lua/custom/plugins/<tool>.lua` — a dependency-free local lazy spec that binds the key and lazy-loads the wrapper.

**Gotcha:** lazy.nvim keys local plugins by `dir`, so specs sharing a `dir` get merged. Each launcher spec needs a distinct `dir`. That is why the empty `claude-lazy/` and `codex-lazy/` directories exist; cursor-agent uses the config root and opencode uses `lua/custom`. A new launcher should add its own `<tool>-lazy/init.lua` (returning `{}`) and point `dir` at it.