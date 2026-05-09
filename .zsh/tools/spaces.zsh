# Spaces — tab-title state convention helper.
# Usage:
#   spaces_state run "task name"
#   spaces_state wait
#   spaces_state done
#   spaces_state err
#   spaces_state idle
#
# Emits the OSC title escape that core/agents.lua parses. Safe outside iTerm:
# the escape is harmless if no terminal interprets it.
spaces_state() {
  local state="${1:-idle}"
  local title="${2:-}"
  printf '\033]0;[spaces:%s] %s\007' "$state" "$title"
}
