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

### Git changes review

`<leader>gc` (uncommitted vs `HEAD`, incl. untracked; inside the diff tab it reuses that tab's base), `<leader>gC` (vs merge-base with the default branch) and `:GitChanges [ref]` open a Telescope picker of changed files with a unified-diff preview — meant for reviewing edits made by the AI TUIs. fff.nvim has no custom-source API, hence Telescope.

Nothing blocks the UI: all git work is async.

- `lua/custom/git_changes/git.lua` — coroutine-based helpers. `git.run`/`git.run_all` only work inside `git.async(fn)`: they yield until the `vim.system` process(es) exit and resume via `vim.schedule`, so code after them is on the main loop. Commands run with `cwd` = repo root (paths are root-relative). `git.root()` uses `vim.fs.root` and spawns no process.
- `lua/custom/git_changes/picker.lua` — `open` must run inside `git.async`. It fetches changes, then builds the Telescope picker in a fresh `vim.schedule` tick, because Telescope runs its own plenary.async coroutines. Previews are async and cached per path. Keys: `<CR>` side-by-side diff, `<C-e>` edit file, `<C-s>` stage/unstage toggle.
- `lua/custom/git_changes/view.lua` — a single reused diff tabpage with two layouts, toggled by buffer-local `<leader>gv` (the choice persists):
  - **inline** (default): the real file in one window. Hunks come from `vim.text.diff(..., { result_type = "indices" })`; added/changed lines get `DiffAdd` line highlights and removed lines are `DiffDelete` `virt_lines`. They are redrawn (debounced) on `TextChanged`/`WinResized`, and `]c`/`[c` jump between these hunks.
  - **split**: a read-only `gitchanges://<base>/<path>` scratch buffer on the left plus native diff mode.
  - The base text arrives asynchronously, and a generation counter drops stale results.
  - Files are shown with `bufadd` + `nvim_win_set_buf` (never `:edit`, which would prompt on unsaved changes).
  - Buffer-local view maps (`]f`/`[f`/`q`/`<leader>gv`, inline `]c`/`[c`) save any buffer-local map they shadow (e.g. gitsigns' `]c`) and restore it with `mapset` when the view moves on or closes.
- `lua/custom/plugins/git-changes.lua` — local lazy spec (dir `git-changes-lazy/`, per the gotcha above) binding the keys and defining `:GitChanges`. Ref completion is served from an async-refreshed cache.

### Merge conflicts

`lua/custom/plugins/fugitive.lua` holds the conflict keys; `lua/custom/git_conflict.lua` holds the logic. The fugitive spec's `init` calls `git_conflict.setup()` at startup, which installs autocmds that highlight conflict markers inline: ours `DiffAdd`, diff3 base `DiffDelete`, theirs `DiffChange`, with key hints on the marker lines.

- `<leader>gq`: `:Git mergetool` (all conflicts into quickfix).
- `<leader>gm`: `:Gvdiffsplit!` (ours `//2` | working copy | theirs `//3`).
- `]x` / `[x`: jump between conflicts.
- `<leader>go` / `gt` / `ga` / `gx`: take ours / theirs / both / none for the block under the cursor. This is marker-based, so it works in plain buffers and in the 3-way middle window. In a diff window with no marker under the cursor, it falls back to `:diffget //2` / `//3`.
- `<leader>gw`: `:Gwrite` (stage the file, i.e. mark it resolved).

`diffopt` adds `vertical` and `algorithm:histogram` (in `options.lua`).

### Timebox

`lua/custom/timebox.lua` holds the logic and `lua/custom/plugins/timebox.lua` is a local lazy spec (dir `timebox-lazy/`). Together they provide `:Timebox {minutes} [label] | list | cancel [all]` and the `<leader>T` keys.
- Timers are one-shot `vim.uv` timers that are closed on finish, on cancel and on `VimLeavePre`. A finished timer shows a WARN notification and rings the terminal bell.
- `mini.lua` calls `timebox.statusline()` only when `package.loaded["custom.timebox"]` is set, so the module never loads at startup.

### Pinned dirs / start screen

The start screen is `mini.starter`, set up in `mini.lua`. It auto-opens only when there are no file args, so `nvim .` still opens Oil. Its first section comes from `lua/custom/pinned_dirs.lua`. `lua/custom/plugins/pinned-dirs.lua` is a local lazy spec (dir `pinned-dirs-lazy/`): its `init` calls `pinned_dirs.setup()`, and it binds `<leader>pp` (toggle pin of the current project root), `<leader>pl` (pick a pinned dir) and `<leader>ps` (open the start screen).
- Pins are stored in `stdpath("data")/pinned_dirs.json`. The file is read lazily, because the module is required at startup. Paths are normalized and compared case-insensitively on Windows.
- A `BufEnter` autocmd (augroup `PinnedDirs`) global-`:cd`s into the longest pinned dir that contains the file. It applies only to `buftype == ""` buffers without a URI scheme, and it skips windows that have a local dir. fff.nvim re-indexes on its own via its global `DirChanged` autocmd, so there is no need to call it.

### Startup / lazy-loading

Keep the startup path light: nvim-lspconfig (and with it mason, fidget, blink.cmp) loads on `BufReadPre`/`BufNewFile`, nvim-java on `ft = "java"` (jdtls is excluded from mason-lspconfig's `automatic_enable` so nvim-java enables it after its setup), and telescope/which-key on `VeryLazy`. Plugin keymaps belong in lazy `keys` specs, not in `config`, so they work before the plugin loads.
