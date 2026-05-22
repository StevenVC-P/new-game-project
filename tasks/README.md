# Task Files

Use this folder for bounded task specs that future local agents or human contributors can execute safely.

Each task file should include:

## Goal

Describe the outcome in one or two sentences.

## Scope

List what is included and what is intentionally out of scope.

## Files Likely Involved

Name expected files or folders. Use this as guidance, not permission for broad rewrites.

## Acceptance Criteria

Describe observable results that prove the task is complete.

## Validation Steps

List commands, scenes, or manual checks to run before committing. Include expected results where practical.

## Checkpoint Cadence

For implementation tasks, define when the agent should create reviewable checkpoint commits. Use milestone-based checkpoints with a 30-45 minute maximum gap.

Examples:

- After adding a system skeleton.
- After wiring UI.
- After passing validation.
- After completing a vertical slice.
- Before attempting a risky refactor.
- After fixing a validation failure.

Checkpoint commits are only for clean, reviewable progress. Do not commit a broken system-error state merely because the time limit was reached.

## Failure Policy

If roughly 45 minutes pass without a working/reviewable state, the agent should roll back to the previous clean commit/state, preserve a written note of what was attempted, and report the blocker.

If the agent makes three attempts to solve the same issue without meaningful progress, it must stop, roll back to the previous clean commit if needed, and write a note explaining:

- What it attempted.
- What failed.
- Current suspected cause.
- Files touched during the attempts.
- Recommended next human/Codex decision.

If rollback itself is unsafe or ambiguous, stop immediately and report instead of trying more changes.

Failed experiments may be documented, but should not be committed as normal checkpoints unless explicitly requested.

## Notes

Document assumptions, risks, or follow-up tasks.
