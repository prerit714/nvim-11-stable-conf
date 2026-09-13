#!/usr/bin/env bash
# Idempotent Cloud Agent setup for this Neovim configuration.
# Installs the editor + toolchain, links the config, and bootstraps plugins.
set -euo pipefail

# Neovim tracks the latest stable release. It must stay recent enough for the
# unpinned nvim-treesitter `main` branch (it relies on the 0.12 `vim.list` API),
# so the `stable` channel is used rather than a pinned 0.11.x build.
NVIM_CHANNEL="stable"
STYLUA_VERSION="v2.5.2"
TREE_SITTER_VERSION="v0.27.0"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\n=== %s ===\n' "$*"; }

install_release_binary() {
  # Downloads a GitHub release asset into a temp dir and echoes the file path.
  local url="$1" out="$2"
  curl -fsSL -o "$out" "$url"
}

log "System packages (python venv for Mason-installed Python tools)"
# Mason builds a venv to install the Python formatters/linters (black, isort,
# pylint). The base image ships Python without ensurepip/venv, so install it
# idempotently before any Neovim/plugin bootstrap runs.
if ! python3 -c "import ensurepip" >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y python3-venv
fi

log "Neovim (latest ${NVIM_CHANNEL})"
tmp="$(mktemp -d)"
install_release_binary \
  "https://github.com/neovim/neovim/releases/download/${NVIM_CHANNEL}/nvim-linux-x86_64.tar.gz" \
  "${tmp}/nvim.tar.gz"
tar -C "${tmp}" -xzf "${tmp}/nvim.tar.gz"
new_ver="$("${tmp}/nvim-linux-x86_64/bin/nvim" --version | head -1)"
cur_ver=""
if command -v nvim >/dev/null 2>&1; then
  cur_ver="$(nvim --version | head -1)"
fi
if [ "${new_ver}" != "${cur_ver}" ]; then
  echo "Installing ${new_ver} (was: ${cur_ver:-none})"
  sudo rm -rf /opt/nvim-linux-x86_64
  sudo mv "${tmp}/nvim-linux-x86_64" /opt/nvim-linux-x86_64
  sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
else
  echo "${new_ver} already present."
fi
rm -rf "${tmp}"

log "stylua ${STYLUA_VERSION}"
if command -v stylua >/dev/null 2>&1 && stylua --version | grep -q "${STYLUA_VERSION#v}"; then
  echo "stylua ${STYLUA_VERSION} already present."
else
  tmp="$(mktemp -d)"
  install_release_binary \
    "https://github.com/JohnnyMorganz/StyLua/releases/download/${STYLUA_VERSION}/stylua-linux-x86_64.zip" \
    "${tmp}/stylua.zip"
  unzip -o "${tmp}/stylua.zip" -d "${tmp}" >/dev/null
  sudo install -m 0755 "${tmp}/stylua" /usr/local/bin/stylua
  rm -rf "${tmp}"
fi

log "tree-sitter CLI ${TREE_SITTER_VERSION}"
if command -v tree-sitter >/dev/null 2>&1 && tree-sitter --version | grep -q "${TREE_SITTER_VERSION#v}"; then
  echo "tree-sitter ${TREE_SITTER_VERSION} already present."
else
  tmp="$(mktemp -d)"
  install_release_binary \
    "https://github.com/tree-sitter/tree-sitter/releases/download/${TREE_SITTER_VERSION}/tree-sitter-linux-x64.gz" \
    "${tmp}/tree-sitter.gz"
  gunzip -f "${tmp}/tree-sitter.gz"
  sudo install -m 0755 "${tmp}/tree-sitter" /usr/local/bin/tree-sitter
  rm -rf "${tmp}"
fi

log "mise + repo-pinned tools (mise.toml)"
if [ ! -x "${HOME}/.local/bin/mise" ] && ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | sh
fi
export PATH="${HOME}/.local/bin:${PATH}"
# mise needs a shell hook to expose its shims to interactive agent shells.
if ! grep -qs 'mise activate bash' "${HOME}/.bashrc"; then
  {
    echo ''
    echo '# Added by nvim-11-stable-conf Cloud Agent setup'
    echo 'export PATH="$HOME/.local/bin:$PATH"'
    echo 'eval "$(mise activate bash)"'
  } >> "${HOME}/.bashrc"
fi
mise trust "${REPO_DIR}/mise.toml" >/dev/null 2>&1 || true
(cd "${REPO_DIR}" && mise install)

log "Cursor CLI (cursor-agent)"
# The <leader>a launcher runs `cursor-agent` in a floating terminal, so the CLI
# has to be on PATH. The installer drops it in ~/.local/bin (already exported
# above). Auth is handled interactively by the user; this only ensures the
# binary exists. Skip the network fetch when it is already installed.
if command -v cursor-agent >/dev/null 2>&1; then
  echo "cursor-agent already present ($(command -v cursor-agent))."
else
  curl https://cursor.com/install -fsS | bash
fi

log "Linking ${REPO_DIR} -> ~/.config/nvim"
mkdir -p "${HOME}/.config"
if [ "$(readlink -f "${HOME}/.config/nvim" 2>/dev/null || true)" != "${REPO_DIR}" ]; then
  rm -rf "${HOME}/.config/nvim"
  ln -s "${REPO_DIR}" "${HOME}/.config/nvim"
fi

log "Bootstrapping plugins (lazy.nvim sync)"
nvim --headless "+Lazy! sync" +qa

log "Installing tree-sitter parsers"
# The treesitter config triggers an async install on startup; wait for the
# installed-parser count to settle instead of hard-coding the language list.
nvim --headless '+lua
local ts = require("nvim-treesitter")
local last, stable = -1, 0
vim.wait(280000, function()
  local n = #ts.get_installed("parsers")
  if n == last then stable = stable + 1 else stable, last = 0, n end
  return n > 0 and stable >= 5
end, 1000)
io.write("treesitter parsers installed: " .. #ts.get_installed("parsers") .. "\n")
' +qa

log "Setup complete"
