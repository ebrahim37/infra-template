#!/bin/bash
# Claude Code hook: publish to ntfy when Claude needs the user's attention.
# Wired to PermissionRequest, PreToolUse (AskUserQuestion|ExitPlanMode) and
# Notification (idle_prompt|elicitation_dialog) in ~/.claude/settings.json.

ntfy_url="${CLAUDE_NTFY_URL:-http://100.64.0.1:2586/omp}"

input=$(cat)

event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
notification=$(printf '%s' "$input" | jq -r '.message // empty')
dir="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty')}"
project="${dir##*/}"

case "$event:$tool" in
  # These two are announced by PreToolUse below, so skip them here to avoid
  # sending two notifications if they also go through the permission flow.
  PermissionRequest:AskUserQuestion | PermissionRequest:ExitPlanMode) exit 0 ;;
  PermissionRequest:*)
    message="Approval required for $tool in $project."
    tags="robot,warning"
    ;;
  PreToolUse:AskUserQuestion)
    message="Claude is waiting for your answer in $project."
    tags="robot,speech_balloon"
    ;;
  PreToolUse:ExitPlanMode)
    message="Claude has a plan for you to review in $project."
    tags="robot,clipboard"
    ;;
  *)
    message="${notification:-Claude needs your attention} ($project)"
    tags="robot,bell"
    ;;
esac

curl -sS -m 5 -o /dev/null \
  -H "Title: Claude Code on ${HOSTNAME:-$(hostname)}" \
  -H "Priority: high" \
  -H "Tags: $tags" \
  --data-binary "$message" \
  "$ntfy_url"
