#!/usr/bin/env bash
# Idempotent Cloud Agent setup for this Neovim configuration.
# Installs the editor + toolchain, links the config, and bootstraps plugins.
set -euo pipefail

# Pinned to the versions this environment was validated against. Neovim must be
# recent enough for the unpinned nvim-treesitter `main` branch (it relies on the
# 0.12 `vim.list` API), so a 0.11.x build is intentionally not used here.
NVIM_VERSION="v0.12.5"
STYLUA_VERSION="v2.5.2"
TREE_SITTER_VERSION="v0.27.0"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\n=== %s ===\n' "$*"; }

install_release_binary() {
  # Downloads a GitHub release asset into a temp dir and echoes the file path.
  local url="$1" out="$2"
  curl -fsSL -o "$out" "$url"
}

log "Neovim ${NVIM_VERSION}"
if command -v nvim >/dev/null 2>&1 && nvim --version | head -1 | grep -q "NVIM ${NVIM_VERSION}"; then
  echo "Neovim ${NVIM_VERSION} already present."
else
  tmp="$(mktemp -d)"
  install_release_binary \
    "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
    "${tmp}/nvim.tar.gz"
  sudo rm -rf /opt/nvim-linux-x86_64
  sudo tar -C /opt -xzf "${tmp}/nvim.tar.gz"
  sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  rm -rf "${tmp}"
fi

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
