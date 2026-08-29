# CLAUDE.md

Guidance for Claude Code working in this repository.

## What this repo is

Personal macOS dotfiles deployed with GNU Stow. `setup.sh` is the bootstrap: one command from an
empty machine to a working environment. Theme everywhere is **Nordic**.

## Deployment model

`stow .` from the repo root symlinks every non-ignored top-level entry into `$HOME`, so
`.config/nvim/init.lua` here **is** `~/.config/nvim/init.lua`. Editing a file changes the live
config immediately — no build step. Re-run `stow .` only after adding a new top-level entry.

- `.stow-local-ignore` **overrides** stow's built-in defaults, so `.git`, `README.md`, `CLAUDE.md`,
  `setup.sh` are listed explicitly. Any new root entry not listed there gets linked into `$HOME`.
- `~/.config` is a *single* folded symlink to `dotfiles/.config` — everything under it lives in
  this working tree, tracked or not.
- `~/.claude` is stowed too (Claude Code hardcodes that path; it is not XDG). Tracked via a
  whitelist: `settings.json`, `CLAUDE.md`, `RTK.md`, `statusline-command.sh`, `themes/`. The
  trailing slash on `themes/` matters — git will not descend into an excluded directory, so it
  must be un-ignored before its contents can be. Everything else is runtime state (`projects/`
  alone is ~47MB). Plugins are not tracked; they reinstall from `settings.json`'s
  `extraKnownMarketplaces` + `enabledPlugins`.
- `.gitignore` excludes runtime state living inside stowed dirs (`tmux/plugins`, `yazi/plugins`,
  lazygit `state.yml`, most of `.claude` and `.config/cliamp`). Do not commit it, do not delete it.
  Two partial ignores are deliberate: `gh/config.yml` tracked but `hosts.yml` not (holds a
  plaintext `oauth_token`), and `cliamp/config.toml` tracked but `secrets.env` and friends not.
  `gh-dash` is fully tracked — its `theme.colors` block takes hex only, anything else is rejected.

## setup.sh

Install manifest and bootstrap in one file. The package lists in `README.md` are a reading copy —
a package added to one must be added to the other. Order is load-bearing:

- `stow .` runs **before** `claude plugin install` and before anything can create `~/.claude` or
  `~/.config`; `claude` writes a real `~/.claude/settings.json` on first run and stow then refuses.
- `rtk init -g` runs after stow, before any `claude` invocation — `.claude/settings.json` registers
  a `PreToolUse` hook calling `rtk hook claude`.
- Existing non-symlink targets move to `~/.dotfiles-backup-<timestamp>/` after a prompt; a new
  top-level entry must be added to the script's `STOW_TARGETS` for that check to cover it.
- mason and treesitter install asynchronously and fire no reliable completion event headlessly, so
  the script parks a headless `nvim` on `vim.wait` and polls
  `~/.local/share/nvim/{mason/bin,site/parser}` until the entry count stops changing.
- Node comes from `n` with `N_PREFIX="$HOME/.local"` (no sudo). Needed because most of mason's
  `tools` list is npm-based and Homebrew's `neovim` pulls in no node.

## Commands

```bash
~/dotfiles/setup.sh                          # full bootstrap; idempotent, re-runnable
cd ~/dotfiles && stow .                      # (re)link configs into $HOME
```

No test suite, linter, or CI. Validation is "apply it and see":
- nvim: `:messages` / `:checkhealth`; `:Lazy sync` after editing `lua/plugins/*.lua`.
- tmux: `tmux source ~/.config/tmux/tmux.conf`. Sourcing only *adds* bindings — stale ones need an
  explicit `unbind` or `tmux kill-server`.
- zsh: `source ~/.zshrc`.
- ghostty: no live reload; `Cmd+Shift+,` or restart. Validate without launching with
  `/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config --config-file=~/.config/ghostty/config`
  (the binary is not on `PATH`).
- yazi: `yazi --version` — it parses `theme.toml` before handling any flag, so a broken theme makes
  even that fail, and blocks startup on an interactive prompt.
- lazygit: `lazygit --print-config-dir` must report `~/.config/lazygit`. It reaches that only
  because `.zshrc` exports `XDG_CONFIG_HOME`; the macOS default is `~/Library/Application Support`,
  which stow cannot reach.

## Neovim (`.config/nvim`)

**lazy.nvim**, self-bootstrapping. `init.lua` sets `mapleader` first (lazy needs it before setup),
then `lazy.setup`, then `require("base")` — so `require("which-key")` in `remap.lua` resolves.
One file per plugin under `lua/plugins/`, config in the spec's `config`/`opts`, **never** in
`after/plugin/` (a plugin may not be loaded when that runs). `lazy-lock.json` is tracked — commit it.

Tooling comes from **mason**. Adding a language means editing three lists in sync:
1. `lua/plugins/lsp.lua` — the `tools` table. Server options go in a `vim.lsp.config("<name>", {...})`
   call in the same file; `mason-lspconfig` v2 has **no** `handlers` key, configuring through it is
   a silent no-op.
2. `lua/plugins/conform.lua` — `formatters_by_ft`.
3. `lua/plugins/treesitter.lua` — the `parsers` list.

Non-LSP linters go in `lua/plugins/lint.lua`. Formatter paths come from the local `mason_path`
variable (`stdpath("data") .. "/mason/bin"`), computed in both `lsp.lua` and `conform.lua` — reuse it.

Keymaps: leader is `<Space>`; global in `lua/base/remap.lua`, plugin-specific in the matching
`lua/plugins/` file, each registered with `wk.add({...})` next to its definition. Use `group = "..."`
for prefix nodes (`name = "+..."` is v2 syntax, does nothing). Keymap-registering plugins load on
`event = "VeryLazy"` rather than `keys = {...}`, so the popup is complete after startup.

nvim-treesitter is pinned to `branch = "main"`: `setup()` takes **only** `install_dir`, parsers come
from `require("nvim-treesitter").install(...)`, highlighting from an explicit `FileType` autocmd.
No `ensure_installed`/`highlight`/`auto_install`. Parsers compile with the `tree-sitter` CLI on PATH.

Folding and float borders are native (`vim.lsp.foldexpr()`, `vim.o.winborder`). Do not reintroduce
nvim-ufo or `vim.lsp.with()`.

## Shell / terminal

**`.zshrc`** — zinit, self-bootstrapping. Order matters: zinit lights → `compinit` →
`zinit cdreplay -q`. `ZVM_CURSOR_STYLE_ENABLED=false` must be set *before* zsh-vi-mode loads or its
`:=` default wins and it takes over ghostty's cursor. The prompt is hand written (`❯` insert,
`❮` normal, red on failure, palette indices not hex): exit status is captured in a `precmd` rather
than `%(?..)` because zsh-vi-mode fires `zle reset-prompt` on every mode switch, where `$?` is the
widget's status. `tmux_base` defines the session layout, `t` attaches or builds it. Machine-local
secrets go in `~/.zsh_extra`, sourced last, untracked.

**`.config/ghostty/config`** — flat `key = value`, no extension. `theme = nordic` resolves to
`themes/nordic` in the same dir, which Ghostty searches before its own resources.
`shell-integration-features` **replaces** the default set rather than merging, so respecify the
whole list. On this ISO keyboard the key left of `1` (`§`/`±`) is **`intl_backslash`**, not
`backquote`. The `global:` prefix needs macOS Accessibility permission. The window is opaque on
purpose: native fullscreen (which macOS window tabs need) forces opacity, so transparency and blur
have no effect and are not set.

**`.config/tmux/tmux.conf`** — prefix `C-Space`, plugins via tpm into the gitignored `plugins/`;
`scripts/` is tracked. `mode-keys emacs` is explicit — tmux otherwise infers `vi` from `EDITOR=nvim`.
`terminal-overrides` needs **both** `xterm-256color:RGB` and `xterm-ghostty:RGB`; dropping either
downgrades that terminal to 256 colours. Statusline is hand written, bottom, no tmux-powerline.
`status 2` with a blank `status-format[0]` carrying **`#[fill=terminal]`** is what makes the gap
above the bar — `fill=default` is accepted but silently paints `status-style`'s background. That
forces `status-format[1]` to carry the whole line, so it holds tmux's stock *single-row* format
verbatim; regenerate it with `tmux set -g status on; tmux show-options -gv 'status-format[0]'`
rather than editing by hand.
- `scripts/git-branch.sh` — prints nothing outside a repo, so the segment vanishes.
- `scripts/cliamp-status.sh` — play/pause icon plus marquee-scrolled `title — artist`. Written in
  **zsh on purpose**: macOS bash is 3.2, whose `${var:off:len}` counts bytes and would cut
  multibyte titles mid-character. Marquee offset is `EPOCHSECONDS * 2`, so it is stateless. `#` in
  the output is doubled to `##` — tmux reads `#` in `#()` output as a format start.

**sesh** (`.config/sesh/sesh.toml`) — `§` opens `sesh picker -i -d`; `detach-on-destroy off` in
`tmux.conf` is required by it. sesh has no directory-scan source, so `[frecency] list_command`
repoints it at `scripts/dirs.sh` (`~` plus depth-1 dirs under `~/projects`), surfacing
never-visited projects and dropping zoxide noise. sesh **execs that directly, without a shell**: it
must be an executable file and must always `exit 0`, or `sesh list` fails outright. The picker's
`-d` is required, not cosmetic — dedup against live tmux sessions only runs under it. Session
layout is config, not script: `windows = [...]` names `[[window]]` entries, one tmux window each;
an undefined name is a hard error. sesh always passes `new-window -n`, disabling
`automatic-rename`, so the scratch window re-enables it with an explicit `-t "$TMUX_PANE"` (the
session is still detached, so a bare `setw` retargets another one). `tmux_base` uses
`sesh connect -s dotfiles` — without `-s`, sesh blocks in `attach-session` before reaching `music`.

**cliamp** — runs in its own detached `music` session so the player and the IPC socket the
statusline polls survive closing the `prefix ±` popup (`scripts/cliamp-popup.sh`). `±` is a toggle:
from inside the popup the script detaches that client by `#{client_tty}`, never tmux's default
"current client". `q` inside cliamp quits the player and takes the widget with it — intended.
`detach-on-destroy on` is set on that session only; `set-option -t` takes a *pane* target and
rejects the `=exact-name` prefix. `config.toml` is tracked with the whole `[navidrome]` block as
`${VAR}` placeholders (public repo, private host); cliamp expands them from the environment and
preserves them when it rewrites the file on every TUI exit. Values live in
`.config/cliamp/secrets.env`, gitignored, `0600`, and **must be quoted** — unquoted, a `<` or `>` in
a password becomes a redirection when the file is sourced, truncating the value. Launch goes through
`scripts/cliamp-launch.sh`, which sources the secrets itself because **tmux does not pass the
calling client's environment to the command it spawns**; it exports all three names, so a fourth
means editing that line. Volume is dB, not percent (`--vol -10` ≈ half loudness, range -30..+6).
No transport keybinds — the MacBook's media keys drive cliamp via MediaRemote.

**`.config/yazi/theme.toml`** — hand written, no flavor package, no `syntect_theme`. Mind the
schema: yazi **v25.12.29** renamed `name` → `url` in `[filetype]`/`[open]`/fetcher/previewer rules,
moved `hovered`/`preview_hovered` into `[indicator]` as `current`/`preview`, `tab_*` into `[tabs]`,
mode styles into `[mode]`, and `[select]` into `[pick]`.

## Claude Code config (`.claude/`)

`themes/nordic.json` is selected by `settings.json`'s `"theme": "custom:nordic"` — the `custom:`
prefix is required and the slug is the filename minus `.json`. Shape is `{ name, base, overrides }`.
Claude Code **silently drops** any override key absent from the base theme and any value that is not
`#rgb`/`#rrggbb`/`rgb(r,g,b)`/`ansi256(n)`/`ansi:<name>`, so a typo just does nothing. The file
reloads live on write. `rainbow_*` and `clawd_*` are left at base values on purpose. Caveat: Claude
Code caps itself at 256 colours whenever `$TMUX` is set — the variable alone, not `TERM`, and not
fixable from `tmux.conf`.

`statusline-command.sh` renders `Model | Effort | Context | Caveman` as plain labelled text;
Context is spent tokens (`52.8k`), the decimal via `awk`. The caveman segment reads
`~/.claude/.caveman-active` **directly** rather than shelling out to the plugin's own statusline
script, which renders a mismatched badge and would need globbing a plugin cache path keyed by commit
hash. Its hardening is reproduced verbatim — refuse symlinks, cap the read at 64 bytes, strip to
`[a-z0-9-]`, whitelist the mode — because those bytes reach the terminal on every keystroke.

The caveman plugin's default mode is pinned in `.config/caveman/config.json`, not under `.claude/`:
its hook resolves `$CAVEMAN_DEFAULT_MODE` → repo-local `.caveman.json` → `$XDG_CONFIG_HOME/caveman/
config.json` → `full`. A root-level `.caveman.json` would be worse than useless — stow links it to
`~/.caveman.json` and the hook walks *up* from the cwd, making a nominally repo-local file a silent
global. `~/.claude/.caveman-active` is only the statusline flag, never read back as config.

## Conventions

Conventional commits with an optional subsystem scope: `feat(nvim): …`, `fix(tmux): …`, `docs: …`.

When adding a tool, add it to the package lists in `setup.sh` and to the copy in `README.md`.
