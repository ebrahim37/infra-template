if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
fi

if [ -n "${SSH_TTY:-}" ] && [ -z "${TMUX:-}" ]; then
	exec tmux new-session -A -s main
fi
