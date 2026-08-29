ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
ZVM_CURSOR_STYLE_ENABLED=false
zinit light jeffreytse/zsh-vi-mode
zinit light Aloxaf/fzf-tab

autoload -Uz compinit && compinit
zinit cdreplay -q

bindkey -M vicmd '^I' autosuggest-accept
bindkey -M vicmd 'k' history-search-backward
bindkey -M vicmd 'j' history-search-forward

HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE

setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups

zstyle ':completion:*' matcher-list 'm:{a-z}={a-zA-Z}'
zstyle ':completion:*' list-colors '${(s.:.)LS_COLORS}'
zstyle ':completion:*' menu no

function tmux_base {
    tmux new-session -d -s main -c ~
    tmux send-keys -t main "yazi" C-m

    tmux new-window -t main -c ~

    sesh connect -s dotfiles

    tmux new-session -d -s music -c ~ "$HOME/.config/tmux/scripts/cliamp-launch.sh"
    tmux set-option -t music detach-on-destroy on

    tmux attach-session -d -t main
}

alias vi=nvim
alias vim=nvim
alias l='ls -la --color'
alias u='cd ..'
alias c='clear'
alias q='exit'
alias t='tmux attach || tmux_base'
alias y='yazi'
alias v='nvim .'
alias g='lazygit'
alias d='lazydocker'
alias p='gh dash'
alias r='claude --resume'

if [[ "$(uname -s)" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    export PATH="$(brew --prefix rustup)/bin:$PATH"
fi

eval "$(zoxide init --cmd cd zsh)"
setopt prompt_subst

typeset -g _prompt_colour=4
typeset -g _prompt_symbol='❯'
function _prompt_exit_colour { (( $? == 0 )) && _prompt_colour=4 || _prompt_colour=1 }
precmd_functions+=(_prompt_exit_colour)

PROMPT=$'\n%F{$_prompt_colour}$_prompt_symbol%f '

function zvm_after_select_vi_mode {
  case $ZVM_MODE in
    $ZVM_MODE_NORMAL) _prompt_symbol='❮' ;;
    *)                _prompt_symbol='❯' ;;
  esac
}

eval "$(fzf --zsh)"

export EDITOR=nvim
export XDG_CONFIG_HOME="$HOME/.config"
export N_PREFIX="$HOME/.local"
export PATH="$N_PREFIX/bin:$HOME/.cargo/bin:$(go env GOPATH)/bin:$PATH"

[[ ! -f ~/.zsh_extra ]] || source ~/.zsh_extra
