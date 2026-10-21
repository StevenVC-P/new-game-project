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

START_TIME=$(date +%s)

echo "Godot executable: $GODOT_CMD"
echo "Project path: $PROJECT_ROOT"
echo "Command: \"$GODOT_CMD\" --headless --import --path \"$PROJECT_ROOT\""
echo "Validation mode: headless editor import pass; does not run the main scene."

# The --import mode starts the editor import pipeline, waits for resources to import,
# and exits automatically without entering gameplay runtime.
set +e
"$GODOT_CMD" --headless --import --path "$PROJECT_ROOT"
EXIT_CODE=$?
set -e

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo "Exit code: $EXIT_CODE"
echo "Elapsed time: ${ELAPSED}s"

if [ "$EXIT_CODE" -ne 0 ]; then
	echo "ERROR: Godot validation failed with exit code $EXIT_CODE." >&2
	exit "$EXIT_CODE"
fi

echo "Godot validation completed successfully."
