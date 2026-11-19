#!/usr/bin/env bash
# bootstrap.sh - set up a fresh Ubuntu machine: packages, tools, configs, Claude Code, private workspace.
#
#   git clone https://github.com/ShengBin-101/dotfiles ~/dotfiles && ~/dotfiles/bootstrap.sh
#
# Safe to re-run: each step skips what's already done. Config files already on the machine are moved
# to ~/.dotfiles-backup/<timestamp>/ before being replaced, never deleted.
#
# Options:
#   --no-apt         skip apt packages (no sudo needed)
#   --no-tools       skip ./install.sh (nvim, lazygit, fzf, node, ... into ~/.local)
#   --no-claude      skip installing Claude Code
#   --no-workspace   skip GitHub login and the private workspace
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WORKSPACE_REPO="ShengBin-101/claude-workspace"
# Keep ~/Desktop: Claude Code keys each folder's memory to its path, and the CLAUDE.md files refer to it.
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/Desktop}"

PACKAGES=(bash tmux git nvim claude)
# What those packages put in ~ (keep in sync when adding a package). Anything here that isn't already
# a link into this repo gets moved to the backup folder first.
TARGETS=(.bashrc .tmux.conf .gitconfig .config/nvim .claude/settings.json)
APT_PACKAGES=(stow tmux git curl ca-certificates build-essential unzip xz-utils python3 python3-venv fontconfig wl-clipboard xclip)
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

do_apt=1 do_tools=1 do_claude=1 do_workspace=1
for arg in "$@"; do
  case "$arg" in
    --no-apt) do_apt=0 ;;
    --no-tools) do_tools=0 ;;
    --no-claude) do_claude=0 ;;
    --no-workspace) do_workspace=0 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 1 ;;
  esac
done

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------- 1. apt packages
if [ "$do_apt" = 1 ]; then
  step "apt packages"
  missing=()
  for p in "${APT_PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "ok installed" || missing+=("$p")
  done
  if [ ${#missing[@]} -eq 0 ]; then
    echo "all installed"
  else
    SUDO=""; if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi
    $SUDO apt-get update -qq
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq "${missing[@]}"
  fi
fi

# ---------------------------------------------------------------- 2. link configs
step "link configs into ~ with stow"
backed_up=0
for t in "${TARGETS[@]}"; do
  path="$HOME/$t"
  [ -e "$path" ] || [ -L "$path" ] || continue
  case "$(readlink -f "$path")" in "$DOTFILES"/*) continue ;; esac   # already linked here
  mkdir -p "$BACKUP/$(dirname "$t")"
  mv "$path" "$BACKUP/$t"
  echo "moved existing ~/$t to $BACKUP/"
  backed_up=1
  if [ "$t" = .config/nvim ]; then   # an old nvim config's plugins and state would clash with LazyVim
    for d in .local/share/nvim .local/state/nvim .cache/nvim; do
      if [ -e "$HOME/$d" ]; then mkdir -p "$BACKUP/$(dirname "$d")"; mv "$HOME/$d" "$BACKUP/$d"; fi
    done
  fi
done
mkdir -p "$HOME/.config" "$HOME/.claude"
stow -R -d "$DOTFILES" -t "$HOME" "${PACKAGES[@]}"
for t in "${TARGETS[@]}"; do echo "~/$t -> $(readlink "$HOME/$t" 2>/dev/null || echo '(inside a linked folder)')"; done
if [ "$backed_up" = 1 ]; then echo "previous files kept in $BACKUP"; fi

# ---------------------------------------------------------------- 3. machine-only files (never tracked)
step "machine-only files"
if [ -f "$HOME/.bashrc.local" ]; then
  echo "~/.bashrc.local exists, left alone"
else
  cp "$DOTFILES/examples/bashrc.local" "$HOME/.bashrc.local"
  echo "created ~/.bashrc.local from examples/bashrc.local (edit it for this machine)"
fi
if [ -f "$HOME/.gitconfig.local" ]; then
  echo "~/.gitconfig.local exists, left alone"
else
  name="${GIT_NAME:-}" email="${GIT_EMAIL:-}"
  if [ -t 0 ]; then
    [ -n "$name" ]  || read -rp "Name for git commits: " name
    [ -n "$email" ] || read -rp "Email for git commits: " email
  fi
  printf '# ~/.gitconfig.local - this machine only (not tracked in ~/dotfiles). Included from ~/.gitconfig.\n[user]\n\tname = %s\n\temail = %s\n' \
    "${name:-CHANGE ME}" "${email:-change-me@example.com}" > "$HOME/.gitconfig.local"
  echo "created ~/.gitconfig.local"
fi

# ---------------------------------------------------------------- 4. tools (after stow, so nvim plugins can install)
if [ "$do_tools" = 1 ]; then
  step "tools into ~/.local"
  "$DOTFILES/install.sh"
fi

# ---------------------------------------------------------------- 5. Claude Code
if [ "$do_claude" = 1 ]; then
  step "Claude Code"
  if command -v claude >/dev/null; then
    echo "already installed: $(claude --version 2>/dev/null || echo unknown version)"
  else
    curl -fsSL https://claude.ai/install.sh | bash
  fi
fi

# ---------------------------------------------------------------- 6. private workspace
if [ "$do_workspace" = 1 ]; then
  step "private workspace ($WORKSPACE_REPO -> $WORKSPACE_DIR)"
  if ! gh auth status >/dev/null 2>&1; then
    echo "Log in to GitHub (a browser window or a one-time code):"
    gh auth login --hostname github.com --git-protocol https --web
  fi
  if [ -d "$WORKSPACE_DIR/.git" ]; then
    git -C "$WORKSPACE_DIR" pull --ff-only
  else
    # init + fetch instead of clone, because ~/Desktop already exists (and may have files in it)
    mkdir -p "$WORKSPACE_DIR"
    git -C "$WORKSPACE_DIR" init -q -b main
    git -C "$WORKSPACE_DIR" remote add origin "https://github.com/$WORKSPACE_REPO.git"
    git -C "$WORKSPACE_DIR" fetch -q origin
    git -C "$WORKSPACE_DIR" checkout -q -t origin/main
    echo "workspace checked out in $WORKSPACE_DIR"
  fi
  # The workspace's own setup (secrets checklist, etc.) lives in the private repo, not here.
  if [ -x "$WORKSPACE_DIR/setup.sh" ]; then "$WORKSPACE_DIR/setup.sh"; fi
fi

step "done"
cat <<'EOF'
Left for you:
  1. Open a new terminal (or: source ~/.bashrc).
  2. Set the terminal font to "JetBrainsMono Nerd Font".
  3. Run `claude` once to log in.
EOF
