#!/usr/bin/env bash
# install.sh - install the command-line tools these dotfiles expect into ~/.local (no sudo needed).
#
#   ./install.sh                 install or update everything
#   ./install.sh neovim fzf      only the named tools
#
# Every download is checked against the SHA-256 its publisher lists before anything is unpacked.
# Run it again any time to update to the latest releases.
#
# Needs these from apt first (once):
#   sudo apt install stow wl-clipboard tmux git curl build-essential
set -euo pipefail

PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
OPT="$PREFIX/opt"
FONTS="$PREFIX/share/fonts"
mkdir -p "$BIN" "$OPT" "$FONTS"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# gh_asset OWNER/REPO REGEX  ->  "tag url sha256" of the newest release asset whose name matches REGEX
gh_asset() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" | python3 -I -c '
import json, re, sys
release = json.load(sys.stdin)
for asset in release["assets"]:
    if re.search(sys.argv[1], asset["name"]):
        print(release["tag_name"], asset["browser_download_url"], (asset.get("digest") or "-").removeprefix("sha256:"))
        break
else:
    sys.exit("no release asset matching " + sys.argv[1])
' "$2"
}

# fetch URL SHA256 FILE  ->  download URL to FILE and stop unless the checksum matches
fetch() {
  if [ -z "$2" ] || [ "$2" = "-" ]; then echo "no published checksum for $1, refusing to install" >&2; exit 1; fi
  curl -fsSL -o "$3" "$1"
  echo "$2  $3" | sha256sum -c --quiet -
}

install_neovim() {
  local out tag url sha
  out=$(gh_asset neovim/neovim '^nvim-linux-x86_64\.tar\.gz$'); read -r tag url sha <<<"$out"
  fetch "$url" "$sha" "$WORK/nvim.tar.gz"
  rm -rf "$OPT/nvim" && mkdir -p "$OPT/nvim"
  tar -xzf "$WORK/nvim.tar.gz" -C "$OPT/nvim" --strip-components=1
  ln -sf "$OPT/nvim/bin/nvim" "$BIN/nvim"
  echo "neovim     $tag"
}

install_lazygit() {
  local out tag url sha
  out=$(gh_asset jesseduffield/lazygit '_[Ll]inux_x86_64\.tar\.gz$'); read -r tag url sha <<<"$out"
  fetch "$url" "$sha" "$WORK/lazygit.tar.gz"
  tar -xzf "$WORK/lazygit.tar.gz" -C "$WORK" lazygit
  install -m 755 "$WORK/lazygit" "$BIN/lazygit"
  echo "lazygit    $tag"
}

install_fzf() {
  local out tag url sha
  out=$(gh_asset junegunn/fzf '-linux_amd64\.tar\.gz$'); read -r tag url sha <<<"$out"
  fetch "$url" "$sha" "$WORK/fzf.tar.gz"
  tar -xzf "$WORK/fzf.tar.gz" -C "$WORK" fzf
  install -m 755 "$WORK/fzf" "$BIN/fzf"
  echo "fzf        $tag"
}

# nvim-treesitter uses it to build language parsers. On Ubuntu 22.04 it prints
# "weak version `GLIBC_2.39' not found" but still runs and builds parsers correctly.
install_tree_sitter() {
  local out tag url sha
  out=$(gh_asset tree-sitter/tree-sitter '^tree-sitter-linux-x64\.gz$'); read -r tag url sha <<<"$out"
  fetch "$url" "$sha" "$WORK/tree-sitter.gz"
  gunzip -c "$WORK/tree-sitter.gz" > "$WORK/tree-sitter"
  install -m 755 "$WORK/tree-sitter" "$BIN/tree-sitter"
  echo "tree-sitter $tag"
}

install_node() {          # language servers installed by nvim's Mason need a current Node
  local ver name sha
  ver=$(curl -fsSL https://nodejs.org/dist/index.json |
        python3 -I -c 'import json, sys; print(next(r["version"] for r in json.load(sys.stdin) if r["lts"]))')
  name="node-$ver-linux-x64.tar.xz"
  sha=$(curl -fsSL "https://nodejs.org/dist/$ver/SHASUMS256.txt" | awk -v n="$name" '$2 == n { print $1 }')
  fetch "https://nodejs.org/dist/$ver/$name" "$sha" "$WORK/node.tar.xz"
  rm -rf "$OPT/node" && mkdir -p "$OPT/node"
  tar -xJf "$WORK/node.tar.xz" -C "$OPT/node" --strip-components=1
  for b in node npm npx; do ln -sf "$OPT/node/bin/$b" "$BIN/$b"; done
  echo "node       $ver (LTS)"
}

install_font() {          # icons in LazyVim and lazygit; pick "JetBrainsMono Nerd Font" in your terminal
  local out tag url sha
  out=$(gh_asset ryanoasis/nerd-fonts '^JetBrainsMono\.tar\.xz$'); read -r tag url sha <<<"$out"
  fetch "$url" "$sha" "$WORK/font.tar.xz"
  rm -rf "$FONTS/JetBrainsMonoNerdFont" && mkdir -p "$FONTS/JetBrainsMonoNerdFont"
  tar -xJf "$WORK/font.tar.xz" -C "$FONTS/JetBrainsMonoNerdFont" --wildcards '*.ttf'
  fc-cache -f "$FONTS" >/dev/null
  echo "font       JetBrainsMono Nerd Font $tag"
}

# ripgrep and fd: static (musl) builds, because Ubuntu 22.04's fd is too old for LazyVim (needs >= 8.4)
install_ripgrep() {
  local out tag url sha
  out=$(gh_asset BurntSushi/ripgrep 'x86_64-unknown-linux-musl\.tar\.gz$'); read -r tag url sha <<<"$out"
  fetch "$url" "$sha" "$WORK/rg.tar.gz"
  tar -xzf "$WORK/rg.tar.gz" -C "$WORK" --strip-components=1 --wildcards '*/rg'
  install -m 755 "$WORK/rg" "$BIN/rg"
  echo "ripgrep    $tag"
}

install_fd() {
  local out tag url sha
  out=$(gh_asset sharkdp/fd 'x86_64-unknown-linux-musl\.tar\.gz$'); read -r tag url sha <<<"$out"
  fetch "$url" "$sha" "$WORK/fd.tar.gz"
  tar -xzf "$WORK/fd.tar.gz" -C "$WORK" --strip-components=1 --wildcards '*/fd'
  rm -f "$BIN/fd" && install -m 755 "$WORK/fd" "$BIN/fd"
  echo "fd         $tag"
}

# GitHub CLI: logs in to GitHub and acts as git's credential helper (see git/.gitconfig).
# Left alone if gh came from somewhere else, e.g. GitHub's apt repository.
install_gh() {
  local out tag url sha existing
  existing="$(command -v gh || true)"
  if [ -n "$existing" ] && [ "$existing" != "$BIN/gh" ]; then echo "gh         already installed at $existing"; return; fi
  out=$(gh_asset cli/cli '_linux_amd64\.tar\.gz$'); read -r tag url sha <<<"$out"
  fetch "$url" "$sha" "$WORK/gh.tar.gz"
  tar -xzf "$WORK/gh.tar.gz" -C "$WORK" --strip-components=2 --wildcards '*/bin/gh'
  install -m 755 "$WORK/gh" "$BIN/gh"
  echo "gh         $tag"
}

# Pre-install LazyVim's plugins, syntax parsers and language servers, so the first launch is ready to use.
# (Mason skips its automatic installs in headless mode, so the language servers are named here.)
nvim_plugins() {
  if [ ! -f "$HOME/.config/nvim/init.lua" ]; then echo "nvim       no config linked yet (run: stow nvim), skipping plugins"; return; fi
  "$BIN/nvim" --headless "+Lazy! sync" +qa >/dev/null 2>&1
  "$BIN/nvim" --headless -c "lua require('lazy').load({ plugins = { 'mason.nvim' } })" \
    -c "MasonInstall clangd pyright ruff lua-language-server marksman json-lsp yaml-language-server taplo neocmakelsp" \
    -c "qa!" >/dev/null 2>&1 || true
  "$BIN/nvim" --headless \
    -c "lua require('lazy').load({ plugins = { 'nvim-treesitter' } }); require('nvim-treesitter').install(LazyVim.opts('nvim-treesitter').ensure_installed):wait(300000)" \
    -c "qa!" >/dev/null 2>&1 || true
  echo "nvim       plugins, syntax parsers and language servers installed"
}

ALL=(neovim lazygit fzf tree_sitter node font ripgrep fd gh nvim_plugins)
TOOLS=("${@:-${ALL[@]}}")
for t in "${TOOLS[@]}"; do
  case "${t//-/_}" in
    neovim|nvim)  install_neovim ;;
    lazygit)      install_lazygit ;;
    fzf)          install_fzf ;;
    tree_sitter)  install_tree_sitter ;;
    node)         install_node ;;
    font)         install_font ;;
    ripgrep|rg)   install_ripgrep ;;
    fd)           install_fd ;;
    gh)           install_gh ;;
    nvim_plugins) nvim_plugins ;;
    *) echo "unknown tool: $t (choose from: ${ALL[*]})" >&2; exit 1 ;;
  esac
done
