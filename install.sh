#!/usr/bin/env bash
# Install Product Discovery Skills into ~/.claude/skills/
#
# Usage:
#   ./install.sh                                    # install all skills in this repo
#   ./install.sh icp-screener                       # install one skill
#   ./install.sh icp-screener phase-map-analyst     # install several
#
# Existing skills with the same name will be replaced (the SKILL.md and any
# other files inside ~/.claude/skills/<skill>/ are overwritten with the repo
# version). The script never touches anything outside ~/.claude/skills/.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
TARGET_DIR="$HOME/.claude/skills"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "Error: skills directory not found at $SKILLS_DIR" >&2
  echo "Run this script from the repo root." >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

# Build the list of skills to install
declare -a skills_to_install
if [ "$#" -eq 0 ]; then
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    skills_to_install+=("$(basename "$d")")
  done
else
  skills_to_install=("$@")
fi

if [ "${#skills_to_install[@]}" -eq 0 ]; then
  echo "No skills found in $SKILLS_DIR." >&2
  exit 1
fi

# Install each skill
installed_count=0
for skill in "${skills_to_install[@]}"; do
  src="$SKILLS_DIR/$skill"
  dst="$TARGET_DIR/$skill"

  if [ ! -d "$src" ]; then
    echo "Unknown skill (not in $SKILLS_DIR): $skill" >&2
    continue
  fi
  if [ ! -f "$src/SKILL.md" ]; then
    echo "Skipping $skill (no SKILL.md found in $src)" >&2
    continue
  fi

  if [ -d "$dst" ]; then
    echo "Replacing: $skill"
    rm -rf "$dst"
  else
    echo "Installing: $skill"
  fi

  cp -R "$src" "$dst"
  installed_count=$((installed_count + 1))
done

echo
if [ "$installed_count" -gt 0 ]; then
  echo "Done. Installed $installed_count skill(s) to $TARGET_DIR."
  echo "Invoke them via /<skill-name> in Claude Code."
else
  echo "No skills were installed."
fi
