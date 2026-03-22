#!/usr/bin/env bash
# Setup relamo skills for cross-platform discovery.
# Creates symlinks from skills/* into each platform's skill directory.
#
# Usage: ./scripts/setup-platforms.sh
#
# Platforms:
#   .agents/skills/  — Codex CLI + Cursor cross-client interop
#   .gemini/skills/  — Gemini CLI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SOURCE="$PROJECT_ROOT/skills"

if [ ! -d "$SKILLS_SOURCE" ]; then
  echo "Error: $SKILLS_SOURCE not found. Run this script from the relamo project root." >&2
  exit 1
fi

TARGETS=(
  "$PROJECT_ROOT/.agents/skills"
  "$PROJECT_ROOT/.gemini/skills"
)

for target_dir in "${TARGETS[@]}"; do
  echo "Setting up $target_dir"
  mkdir -p "$target_dir"
  for skill_dir in "$SKILLS_SOURCE"/*/; do
    skill_name="$(basename "$skill_dir")"
    link_path="$target_dir/$skill_name"
    if [ -L "$link_path" ]; then
      echo "  skip: $skill_name (symlink exists)"
    elif [ -e "$link_path" ]; then
      echo "  skip: $skill_name (real path exists, not overwriting)"
    else
      ln -s "$skill_dir" "$link_path"
      echo "  link: $skill_name -> $skill_dir"
    fi
  done
done

echo "Done. Skills are now discoverable by Codex CLI, Cursor, and Gemini CLI."
