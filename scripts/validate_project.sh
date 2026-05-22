#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PROJECT_FILE="$PROJECT_ROOT/project.godot"

if [ ! -f "$PROJECT_FILE" ]; then
	echo "ERROR: project.godot was not found at: $PROJECT_FILE" >&2
	exit 1
fi

GODOT_CMD="${GODOT_BIN:-}"

if [ -z "$GODOT_CMD" ]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT_CMD="godot"
	else
		echo "ERROR: Godot executable not configured. Set GODOT_BIN to the full Godot executable path or put godot on PATH." >&2
		exit 1
	fi
fi

echo "Using Godot: $GODOT_CMD"
echo "Checking project: $PROJECT_ROOT"

"$GODOT_CMD" --headless --editor --quit --path "$PROJECT_ROOT"

echo "Godot validation completed successfully."
