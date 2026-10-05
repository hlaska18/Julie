#!/bin/sh
# Háček pro Claude Code: zapíše, co zrovna dělá, do ~/.jezevcik/state (čte to Julie).
# Použití: hook.sh prompt|pre|notify|stop   (JSON od Claude Code jde na stdin)
ev="$1"
in=$(cat)
tool=$(printf '%s' "$in" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
case "$ev" in
  prompt) tok=think ;;
  notify) tok=notify ;;
  stop) tok=done ;;
  pre)
    case "$tool" in
      Bash) tok=bash ;;
      Read|Glob|Grep|LS) tok=read ;;
      Edit|Write|MultiEdit|NotebookEdit) tok=edit ;;
      WebFetch|WebSearch) tok=web ;;
      Task|Agent) tok=task ;;
      mcp__*) tok=web ;;
      *) tok=think ;;
    esac ;;
  *) exit 0 ;;
esac
mkdir -p "$HOME/.jezevcik"
printf '%s %s\n' "$tok" "$(date +%s)" > "$HOME/.jezevcik/state"
exit 0
