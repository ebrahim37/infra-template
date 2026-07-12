# if not running interactively, don't do anything
[[ $- != *i* ]] && return

export EDITOR=vi
export VISUAL=vi

export BUN_INSTALL="$HOME/.bun"
export PATH="$PATH:$BUN_INSTALL/bin"

export PATH="$PATH:$HOME/scripts"

export PS1="\[\e[31m\][\[\e[m\]\[\e[33m\]\u\[\e[m\]\[\e[32m\]@\[\e[m\]\[\e[34m\]\h\[\e[m\] \[\e[35m\]\W\[\e[m\]\[\e[31m\]]\[\e[m\]\\$ "

alias nvim="nvi"
alias yay="ya"

alias sc="systemctl --user"
alias ssc="sudo systemctl"
alias jc="journalctl --user -u"
alias jjc="journalctl -u"

alias ports="sudo ss -lntup"
alias pa="podman attach --detach-keys=ctrl-a,ctrl-d"
alias clean-cache="ya -Yc && ya -Scc && bun pm -g cache rm"
alias caddy-reload="podman exec -w /etc/caddy caddy caddy reload"
