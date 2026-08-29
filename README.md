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

The manifest `setup.sh` installs, for reference:

```
brew install --cask ghostty font-jetbrains-mono-nerd-font font-symbols-only-nerd-font claude claude-code
brew install sesh tmux jq bjarneo/cliamp/cliamp neovim tree-sitter-cli glow yazi ffmpegthumbnailer unar poppler fd ripgrep fzf lazygit lazydocker openjdk d2 zoxide stow rustup dive docker-slim go rtk n
n lts
rustup install stable
sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk
git clone https://github.com/tmux-plugins/tpm ~/dotfiles/.config/tmux/plugins/tpm
rtk init -g
claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman
```

Node comes from `n`, not the `node` formula, with `N_PREFIX="$HOME/.local"` so no `sudo` is
needed — `.zshrc` exports both.
