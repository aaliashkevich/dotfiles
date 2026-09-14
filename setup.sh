#!/usr/bin/env bash
#
# One-shot bootstrap for these dotfiles on macOS.
#
#   ~/dotfiles/setup.sh
#
# Installs Homebrew and every package, deploys the configs with stow, drives each
# tool's own first-run bootstrap headlessly, and writes the cliamp secrets file.
# Idempotent: safe to re-run. The only prompts are the sudo password and the three
# Navidrome values.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Top-level entries stow links into $HOME. Add new ones here as well as leaving
# them out of .stow-local-ignore.
STOW_TARGETS=(.zshrc .config .claude)

CASKS=(
    ghostty
    font-jetbrains-mono-nerd-font
    font-symbols-only-nerd-font
    claude
    claude-code
)

FORMULAE=(
    sesh tmux jq bjarneo/cliamp/cliamp neovim tree-sitter-cli glow yazi
    ffmpegthumbnailer unar poppler fd ripgrep fzf lazygit lazydocker openjdk
    d2 zoxide stow rustup dive docker-slim go rtk n mactop gh
)

WARNINGS=()
NVIM_PID=""
SUDO_KEEPALIVE_PID=""
SUDO_NONINTERACTIVE=0

# ---------------------------------------------------------------- logging ----

bold=$'\033[1m'
blue=$'\033[34m'
green=$'\033[32m'
yellow=$'\033[33m'
reset=$'\033[0m'

step() { printf '\n%s%s==>%s %s%s\n' "$bold" "$blue" "$reset" "$1" "$reset"; }
info() { printf '    %s\n' "$1"; }
ok() { printf '    %s✓%s %s\n' "$green" "$reset" "$1"; }
warn() {
    printf '    %s!%s %s\n' "$yellow" "$reset" "$1"
    WARNINGS+=("$1")
}
die() {
    printf '\n%s✗%s %s\n' "$yellow" "$reset" "$1" >&2
    exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

# Group membership as the directory service sees it. A bare `id -Gn` reports the
# groups this shell was *started* with, so an elevation granted mid-run would
# never show up there and the wait loop below would never finish.
is_admin() { id -Gn "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx admin; }

# The exact probe Homebrew's installer runs under NONINTERACTIVE. Passes only if
# a warm sudo timestamp and a sudoers rule covering mkdir are both in place.
sudo_probe() { sudo -n -l mkdir >/dev/null 2>&1; }

# SAP Privileges. The binary moved between major versions, so try every path.
privileges_cli() {
    local p
    for p in /usr/local/bin/PrivilegesCLI \
        /Applications/Privileges.app/Contents/MacOS/PrivilegesCLI \
        /Applications/Privileges.app/Contents/Resources/PrivilegesCLI; do
        [ -x "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

# Wrap a value in single quotes for a file that gets sourced by sh. Without this
# an unquoted < or > in a password is parsed as a redirection.
shell_quote() {
    local v=${1//\'/\'\\\'\'}
    printf "'%s'" "$v"
}

cleanup() {
    [ -n "$NVIM_PID" ] && kill "$NVIM_PID" 2>/dev/null || true
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Number of entries directly under a directory; 0 if it does not exist.
count_entries() {
    [ -d "$1" ] || {
        printf 0
        return
    }
    find "$1" -mindepth 1 -maxdepth 1 | wc -l | tr -d " "
}

# Wait until the file count under the given directories stops changing.
# usage: wait_settled <timeout-secs> <stable-secs> <dir>...
wait_settled() {
    local timeout=$1 stable=$2
    shift 2
    local last=-1 unchanged=0 elapsed=0 count dir

    while [ "$elapsed" -lt "$timeout" ]; do
        count=0
        for dir in "$@"; do
            count=$((count + $(count_entries "$dir")))
        done

        if [ "$count" -eq "$last" ]; then
            unchanged=$((unchanged + 5))
            [ "$unchanged" -ge "$stable" ] && return 0
        else
            unchanged=0
            last=$count
        fi

        sleep 5
        elapsed=$((elapsed + 5))
    done

    return 1
}

# ------------------------------------------------------------------ steps ----

preflight() {
    step "Preflight"
    [ "$(uname -s)" = "Darwin" ] || die "macOS only — on Linux install the same tools with the system package manager."
    ok "repo at $REPO"

    if is_admin; then
        ok "$USER is an administrator"
    elif privileges_cli >/dev/null; then
        ok "$USER is a standard user — Privileges.app is available to elevate"
    else
        warn "$USER is a standard user and Privileges.app is absent — steps needing root will be skipped"
    fi
}

jdk_link_ok() {
    have brew || return 1
    local src
    src="$(brew --prefix openjdk 2>/dev/null)/libexec/openjdk.jdk"
    [ -e "$src" ] && [ "/Library/Java/JavaVirtualMachines/openjdk.jdk" -ef "$src" ]
}

request_sudo() {
    step "Administrator access"

    if have brew && jdk_link_ok; then
        ok "not needed — Homebrew present and the openjdk symlink is in place"
        return
    fi

    info "needed to install Homebrew and to link openjdk into /Library/Java/JavaVirtualMachines"

    local cli waited
    if ! is_admin; then
        if cli="$(privileges_cli)"; then
            info "standard user — asking Privileges.app for admin rights"
            "$cli" --add >/dev/null 2>&1 || true

            waited=0
            until is_admin || [ "$waited" -ge 15 ]; do
                sleep 1
                waited=$((waited + 1))
            done

            if is_admin; then
                ok "elevated — elevation expires (commonly after 20 min), re-run '$cli --add' if a later step is refused"
            else
                warn "Privileges.app did not grant admin — continuing on sudo alone"
            fi
        else
            warn "standard user and no Privileges.app — continuing on sudo alone"
        fi
    fi

    sudo -v || die "sudo required"

    # Homebrew's installer and the keepalive both rely on a passwordless `sudo -n`.
    # A managed Mac with timestamp_timeout=0 has none, so probe instead of assuming.
    if sudo_probe; then
        SUDO_NONINTERACTIVE=1

        # Keep the timestamp warm; brew and nvim steps take longer than sudo's 5 min.
        while true; do
            sudo -n true
            sleep 60
            kill -0 "$$" 2>/dev/null || exit
        done 2>/dev/null &
        SUDO_KEEPALIVE_PID=$!
        ok "granted"
    else
        SUDO_NONINTERACTIVE=0
        warn "sudo has no reusable timestamp — every sudo call will ask for the password"
    fi
}

install_clt() {
    step "Xcode Command Line Tools"

    if xcode-select -p >/dev/null 2>&1; then
        ok "already installed"
        return
    fi

    info "launching the installer — click through the dialog, this script waits"
    xcode-select --install >/dev/null 2>&1 || true

    until xcode-select -p >/dev/null 2>&1; do sleep 10; done
    ok "installed"
}

install_homebrew() {
    step "Homebrew"

    if ! have brew; then
        # NONINTERACTIVE makes upstream's have_sudo_access() probe with
        # `sudo -n -l mkdir`, which can never prompt. Where that fails the installer
        # aborts with "the user needs to be an Administrator", blaming the group
        # rather than the probe. The interactive path uses `sudo -v` and can ask.
        if [ "$SUDO_NONINTERACTIVE" = 1 ]; then
            NONINTERACTIVE=1 /bin/bash -c \
                "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
            info "sudo prompts per call — running Homebrew's installer interactively; it waits for one RETURN"
            /bin/bash -c \
                "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
    fi

    if ! have brew; then
        local prefix
        [ "$(uname -m)" = "arm64" ] && prefix=/opt/homebrew || prefix=/usr/local
        eval "$("$prefix/bin/brew" shellenv)"
    fi

    have brew || die "Homebrew install failed — on Apple Silicon upstream supports /opt/homebrew only, and creating it needs root. With sudo locked down the only route left is the unsupported prefix 'git clone https://github.com/Homebrew/brew ~/homebrew', which builds most formulae from source."
    ok "$(brew --version | head -1)"
}

update_homebrew() {
    step "brew update && brew upgrade"
    brew update
    brew upgrade
    ok "up to date"
}

install_packages() {
    step "Casks"
    local pkg name

    # A standard user owns neither /Applications nor /Library/Fonts. Both flags are
    # needed — font casks ignore --appdir and land in the font dir.
    if ! is_admin; then
        mkdir -p "$HOME/Applications" "$HOME/Library/Fonts"
        export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications --fontdir=$HOME/Library/Fonts"
        warn "standard user — casks go to ~/Applications, fonts to ~/Library/Fonts"
    fi

    for pkg in "${CASKS[@]}"; do
        name="${pkg##*/}"
        if brew list --cask --versions "$name" >/dev/null 2>&1; then
            ok "$name"
        else
            brew install --cask "$pkg"
        fi
    done

    step "Formulae"
    for pkg in "${FORMULAE[@]}"; do
        name="${pkg##*/}"
        if brew list --formula --versions "$name" >/dev/null 2>&1; then
            ok "$name"
        else
            brew install "$pkg"
        fi
    done
}

install_node() {
    step "Node (via n)"

    export N_PREFIX="$HOME/.local"
    mkdir -p "$N_PREFIX/bin"
    export PATH="$N_PREFIX/bin:$PATH"

    n lts
    ok "$(node --version) at $(command -v node)"

    if brew list --formula --versions node >/dev/null 2>&1; then
        warn "Homebrew's node formula is installed and shadows n's node — 'brew uninstall node' to switch over"
    fi
}

install_rust() {
    step "Rust toolchain"

    local rustup_bin
    rustup_bin="$(brew --prefix rustup)/bin"
    export PATH="$rustup_bin:$PATH"
    rustup install stable
    rustup default stable
    ok "$(rustc --version)"
}

link_openjdk() {
    step "openjdk"

    if jdk_link_ok; then
        ok "already linked"
        return
    fi

    # Root-only. Without it java still works off JAVA_HOME, so warn rather than
    # let `set -e` take the rest of the bootstrap down with it.
    if sudo ln -sfn "$(brew --prefix openjdk)/libexec/openjdk.jdk" \
        /Library/Java/JavaVirtualMachines/openjdk.jdk; then
        ok "linked into /Library/Java/JavaVirtualMachines"
        return
    fi

    local line='export JAVA_HOME="$(brew --prefix openjdk)/libexec/openjdk"'
    grep -qsF "$line" "$HOME/.zsh_extra" || printf '%s\n' "$line" >>"$HOME/.zsh_extra"
    warn "could not link openjdk into /Library/Java/JavaVirtualMachines (needs root) — JAVA_HOME written to ~/.zsh_extra instead"
}

make_projects_dir() {
    step "$HOME/projects"
    mkdir -p "$HOME/projects"
    ok "present — sesh lists its depth-1 directories"
}

deploy_stow() {
    step "stow"

    local conflicts=() target
    for target in "${STOW_TARGETS[@]}"; do
        if [ -e "$HOME/$target" ] || [ -L "$HOME/$target" ]; then
            [ "$HOME/$target" -ef "$REPO/$target" ] || conflicts+=("$target")
        fi
    done

    if [ ${#conflicts[@]} -gt 0 ]; then
        local backup
        backup="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
        printf '\n    These already exist in your home directory and are not links into this repo:\n'
        printf '      ~/%s\n' "${conflicts[@]}"
        printf '    They will be moved to %s\n' "$backup"
        read -r -p "    Continue? [y/N] " reply
        case "$reply" in
        [yY]*) ;;
        *) die "aborted — move or remove those paths yourself, then re-run" ;;
        esac

        mkdir -p "$backup"
        for target in "${conflicts[@]}"; do
            mv "$HOME/$target" "$backup/$target"
            info "moved ~/$target"
        done
    fi

    (cd "$REPO" && stow .)

    if [ -L "$HOME/.config" ]; then
        ok "$HOME/.config is a single symlink into the repo"
    else
        warn "$HOME/.config is a real directory, not a folded symlink — the repo assumes the symlink; check for stray files under it"
    fi
}

install_tpm() {
    step "tmux plugins"

    local tpm="$REPO/.config/tmux/plugins/tpm"
    [ -d "$tpm" ] || git clone https://github.com/tmux-plugins/tpm "$tpm"

    # Same work as <prefix>I, without needing an attached client.
    tmux new-session -d -s __dotfiles_setup -c "$HOME" 2>/dev/null || true
    "$tpm/bin/install_plugins" >/dev/null
    tmux kill-session -t __dotfiles_setup 2>/dev/null || true

    ok "tpm and its plugins installed"
}

write_secrets() {
    step "Navidrome credentials"

    local secrets="$HOME/.config/cliamp/secrets.env"
    local url user password

    info "written to $secrets (mode 0600, never committed)"
    read -r -p "    NAVIDROME_URL (with https://): " url
    read -r -p "    NAVIDROME_USER: " user
    read -rs -p "    NAVIDROME_PASSWORD: " password
    printf '\n'

    mkdir -p "$(dirname "$secrets")"
    (
        umask 077
        {
            printf 'NAVIDROME_URL=%s\n' "$(shell_quote "$url")"
            printf 'NAVIDROME_USER=%s\n' "$(shell_quote "$user")"
            printf 'NAVIDROME_PASSWORD=%s\n' "$(shell_quote "$password")"
        } >"$secrets"
    )
    chmod 600 "$secrets"

    ok "written"
}

bootstrap_zsh() {
    step "zsh plugins"
    info "zinit clones itself and its plugins on the first interactive shell"
    zsh -i -c exit </dev/null >/dev/null 2>&1 || warn "the first zsh start reported an error — run 'zsh' by hand to see it"
    ok "done"
}

bootstrap_nvim() {
    step "Neovim plugins, language servers and parsers"
    info "the slow step — mason and treesitter downloads run in the background"

    nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 ||
        warn "lazy.nvim restore reported an error — check ':Lazy' in nvim"

    # mason-tool-installer and the treesitter spec both install on startup, so a
    # headless instance that simply stays alive drives both. Wait for the two
    # install directories to stop growing rather than for a plugin event.
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
    nvim --headless -c 'lua vim.wait(2400000, function() return false end)' >/dev/null 2>&1 &
    NVIM_PID=$!

    if wait_settled 2400 60 "$data/mason/bin" "$data/site/parser"; then
        ok "$(count_entries "$data/mason/bin") mason tools, $(count_entries "$data/site/parser") treesitter parsers"
    else
        warn "nvim tooling did not finish within 40 minutes — open nvim and check ':Mason' / ':checkhealth'"
    fi

    kill "$NVIM_PID" 2>/dev/null || true
    wait "$NVIM_PID" 2>/dev/null || true
    NVIM_PID=""
}

init_rtk() {
    step "rtk"
    rtk init -g
    ok "initialised — the Claude Code PreToolUse hook needs this"
}

install_claude_plugin() {
    step "Claude Code plugins"

    if ! have claude; then
        warn "no 'claude' on PATH — run: claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman"
        return
    fi

    claude plugin marketplace add JuliusBrussee/caveman || true
    claude plugin install caveman@caveman ||
        warn "caveman plugin install failed — run 'claude plugin install caveman@caveman' by hand"
    ok "caveman installed"
}

install_codegraph() {
    step "codegraph"

    if have codegraph; then
        codegraph upgrade || warn "codegraph upgrade failed — re-run 'codegraph upgrade' by hand"
    else
        # Unpacks into ~/.codegraph/versions/<ver> and symlinks ~/.local/bin/codegraph.
        # That directory is already on PATH via N_PREFIX, so no rc file needs editing.
        curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
    fi

    if have codegraph; then
        ok "$(codegraph --version)"
    else
        warn "codegraph not on PATH after install — expected $HOME/.local/bin/codegraph"
    fi
}

wire_codegraph() {
    step "codegraph MCP wiring"

    have codegraph || {
        warn "no codegraph on PATH — skipping MCP wiring"
        return
    }

    have claude || {
        warn "no 'claude' on PATH — run 'codegraph install' by hand once it is"
        return
    }

    # --no-permissions: the allow entry is tracked in .claude/settings.json instead, so the
    # installer never rewrites a stowed file. It still owns its block in .claude/CLAUDE.md.
    codegraph install --yes --target=claude --location=global --no-permissions ||
        warn "codegraph install failed — run 'codegraph install' by hand"
    ok "MCP server wired into ~/.claude.json"
}

# gh auth login hands out its default scope set, which does NOT include 'project' — every
# project-board operation (gh project item-add, gh issue edit --add-project) then fails on an
# insufficient-scope error. Checking authentication alone is not enough: a machine that logged in
# before this function existed keeps its old token forever, so the scopes are re-checked on every
# run and topped up with gh auth refresh.
auth_gh() {
    step "GitHub CLI"

    if ! have gh; then
        warn "gh not installed — skipping auth; 'gh dash' stays empty"
        return
    fi

    local scopes=(project workflow)

    local status
    if ! status=$(gh auth status 2>&1); then
        gh auth login -s project -s workflow ||
            warn "gh auth login did not complete — 'gh dash' stays empty until it does"
        return
    fi

    local missing=()
    local scope
    for scope in "${scopes[@]}"; do
        grep -q "Token scopes:.*'$scope'" <<<"$status" || missing+=("$scope")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "authenticated with the ${scopes[*]} scopes"
        return
    fi

    # A token from the environment is not gh's to rewrite: 'gh auth refresh' rejects it outright.
    if grep -qE 'GH_TOKEN|GITHUB_TOKEN' <<<"$status"; then
        warn "token comes from the environment and cannot be refreshed — reissue it with the ${missing[*]} scope(s)"
        return
    fi

    info "token is missing the ${missing[*]} scope(s) — opening the browser to refresh it"
    gh auth refresh -s project -s workflow ||
        warn "gh auth refresh did not complete — run 'gh auth refresh -s project -s workflow' by hand"
}

# gh-dash ships as a gh extension, not a formula: 'gh extension install' is the only
# supported route, and it is a no-op-with-error on a machine that already has it.
install_gh_dash() {
    step "gh-dash"

    if ! have gh; then
        warn "gh not installed — skipping gh-dash"
        return
    fi

    if gh extension list 2>/dev/null | grep -q 'dlvhdr/gh-dash'; then
        ok "already installed"
        return
    fi

    gh extension install dlvhdr/gh-dash ||
        warn "gh extension install dlvhdr/gh-dash failed — run it by hand"
}

smoke_test() {
    step "Checks"

    if yazi --version >/dev/null 2>&1; then
        ok "yazi parses its theme"
    else
        warn "yazi failed to start — .config/yazi/theme.toml is probably invalid"
    fi

    local ghostty=/Applications/Ghostty.app/Contents/MacOS/ghostty
    if [ -x "$ghostty" ]; then
        if "$ghostty" +validate-config --config-file="$HOME/.config/ghostty/config" >/dev/null 2>&1; then
            ok "ghostty config valid"
        else
            warn "ghostty config failed validation"
        fi
    else
        warn "Ghostty.app not found"
    fi

    local lgdir
    lgdir="$(XDG_CONFIG_HOME="$HOME/.config" lazygit --print-config-dir 2>/dev/null || true)"
    if [ "$lgdir" = "$HOME/.config/lazygit" ]; then
        ok "lazygit reads $lgdir"
    else
        warn "lazygit config dir is '$lgdir', expected $HOME/.config/lazygit"
    fi

    if rtk gain >/dev/null 2>&1; then
        ok "rtk works ($(rtk --version 2>/dev/null))"
    else
        warn "'rtk gain' failed — you may have reachingforthejack/rtk (Rust Type Kit) instead"
    fi

    if have codegraph && codegraph --version >/dev/null 2>&1; then
        ok "codegraph works ($(codegraph --version 2>/dev/null))"
    else
        warn "codegraph missing or not runnable"
    fi

    if jq -e '.mcpServers.codegraph' "$HOME/.claude.json" >/dev/null 2>&1; then
        ok "codegraph MCP server registered in ~/.claude.json"
    else
        warn "codegraph not in ~/.claude.json — run 'codegraph install'"
    fi

    local missing=() bin
    for bin in sesh tmux nvim cliamp jq gh stow zoxide fzf; do
        have "$bin" || missing+=("$bin")
    done
    if [ ${#missing[@]} -eq 0 ]; then
        ok "all binaries on PATH"
    else
        warn "not on PATH: ${missing[*]}"
    fi
}

summary() {
    step "Done"

    if [ ${#WARNINGS[@]} -gt 0 ]; then
        printf '    %s%d warning(s):%s\n' "$yellow" "${#WARNINGS[@]}" "$reset"
        printf '      - %s\n' "${WARNINGS[@]}"
        printf '\n'
    fi

    info "open a new terminal and run 't' to build the tmux session layout"
}

# ------------------------------------------------------------------- main ----

preflight
request_sudo
install_clt
install_homebrew
update_homebrew
install_packages
install_node
install_rust
link_openjdk
make_projects_dir
deploy_stow
install_tpm
write_secrets
bootstrap_zsh
bootstrap_nvim
init_rtk
install_claude_plugin
install_codegraph
wire_codegraph
auth_gh
install_gh_dash
smoke_test
summary
