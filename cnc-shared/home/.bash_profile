if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
fi

if [ -n "${SSH_TTY:-}" ] && [ -z "${TMUX:-}" ]; then
	if ! tmux has-session -t '=main' 2>/dev/null; then
		exec tmux new-session -s main \
			"bash -l; tmux detach-client -s =main"
	fi

	main_group=$(tmux display-message -p -t '=main' '#{session_group}')
	if [ -n "$main_group" ] && ! tmux list-clients -F '#{session_group}' | grep -Fqx "$main_group"; then
		exec tmux attach-session -t '=main'
	elif [ -z "$main_group" ] && ! tmux list-clients -F '#{session_name}' | grep -Fqx main; then
		exec tmux attach-session -t '=main'
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
