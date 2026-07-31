#!/usr/bin/env bash
# apply-models.sh — sync .opencode/agents/*.md `model:` fields to the
# per-agent preferences declared in config.yaml. See `--help` for usage.
set -euo pipefail

usage() {
  cat <<'EOF'
apply-models.sh — sync .opencode/agents/*.md `model:` fields to the
per-agent preferences declared in config.yaml.

Usage:
  scripts/apply-models.sh                        Apply config.yaml as-is
  scripts/apply-models.sh --status                Show current state, change nothing
  scripts/apply-models.sh --dry-run                Preview changes, write nothing
  scripts/apply-models.sh --set AGENT=MODEL        Set+persist+apply one agent
  scripts/apply-models.sh --set A=M1 --set B=M2    Repeat --set for several agents
  scripts/apply-models.sh --set AGENT=MODEL --dry-run   Preview an override only

Without --dry-run or --status, --set writes to config.yaml immediately,
then applies it. AGENT must match a file in .opencode/agents/ (its name
without the .md extension) — e.g. architect, project-manager, r-developer.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config.yaml"
AGENTS_DIR="$REPO_ROOT/.opencode/agents"

[[ -f "$CONFIG_FILE" ]] || { echo "Missing $CONFIG_FILE" >&2; exit 1; }
[[ -d "$AGENTS_DIR"  ]] || { echo "Missing $AGENTS_DIR"  >&2; exit 1; }

# Discover agents from the .md files actually present — that directory
# is the only source of truth for "which agents exist"; config.yaml
# just supplies each one's preferred model. New agent? Drop in its .md
# file and a config.yaml line; nothing here needs editing.
AGENTS=()
while IFS= read -r -d '' f; do
  AGENTS+=("$(basename "$f" .md)")
done < <(find "$AGENTS_DIR" -maxdepth 1 -name '*.md' -print0 | sort -z)
[[ ${#AGENTS[@]} -gt 0 ]] || { echo "No agent .md files found in $AGENTS_DIR" >&2; exit 1; }

is_known_agent() {
  local key="$1" a
  for a in "${AGENTS[@]}"; do [[ "$a" == "$key" ]] && return 0; done
  return 1
}

DRY_RUN=false
STATUS_ONLY=false
declare -A OVERRIDE=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --status)  STATUS_ONLY=true; shift ;;
    --set)
      spec="${2:-}"
      key="${spec%%=*}"
      value="${spec#*=}"
      if [[ -z "$spec" || "$key" == "$spec" ]]; then
        echo "Invalid --set value '$spec' (expected AGENT=MODEL)" >&2
        exit 1
      fi
      if ! is_known_agent "$key"; then
        echo "Unknown agent '$key' in --set (no .opencode/agents/${key}.md)" >&2
        exit 1
      fi
      OVERRIDE["$key"]="$value"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

config_has() { grep -qE "^${1}:" "$CONFIG_FILE"; }

config_get() {  # assumes config_has already confirmed the key exists
  local agent="$1" line
  line="$(grep -E "^${agent}:" "$CONFIG_FILE" | tail -n1)"
  sed -E "s/^${agent}:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]+$//" <<<"$line"
}

config_set() {  # rewrites the line in place, or appends if it's new
  local agent="$1" value="$2" tmp
  tmp="$(mktemp)"
  awk -v agent="$agent" -v value="$value" '
    $0 ~ "^" agent ":" && !done { print agent ": " value; done = 1; next }
    { print }
    END { if (!done) print agent ": " value }
  ' "$CONFIG_FILE" > "$tmp"
  mv "$tmp" "$CONFIG_FILE"
}

UNRESOLVED=()
CHANGED=0

for agent in "${AGENTS[@]}"; do
  file="$AGENTS_DIR/${agent}.md"
  current="$(awk '
    /^---$/ { n++ }
    n==1 && /^model:/ { sub(/^model:[[:space:]]*/, ""); print; exit }
  ' "$file")"

  if [[ -n "${OVERRIDE[$agent]:-}" ]]; then
    target="${OVERRIDE[$agent]}"
    if [[ "$DRY_RUN" == false && "$STATUS_ONLY" == false ]]; then
      config_set "$agent" "$target"
      echo "config.yaml: $agent -> $target"
    fi
  elif config_has "$agent"; then
    target="$(config_get "$agent")"
  else
    UNRESOLVED+=("$agent")
    printf '  %-16s %-24s -> %-24s %s\n' "$agent" "$current" "?" "NO CONFIG ENTRY"
    continue
  fi

  [[ "$target" == */* ]] || echo "Warning: '$agent' value '$target' doesn't look like provider/model" >&2

  mark="ok"
  if [[ "$current" != "$target" ]]; then
    mark="CHANGE"
    CHANGED=$((CHANGED + 1))
  fi
  printf '  %-16s %-24s -> %-24s %s\n' "$agent" "$current" "$target" "$mark"

  [[ "$STATUS_ONLY" == true || "$DRY_RUN" == true ]] && continue
  [[ "$current" == "$target" ]] && continue

  awk -v target="$target" '
    /^---$/ { n++; print; next }
    n==1 && /^model:/ { print "model: " target; next }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
done

# orphaned config.yaml entries: keys with no matching agent file
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if ! is_known_agent "$key"; then
    echo "Note: config.yaml has '$key', no matching .opencode/agents/${key}.md" >&2
  fi
done < <(grep -E '^[a-zA-Z0-9_-]+:' "$CONFIG_FILE" | sed -E 's/:.*//')

echo
if [[ ${#UNRESOLVED[@]} -gt 0 ]]; then
  echo "${#UNRESOLVED[@]} agent(s) have no config.yaml entry: ${UNRESOLVED[*]}"
fi
if [[ "$STATUS_ONLY" == true ]]; then
  echo "$CHANGED file(s) differ from config.yaml."
elif [[ "$DRY_RUN" == true ]]; then
  echo "$CHANGED file(s) would change. Dry run only — nothing written."
else
  echo "$CHANGED file(s) updated."
fi
if [[ ${#UNRESOLVED[@]} -gt 0 ]]; then
  exit 1
fi
