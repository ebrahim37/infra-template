const DEFAULT_NTFY_URL = "http://100.64.0.1:2586/omp";
const REQUEST_TIMEOUT_MS = 5_000;

function projectName(cwd) {
	const parts = cwd.split(/[\\/]/).filter(Boolean);
	return parts.at(-1) ?? cwd;
}

export default function ntfyAttention(pi) {
	const ntfyUrl = process.env.OMP_NTFY_URL || DEFAULT_NTFY_URL;
	const hostname = process.env.HOSTNAME || "cnc";
	const notifiedToolCalls = new Set();

	function publish(message, tags) {
		void fetch(ntfyUrl, {
			method: "POST",
			headers: {
				Title: `OMP on ${hostname}`,
				Priority: "high",
				Tags: tags,
			},
			body: message,
			signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
		}).then(response => {
			if (!response.ok) {
				pi.logger.warn("ntfy returned an HTTP error", {
					status: response.status,
					url: ntfyUrl,
				});
			}
		}).catch(error => {
			pi.logger.warn("ntfy notification failed", {
				error: String(error),
				url: ntfyUrl,
			});
		});
	}

	function publishOnce(toolCallId, message, tags) {
		if (notifiedToolCalls.has(toolCallId)) return;
		notifiedToolCalls.add(toolCallId);
		publish(message, tags);
	}

	pi.on("tool_approval_requested", (event, context) => {
		publishOnce(
			event.toolCallId,
			`Approval required for ${event.toolName} in ${projectName(context.cwd)}.`,
			"robot,warning",
		);
	});

	pi.on("tool_call", (event, context) => {
		if (event.toolName !== "ask") return;
		publishOnce(
			event.toolCallId,
			`The agent is waiting for your answer in ${projectName(context.cwd)}.`,
			"robot,speech_balloon",
		);
	});

	pi.on("tool_approval_resolved", event => {
		notifiedToolCalls.delete(event.toolCallId);
	});

	pi.on("tool_result", event => {
		notifiedToolCalls.delete(event.toolCallId);
	});
}
