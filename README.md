# dotfiles

My Ubuntu 22.04 setup: bash, tmux, Neovim (LazyVim), git and Claude Code settings.

Each folder is a [GNU Stow](https://www.gnu.org/software/stow/) package laid out the way its files sit under `~`.
Stowing it replaces those files with symlinks into this repo, so editing a config edits the repo.

| Package  | Links to                  | Notes |
|----------|---------------------------|-------|
| `bash`   | `~/.bashrc`               | Ubuntu default + PATH, `EDITOR=nvim`, fzf key bindings |
| `tmux`   | `~/.tmux.conf`            | mouse, vi copy mode to the Wayland clipboard, splits open in the current folder |
| `nvim`   | `~/.config/nvim`          | [LazyVim](https://lazyvim.github.io) starter + C/C++, CMake, Python, Markdown, JSON, YAML, TOML extras |
| `git`    | `~/.gitconfig`            | gh credential helper; name and email come from `~/.gitconfig.local` |
| `claude` | `~/.claude/settings.json` | Claude Code settings only (never the rest of `~/.claude`) |

## New machine

```bash
sudo apt install git
git clone https://github.com/ShengBin-101/dotfiles ~/dotfiles && ~/dotfiles/bootstrap.sh
```

`bootstrap.sh` does everything in order, and is safe to re-run:

1. **apt packages**: stow, tmux, build tools, clipboard tools (asks for your sudo password).
2. **Configs**: moves any existing `~/.bashrc`, `~/.tmux.conf`, etc. to `~/.dotfiles-backup/<time>/`, then `stow`s the packages.
3. **Machine-only files**: creates `~/.bashrc.local` from `examples/bashrc.local` and asks for your git name and email
   for `~/.gitconfig.local`. Neither is tracked; put secrets in `~/.bashrc.local`.
4. **Tools**: `./install.sh` puts nvim, lazygit, fzf, ripgrep, fd, node, gh, tree-sitter and a Nerd Font in `~/.local`,
   then pre-installs LazyVim's plugins and language servers.
5. **Claude Code**, via the official installer.
6. **Private workspace**: logs in to GitHub and checks out my private workspace repo (skip with `--no-workspace`).

Skip steps with `--no-apt`, `--no-tools`, `--no-claude`, `--no-workspace`. Afterwards, open a new terminal, set its
font to **JetBrainsMono Nerd Font**, and run `claude` to log in.

`install.sh` also works on its own. It verifies every download against its published SHA-256 and needs no sudo.
Run it again to update, or name tools to update just those: `./install.sh neovim lazygit`.

## Day to day

- **Configs:** edit them in place, then commit here. Reload tmux with `prefix + r`.
- **Neovim plugins:** `:Lazy update`, then commit `lazy-lock.json`. Add plugins as files in `nvim/.config/nvim/lua/plugins/`.
- **Language extras:** `:LazyExtras` to browse; this config enables them in `lua/config/lazy.lua`.

## Learning Neovim

1. `:Tutor`: the built-in 30-minute lesson on moving and editing.
2. Press `Space` and wait: LazyVim lists every command under it.
3. Handy first keys: `Space Space` find file, `Space /` search text, `Space e` file tree, `Space g g` lazygit, `gd` go to definition, `K` hover docs.
