# if not running interactively, don't do anything
[[ $- != *i* ]] && return

export EDITOR=nvi
export VISUAL=nvi

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"
export PATH="$HOME/scripts:$PATH"

export PS1='\[\e[31m\][\[\e[33m\]\u\[\e[32m\]@\[\e[34m\]\h \[\e[35m\]\W\[\e[31m\]]\[\e[m\]\$ '

case ${TERM} in
	xterm*|rxvt*|Eterm|aterm|kterm|gnome*|foot*)
		PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033]0;%s@%s:%s\007" "$USER" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
		;;
esac

alias nvim="nvi"

alias rcs="rc-status"
alias rcl="sudo tail -f /var/log/messages"

alias hsc="run-host systemctl --user"
alias hjc="run-host journalctl --user -u"
alias hssc="run-host-root systemctl"
alias hjjc="run-host journalctl -u"

alias clean-cache="sudo apk cache clean && pnpm store prune"
alias pa="run-host podman attach"
