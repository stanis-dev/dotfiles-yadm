fpath=("/Users/stan/.oh-my-zsh/custom/completions" $fpath)
autoload -Uz compinit
compinit

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(
  git
  z
  colorize
  docker
  docker-compose
)
source $ZSH/oh-my-zsh.sh

export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/node@24/lib"
export CPPFLAGS="-I/opt/homebrew/opt/node@24/include"

export EDITOR='nvim'
export VISUAL='nvim'

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

alias v="nvim"
alias pimin='pi --no-session --no-context-files --no-skills --no-extensions --no-prompt-templates --no-themes --no-tools --thinking off --system-prompt "Be concise."'
export PATH="$HOME/.local/bin:$PATH"

[ -s "/Users/stan/.bun/_bun" ] && source "/Users/stan/.bun/_bun"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PLAYWRITER_AUTO_ENABLE=1
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

[[ -n $CLAUDECODE && ! -o interactive ]] && unsetopt nomatch
