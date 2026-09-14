if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
fi

if [ -n "${SSH_TTY:-}" ] && [ -z "${TMUX:-}" ]; then
	if ! tmux has-session -t '=main' 2>/dev/null; then
		tmux new-session -d -s main
	fi

	ssh_tmux_session="ssh-$$"
	tmux new-session -d -s "$ssh_tmux_session" -t main
	tmux new-window -t "$ssh_tmux_session:" -c "$HOME" \
		"bash -l; tmux kill-session -t =$ssh_tmux_session"

	cleanup_ssh_tmux_session() {
		tmux kill-session -t "=$ssh_tmux_session" 2>/dev/null || true
	}
	trap cleanup_ssh_tmux_session EXIT HUP INT TERM
	tmux attach-session -t "=$ssh_tmux_session"
	exit
fi
