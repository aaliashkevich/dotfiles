# dotfiles

Personal dotfiles deployed with GNU Stow. Running `stow .` from the repo root
symlinks every non-ignored top-level entry into `$HOME`,
so editing a file here changes the live config immediately.

Machine-local secrets and overrides go in `~/.zsh_extra`, which is untracked.

## setup

```
git clone https://github.com/aaliashkevich/dotfiles ~/dotfiles && ~/dotfiles/setup.sh
```

`setup.sh` does everything: installs the Command Line Tools and Homebrew, installs every
package, deploys the configs with `stow`, and drives each tool's own first-run bootstrap
(zinit, tpm, lazy.nvim, mason, treesitter) headlessly. It is idempotent — re-run it any time.

It stops for input three times: the sudo password (Homebrew and the openjdk symlink), the three
Navidrome values it writes to `~/.config/cliamp/secrets.env` (mode `0600`), and `gh auth login`.

## dependencies

Everything `setup.sh` installs, for reference.

**Casks** — ghostty, font-jetbrains-mono-nerd-font, font-symbols-only-nerd-font, claude,
claude-code

**Formulae** — sesh, tmux, jq, bjarneo/cliamp/cliamp, neovim, tree-sitter-cli, glow, yazi,
ffmpegthumbnailer, unar, poppler, fd, ripgrep, fzf, lazygit, lazydocker, openjdk, d2, zoxide,
stow, rustup, dive, docker-slim, go, rtk, n, mactop

**Toolchains** — Node LTS through `n` rather than the `node` formula, with
`N_PREFIX="$HOME/.local"` so no `sudo` is needed (`.zshrc` exports both); Rust stable through
`rustup`; and an `openjdk.jdk` symlink into `/Library/Java/JavaVirtualMachines`.

**Plugins** — tpm, cloned into `.config/tmux/plugins/tpm`, and the tmux plugins it installs:
tmux-sensible, tmux-yank, vim-tmux-navigator. The caveman Claude Code plugin, from the
`JuliusBrussee/caveman` marketplace. zinit, lazy.nvim and mason bootstrap themselves on the
first run of their own tool, and `rtk init -g` registers the rtk hook.
