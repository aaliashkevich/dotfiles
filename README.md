# dotfiles

Personal dotfiles deployed with GNU Stow. Running `stow .` from the repo root
symlinks every non-ignored top-level entry into `$HOME`,
so editing a file here changes the live config immediately.

## dependencies

```
brew update && brew upgrade
brew install --cask ghostty font-jetbrains-mono-nerd-font font-symbols-only-nerd-font
brew install sesh tmux jq bjarneo/cliamp/cliamp neovim tree-sitter-cli glow yazi ffmpegthumbnailer unar poppler fd ripgrep fzf lazygit lazydocker openjdk d2 zoxide stow rustup dive docker-slim go rtk
rustup install stable
sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk
git clone https://github.com/tmux-plugins/tpm ~/dotfiles/.config/tmux/plugins/tpm
npx skills add JuliusBrussee/caveman
```

## setup

- run `rtk init -g`
- run `cd ~/dotfiles && stow .`.
- `zsh` — zinit clones itself and installs plugins.
- `tmux` — press `<prefix>I` (prefix is `C-Space`) to install plugins.
- `nvim` — lazy.nvim bootstraps itself, then mason installs the language servers, formatters and linters.
- `claude` — `~/.claude` is stowed from this repo with the settings and the status line.
- `cliamp` — create `~/.config/cliamp/secrets.env` (mode `0600`) holding all three Navidrome values, quoted:

  ```sh
  NAVIDROME_URL='https://navidrome.example.com'
  NAVIDROME_USER='...'
  NAVIDROME_PASSWORD='...'
  ```

- `gh` — run `gh auth login`.

Machine-local secrets and overrides go in `~/.zsh_extra`, which is untracked.
