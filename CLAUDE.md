# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal cross-platform dotfiles, deployed with GNU Stow. `README.md` has the macOS bootstrap
command list; on Linux the same tooling is installed by the system's own package manager.

Everything here is portable across both platforms — desktop-environment and machine-specific
configuration is deliberately kept out.

## Deployment model (important)

`stow .` (run from repo root, target `$HOME`) symlinks every non-ignored top-level entry into `$HOME`.
So `.config/nvim/init.lua` here **is** `~/.config/nvim/init.lua`. Editing a file in this repo changes
the live config immediately — there is no build, compile, or copy step for anything under `.config/` or `.zshrc`.

Consequences:
- Re-run `stow .` only after adding a *new* top-level entry or a new file in an unlinked directory.
- Any new file added at repo root gets symlinked into `$HOME` unless listed in `.stow-local-ignore`.
  That file **overrides** stow's built-in ignore defaults, so `README.md`, `CLAUDE.md`, `.git` are
  listed explicitly. Add new non-dotfile root entries there too.
- `$HOME/.config` is a *single* symlink to `dotfiles/.config` (stow folded the whole directory).
  Everything under `~/.config` therefore lives in this working tree, tracked or not.
- `.gitignore` excludes machine-generated state and unmanaged config that live inside stowed dirs
  (`.config/tmux/plugins`, `.config/yazi/plugins`, lazygit's `state.yml`, and almost all of
  `.claude` and `.config/cliamp`). Do not commit those; do not delete them either — they are
  live runtime state.
  Two dirs are only *partly* ignored, deliberately: `.config/gh/config.yml` is tracked but
  `hosts.yml` is not (it holds `oauth_token` in plaintext on any machine without a keychain —
  on macOS it happens to be empty, which makes it a trap rather than a safe file), and
  `.config/cliamp/config.toml` is tracked while everything beside it — `secrets.env`, the
  socket, `history.toml`, `resume.json`, the log — is not. `.config/gh-dash` is fully
  tracked; its `theme.colors` block is hand-written Nordic (hex only — gh-dash validates
  those fields with `omitempty,color` and rejects anything else).
  nvim plugin state lives outside the repo in `~/.local/share/nvim/lazy`.
- `~/.claude` is stowed from `.claude/` here. Claude Code hardcodes `~/.claude` — it is **not**
  XDG, so it cannot live under `.config` without setting `CLAUDE_CONFIG_DIR`. Only four files and
  one directory are tracked, via a whitelist (`.claude/*` ignored, then `!` each entry):
  `settings.json`, `CLAUDE.md`, `RTK.md`, `statusline-command.sh`, `themes/`. Note the trailing
  slash on `themes/` matters — `.claude/*` matches the directory itself, and git will not descend
  into an excluded directory, so the directory must be un-ignored before anything inside it can
  be. Un-ignoring it covers its whole contents, which is fine: it holds nothing but themes.
  Everything else is runtime state — `projects/` alone is ~47MB of session transcripts.
  Plugins are **not** tracked; they reinstall from
  `settings.json`'s `extraKnownMarketplaces` + `enabledPlugins`. There is no credentials file on
  macOS (auth lives in the Keychain), so nothing secret is in the directory.
  The caveman plugin's default mode is **not** configured under `.claude/` — its `SessionStart`
  hook resolves the mode from `$CAVEMAN_DEFAULT_MODE`, then a repo-local `.caveman.json`, then
  `$XDG_CONFIG_HOME/caveman/config.json`, then a hardcoded `full`. It is pinned explicitly in
  `.config/caveman/config.json` so a plugin update cannot move it. `~/.claude/.caveman-active`
  is only the flag the statusline reads — it is written from the resolved mode and never read
  back as config, so editing it changes nothing. A root-level `.caveman.json` would be worse
  than useless here: stow links it to `~/.caveman.json`, and the hook walks *up* from the cwd,
  so a nominally repo-local file would become a silent global.
  `statusline-command.sh` renders `Model: … | Effort: … | Context: … | Caveman: …`, all four as
  plain labelled text. Context is the spent token count (input + output) as `52.8k`, not a `k/k`
  ratio; the one decimal comes from `awk`, since bash has no float arithmetic. The caveman segment reads `~/.claude/.caveman-active` **directly** rather than shelling
  out to the plugin's `caveman-statusline.sh`, which renders a `[CAVEMAN:ULTRA]` badge plus a
  savings suffix and would not match the other segments. That also avoids globbing the plugin
  cache, whose path is keyed by commit hash and changes on every plugin update. The flag file's
  hardening is reproduced verbatim — refuse symlinks, cap the read at 64 bytes, strip to
  `[a-z0-9-]`, whitelist the mode — because the file's bytes are printed to the terminal on
  every keystroke.
  `themes/nordic.json` is the Nordic theme, selected by `settings.json`'s `"theme":
  "custom:nordic"` — the `custom:` prefix is required, and the slug after it is the filename
  minus `.json`. Shape is `{ name, base, overrides }`; `base` must be one of `dark`, `light`,
  and the `-ansi`/`-daltonized` variants of each. Claude Code silently drops any override key
  that is not in the base theme and any value that is not `#rgb`/`#rrggbb`/`rgb(r,g,b)`/
  `ansi256(n)`/`ansi:<name>` — there is no error, so a typo just does nothing. The file is
  watched and reloaded live on write. Only the `rainbow_*` and `clawd_*` keys are left at their
  base values on purpose (a rainbow has to stay a rainbow, and the latter is mascot art).
  Caveat: Claude Code caps itself at 256 colours whenever `$TMUX` is set — verified, and it is
  the `TMUX` variable alone, not `TERM` or `COLORTERM`, and not fixable from `tmux.conf`
  (`default-terminal tmux-direct` changes nothing). Inside tmux the palette is therefore
  quantised, which shifts some hues noticeably; outside tmux the exact hexes are emitted.

## Commands

```bash
cd ~/dotfiles && stow .                      # (re)link configs into $HOME
```

No test suite, linter, or CI. Validation is "apply it and see":
- nvim: `nvim` and check `:messages` / `:checkhealth`; `:Lazy sync` after editing `lua/plugins/*.lua`.
- tmux: `tmux source ~/.config/tmux/tmux.conf`; `<prefix>I` installs plugins via tpm.
- zsh: `source ~/.zshrc`.
- ghostty: no live reload — `Cmd+Shift+,` reloads config, or restart the app.
  `ghostty +validate-config --config-file=~/.config/ghostty/config` checks it without launching.

## Neovim (`.config/nvim`)

Plugin manager is **lazy.nvim**, self-bootstrapping on first launch. Load order:
- `init.lua` sets `mapleader` first (lazy needs it before setup), bootstraps lazy, calls
  `require("lazy").setup({ spec = { { import = "plugins" } } })`, then `require("base")`.
- `lua/base/init.lua` requires `options`, `remap`, `commands` in that order. These run *after*
  `lazy.setup`, so `require("which-key")` in `remap.lua` resolves.
- `lua/plugins/*.lua` — one file per plugin (or per tightly-coupled group), each returning a
  lazy spec. Plugin config lives in the spec's `config`/`opts`, **not** in `after/plugin/`;
  under lazy a plugin may not be loaded when `after/plugin` runs, so a top-level
  `require("<plugin>")` there would error.

`lazy-lock.json` is the version pin and **is** tracked in git. Commit it when versions change.

Tooling is installed through **mason**, not the system package manager. Three lists must be kept
in sync when adding a language:
1. `lua/plugins/lsp.lua` — the `tools` table (servers + formatters + linters), fed to
   `mason-tool-installer`. Servers needing non-default options get a `vim.lsp.config("<name>", {...})`
   call in the same file; `mason-lspconfig`'s `automatic_enable` does the `vim.lsp.enable()`.
   Note `mason-lspconfig` v2 has **no** `handlers` key — configuring servers through it is a silent no-op.
2. `lua/plugins/conform.lua` — `formatters_by_ft` (conform does format-on-save, 1000ms, LSP fallback).
3. `lua/plugins/treesitter.lua` — the `parsers` list.

Linters that are not language servers go in `lua/plugins/lint.lua` (`nvim-lint`, on write/read/InsertLeave).

Formatters resolve out of `vim.fn.stdpath("data") .. "/mason/bin"`; that path is computed in both
`lsp.lua` and `conform.lua` — reuse the local `mason_path` variable rather than hardcoding.

Keymaps: leader is `<Space>`. Global maps live in `lua/base/remap.lua`, plugin-specific ones in the
matching `lua/plugins/` file. Every user-facing map is also registered with `which-key` via
`wk.add({...})` next to where it is defined — follow that convention so the popup stays accurate.
Use `group = "..."` for prefix nodes (`name = "+..."` is which-key v2 syntax and does nothing).
Because `wk.add` only runs when its plugin loads, keymap-registering plugins use `event = "VeryLazy"`
rather than `keys = {...}`, so the popup is complete right after startup.

nvim-treesitter is pinned to `branch = "main"` (the rewritten API). Its `setup()` accepts **only**
`install_dir` — parsers are installed with `require("nvim-treesitter").install(...)` and highlighting
is started by an explicit `FileType` autocmd calling `vim.treesitter.start`. There is no
`ensure_installed`, `highlight`, or `auto_install`. This branch compiles parsers with the
`tree-sitter` CLI, which must be on `PATH` (`brew install tree-sitter-cli`).

Folding and float borders are native: `vim.lsp.foldexpr()` and `vim.o.winborder` in
`lua/base/options.lua`. Do not reintroduce nvim-ufo or `vim.lsp.with()`.

## Shell / terminal

- `.zshrc` — plugin manager is **zinit** (self-bootstrapping clone on first run). Order matters:
  zinit lights → `compinit` → `zinit cdreplay -q`. vi-mode is on (`zsh-vi-mode`).
  `tmux_base` function defines the standard session layout; `t` alias attaches or builds it.
  Platform-specific bits are guarded with `uname -s` checks — keep new ones inside those blocks.
  Machine-local secrets/overrides go in `~/.zsh_extra`, sourced last and not tracked here.
- `.config/ghostty/config` — primary terminal. Flat `key = value`, no sections, no extension.
  `theme = nordic` resolves to `.config/ghostty/themes/nordic`, a hand-written theme file holding
  the palette from `AlexvZyl/nordic.nvim`. Ghostty searches `~/.config/ghostty/themes/` **before**
  its own resources dir, so this shadows nothing (the bundled `Nord` is stock Nord, with a lighter
  `#2E3440` background). A theme file is just another Ghostty config file.
  The window is **fully opaque** and uses native fullscreen, so macOS window tabs work.
  `background-opacity`/`background-blur`/`macos-non-native-fullscreen` were removed together —
  they only made sense as a set, because native fullscreen forces the window opaque.
  `shell-integration-features` **replaces** the default set rather than merging into it, so the
  whole list is respecified when enabling `ssh-env`/`ssh-terminfo`.
  Key names in `keybind` are W3C names; both `backquote` and `grave_accent` validate. On this ISO
  keyboard the key left of `1` (the one that types `§`/`±`) is **`intl_backslash`**, *not*
  `backquote`. The `global:` prefix makes a binding work while another app is focused, and needs
  macOS Accessibility permission.
  Validate without launching: `ghostty +validate-config --config-file=~/.config/ghostty/config`
  (the binary is not on `PATH`; it lives at `/Applications/Ghostty.app/Contents/MacOS/ghostty`).
- `.config/tmux/tmux.conf` — prefix is `C-Space`, plugins via **tpm** (installed into the
  gitignored `plugins/` dir). `.config/tmux/scripts/` is tracked, unlike `plugins/`.
  `mode-keys` is set to `emacs` **explicitly**: tmux infers `vi` from `EDITOR=nvim` otherwise, so
  deleting that line silently restores vi copy-mode.
  `terminal-overrides` lists **both** `xterm-256color:RGB` and `xterm-ghostty:RGB` on purpose:
  ghostty's own `TERM` is `xterm-ghostty`, while most other terminals report `xterm-256color`.
  Dropping either entry silently downgrades that terminal to 256 colours.
  Sessions are **sesh**, not tms: `§` opens `sesh picker -i -d` in a popup.
  `detach-on-destroy off` is required by sesh so killing a session does not detach the client —
  but see the cliamp popup below, which overrides it per-session.
  `.config/sesh/sesh.toml` configures it: sesh 2.28 has its own picker, so no fzf/gum wiring is
  needed. The `music` session is blacklisted there so the player never appears in the list.
  sesh has **no directory-scan source** — its list sources are tmux, config, tmuxinator and
  zoxide only, so a project would appear only after zoxide had recorded a visit to it. The
  frecency backend is therefore repointed with `[frecency] list_command` at
  `.config/sesh/scripts/dirs.sh`, which prints `~` plus every depth-1 directory under
  `~/projects`. That both surfaces never-visited projects and drops the zoxide noise
  (`/usr/local`, `/Applications`, mason paths) from the picker. sesh **execs the command
  directly, without a shell**, so it must be an executable file rather than a pipeline in the
  config, and it must always `exit 0` — a non-zero exit makes `sesh list` fail outright instead
  of degrading. `query_command`/`add_command` stay at their zoxide defaults: connecting still
  runs `zoxide add`, so the shell's own `cd` stays warm, and a path is resolved by sesh's `dir`
  strategy before the zoxide one is ever reached.
  The picker's `-d` is **required, not cosmetic**: dir-sourced rows dedupe against live tmux
  sessions by path and config-sourced ones by name, and that dedup only runs under `-d`. Without
  it `~` and `dotfiles` each appear twice.
  Session layout is config, not script: a `[[wildcard]]`/`[[session]]` `windows = [...]` list
  names `[[window]]` entries, and sesh creates one tmux window per name running its
  `startup_script`, then wraps back to window 1 for `startup_command`. So `~/projects/*` and
  `~/dotfiles` both open `nvim`, `lazygit`, `gh-dash`, scratch shell. An undefined window name is
  a hard error. sesh always passes `new-window -n`, which turns tmux's `automatic-rename` off, so
  the scratch window turns it back on to keep tracking whatever runs in it — with an explicit
  `-t "$TMUX_PANE"`, because the session is still detached at that point and a bare `setw` has no
  client to resolve "current window" from and silently retargets another session.
  `tmux_base` builds `dotfiles` with `sesh connect -s dotfiles` so the layout lives only in
  `sesh.toml`. The `-s` is load-bearing: without a client attached sesh returns instead of
  calling `attach-session`, which would block `tmux_base` before it ever reaches `music`.
  There are **no cliamp transport keybinds** — the MacBook's media keys already drive cliamp
  through MediaRemote, and volume goes through the system. `±` only toggles the player popup.
- Statusline is **hand written** in `tmux.conf` — there is no tmux-powerline. It sits at the
  bottom, `status-justify absolute-centre` centres the window list between
  `status-left` (session name + git branch) and `status-right` (cliamp, then a `%H:%M` clock in
  the same pill style as the session name). The clock is plain strftime in `status-right` — tmux
  runs those through strftime, so it needs no script. `status-interval 1`
  drives both `#()` scripts once a second.
  `status 2` with a blank `status-format[0]` carrying **`#[fill=terminal]`** is how the gap
  between the pane content and the bar is made — tmux has no status-padding option. tmux clears
  every status row with `status-style` before drawing, and `fill` is the only thing that
  overrides that, so an empty format alone still paints the bar colour. It must be
  `fill=terminal`, **not** `fill=default`: `default` is accepted but silently renders as
  `status-style`'s background, while `terminal` emits no background at all and lets the
  terminal's own show through, tracking the ghostty theme. The consequence is that `status-format[1]`
  must carry the entire line, so it holds tmux's stock *single-row* format verbatim; regenerate
  it with `tmux set -g status on; tmux show-options -gv 'status-format[0]'` rather than editing
  it by hand. (tmux-powerline also used to set `status 2`, but with tmux's default two-row split.)
  Window cells show the window **name only** — no index, no separators; the active one is a
  filled blue pill. (A single status row cannot draw a top or bottom border, so anything
  box-like there is limited to vertical edge glyphs.)
  Sourcing the config in a live server only *adds* bindings — stale ones need an explicit
  `unbind`, or a `tmux kill-server`.
  - `.config/tmux/scripts/git-branch.sh` — prints nothing outside a repo, so the segment vanishes.
  - `.config/tmux/scripts/cliamp-status.sh` — icon, marquee-scrolled `title — artist`, 10-cell
    progress bar. No elapsed/total time: the bar already says it. Written in **zsh on purpose**:
    macOS bash is 3.2, whose `${var:off:len}` counts bytes and would cut multibyte titles
    mid-character. The marquee offset is `EPOCHSECONDS * 2`, not a state file, so the script is
    stateless and steps two characters per redraw; it freezes while paused.
    `#` in the output is doubled to `##` because tmux reads `#` in `#()` output as a format start.
    Prints nothing when cliamp is not running, so the bar just goes empty.
- cliamp (music player, gitignored config) runs in its own detached `music` tmux session started
  by `tmux_base`, and is shown from anywhere with `prefix ±` via
  `.config/tmux/scripts/cliamp-popup.sh`. Keeping it in a session rather than launching it in the
  popup means the player — and the IPC socket the statusline polls — survives closing the popup.
  The script creates the session on demand, so the popup works even if `tmux_base` never ran.
  `prefix ±` is a **toggle**: pressed from inside the popup the script detaches that client
  (targeted by `#{client_tty}`, never left to tmux's "current client" default), so the popup
  closes and playback continues. `q` inside cliamp still quits the player outright, which takes
  the session and the statusline widget with it — that is intended, not a bug.
  It sets `detach-on-destroy on` **on that session only**, so quitting cliamp closes the popup
  instead of dropping the popup's client into another session. Note `set-option -t` takes a
  *pane* target and rejects the `=exact-name` prefix that `has-session`/`attach-session` accept.
  `~/.config/cliamp/config.toml` **is** tracked, and the whole `[navidrome]` block is
  placeholders — `${NAVIDROME_URL}`, `${NAVIDROME_USER}`, `${NAVIDROME_PASSWORD}` — because the
  repo is public and the host is a private one. cliamp expands any `${VAR}` in a config string
  from the environment, not just the password, and preserves the placeholder when it rewrites the
  file on quit (it rewrites on every TUI exit, so theme/shuffle/repeat changes show up as diffs).
  `NAVIDROME_URL` carries its own `https://`, so no fragment of the host is left in the file.
  The values live in `.config/cliamp/secrets.env`, gitignored, `0600`.
  They **must be quoted** there — `NAVIDROME_PASSWORD='...'`. Unquoted, any `<`/`>` in a password
  is parsed as a shell redirection when the file is sourced: the value is silently truncated at
  the first metacharacter and a stray file named after the following characters appears in the
  caller's cwd.
  Launch goes through `.config/tmux/scripts/cliamp-launch.sh`, the single definition of the
  cliamp command line, called by both `tmux_base` and `cliamp-popup.sh`. It sources the secrets
  itself because **tmux does not pass the calling client's environment to the command it
  spawns** — an `export` in `.zsh_extra` reaches interactive shells but arrives empty in a
  `tmux new-session` command, and `tmux show-environment` confirms it never enters the session
  environment at all. It exports all three names; adding a fourth means editing that `export`
  line, or cliamp silently starts with an empty field.
  cliamp's volume is **dB, never a percentage** — `--vol -10` is roughly half
  perceived loudness; the flag accepts -30..+6, and `volume_min` (default -50) is the floor.
- `.config/yazi/theme.toml` — hand written against the Nordic palette, no flavor package
  (`nord` is not in `yazi-rs/flavors`, and the community ones carry megabyte `tmtheme.xml` and
  `preview.png` blobs). There is no `syntect_theme`: yazi's built-in one is used for preview
  highlighting, since no Nordic tmTheme exists that does not mean committing someone's blob.
  Mind the schema — yazi **v25.12.29** renamed `name` → `url` in `[filetype]`/`[open]`/fetcher/
  previewer rules and moved `hovered`/`preview_hovered` into `[indicator]` as `current`/`preview`,
  `tab_*` into `[tabs]`, the mode styles into `[mode]`, and `[select]` into `[pick]`. yazi parses
  `theme.toml` **before** handling any flag, so a broken theme makes even `yazi --version` fail
  and blocks startup on an interactive `Press <Enter>` prompt — which is what
  `tmux_base`'s auto-launched yazi hits. `yazi --version` is therefore the cheapest config check.
  `.config/yazi/plugins` is gitignored (like `.config/tmux/plugins`); `flavors/` is not.
- `.config/lazygit/config.yml` — Nordic `gui.theme`. lazygit on macOS defaults its config dir to
  `~/Library/Application Support/lazygit`, which stow cannot reach; `.zshrc` exports
  `XDG_CONFIG_HOME="$HOME/.config"` so it lands in this repo instead and matches Linux, where
  lazygit already uses `~/.config/lazygit`. Verify with `lazygit --print-config-dir`.
  lazygit writes `state.yml` and `github_pull_requests.json` next to the config — both gitignored.
- Prompt is hand written in `.zshrc` — starship is gone, and Ghostty has no prompt renderer to
  replace it (`cursor-style` and `shell-integration-features` only reach the cursor and the
  window title). It is a lone vi-mode indicator: `❯` insert, `❮` normal, red after a failed
  command. Colours are palette **indices** (`%F{4}`/`%F{1}`), not hex, so they resolve through
  `.config/ghostty/themes/nordic` and follow the theme. Two non-obvious bits: the exit status is
  captured in a `precmd` rather than tested inline with `%(?..)`, because zsh-vi-mode fires a
  `zle reset-prompt` on every mode switch and `$?` there is the widget's status, not the last
  command's — an inline test loses the red the moment you press Escape; and `PROMPT` is assigned
  with `$'...'`, which does not expand parameters, so `prompt_subst` resolves them at draw time.
  The symbol is swapped by `zvm_after_select_vi_mode`, which zsh-vi-mode auto-runs and follows
  with its own reset-prompt.
  `ZVM_CURSOR_STYLE_ENABLED=false` is set **before** the plugin loads (its `:=` default would
  otherwise win): zsh-vi-mode owns the cursor by default (beam in insert, block in normal) and
  would override ghostty's `cursor-style`/`cursor-style-blink`. The prompt symbol carries the
  mode instead.
  Theme across ghostty/tmux/nvim/yazi/lazygit/cliamp is **Nordic**.

## Conventions

Commits are conventional-commit style with an optional scope naming the subsystem:
`feat(nvim): …`, `fix(tmux): …`, `chore(ghostty): …`, `docs: …`.

When adding a tool to the macOS setup, also update the `brew install` line in `README.md` — that
list is the install manifest for the platform.
