# if not running interactively, don't do anything
[[ $- != *i* ]] && return

export EDITOR=vi
export VISUAL=vi

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"
export PATH="$HOME/scripts:$PATH"

export PS1='\[\e[31m\][\[\e[33m\]\u\[\e[32m\]@\[\e[34m\]\h \[\e[35m\]\W\[\e[31m\]]\[\e[m\]\$ '

alias nvim="nvi"

alias sc="systemctl --user"
alias jc="journalctl --user -u"
alias ssc="sudo systemctl"
alias jjc="journalctl -u"

alias hsc="run-host systemctl --user"
alias hjc="run-host journalctl --user -u"
alias hssc="run-host-root systemctl"
alias hjjc="run-host journalctl -u"

alias clean-cache="sudo apt-get clean && pnpm store prune"
alias pa="run-host podman attach "
