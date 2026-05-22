# Local Agent Runtime Checklist

Use this checklist to verify that the coding-agent workflow is backed by a local model runtime with bounded tool access. Record the command used and the observed result for each step.

Cloud-backed agents and hosted model calls are outside the default setup. Use them only when the user explicitly opts in for a specific bounded task.

## Local Agent Wrapper

Check for any local agent wrapper the user intentionally installed. Do not install new tools from this checklist unless the user explicitly asks.

Common checks:

```powershell
Get-Command aider -ErrorAction SilentlyContinue
Get-Command interpreter -ErrorAction SilentlyContinue
Get-Command continue -ErrorAction SilentlyContinue
```

If a local agent wrapper is found, record its version using that tool's documented command. Examples:

```powershell
aider --version
interpreter --version
```

Result:

```text
TODO
```

## Local LLM Runtime

### Check for Ollama

PowerShell:

```powershell
Get-Command ollama -ErrorAction SilentlyContinue
```

If found:

```powershell
ollama --version
ollama list
```

Small prompt, replacing `<model>` with a model from `ollama list`:

```powershell
ollama run <model> "Reply with one sentence confirming local inference works."
```

Result:

```text
TODO
```

### Check for LM Studio

PowerShell:

```powershell
Get-Command lmstudio -ErrorAction SilentlyContinue
```

If no CLI is found, check the LM Studio desktop app manually and record:

- Installed or not installed
- Models downloaded
- Whether the local server is enabled
- The exact test prompt used

Result:

```text
TODO
```

### Check for Another Local Runtime

Record the runtime name, version command, model-list command, and prompt command. Do not invent commands for tools that are not installed.

Runtime:

```text
TODO
```

Commands:

```text
TODO
```

Result:

```text
TODO
```

## Repo Access

### Confirm the Agent Can Read This Repo

Ask the local agent wrapper to inspect repository files without editing them:

```text
Read README.md, project.godot, and scripts/check-godot.ps1. Summarize what this project is and how validation is run. Do not edit files.
```

Optional shell checks for the same files:

```powershell
Test-Path README.md
Test-Path project.godot
Test-Path .\scripts\check-godot.ps1
```

Result:

```text
TODO
```

### Confirm the Agent Can Create a Test Branch

Check the current branch:

```powershell
git branch --show-current
```

Create the proof branch only if it does not already exist:

```powershell
git branch --list agent/proof-of-work
git switch -c agent/proof-of-work
```

If the branch already exists, switch to it instead:

```powershell
git switch agent/proof-of-work
```

Result:

```text
TODO
```

### Confirm the Agent Can Make a Harmless File Edit

The proof edit must only add or update:

```text
docs/AGENT_PROOF_OF_WORK.md
```

The file should include:

- Timestamp
- Active branch
- Validation command attempted
- Validation result
- Diff summary

Do not modify gameplay code for this proof task.

Result:

```text
TODO
```

### Confirm the Agent Can Run Validation

Attempt the repository validation script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

If Godot is not globally available, configure `GODOT_BIN`:

```powershell
$env:GODOT_BIN = "C:\Path\To\Godot.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

Do not assume the path exists. Record missing executable, missing `GODOT_BIN`, or permission failures as valid verification results.

Result:

```text
TODO
```

### Confirm the Agent Can Summarize the Diff

Commands:

```powershell
git diff --stat
git diff -- docs/AGENT_PROOF_OF_WORK.md
```

After committing:

```powershell
git show --stat --oneline --summary HEAD
```

Result:

```text
TODO
```

### Tool and File Access

Document whether the local model can access tools and files directly or only through a wrapper.

Examples:

- Direct CLI agent with shell/file tools: can inspect and edit repo files under user control.
- Local chat app only: can answer prompts but cannot read files, run validation, or commit without copied context or an external wrapper.
- Local OpenAI-compatible server: can provide inference, but file/tool access depends on the client connected to it.

Result:

```text
TODO
```

## Cost-Control Guidance

- Use local LLMs for repetitive, low-risk edits and summaries.
- Keep hosted/cloud models disabled by default.
- Use a cloud model only when the user explicitly opts in for a bounded planning, architecture, hard debugging, or review task.
- Avoid open-ended prompts such as "continue forever" or "keep improving this."
- Use bounded tasks with acceptance criteria, expected files, and stopping conditions.
- Require branches and commits for every meaningful change.

## Real Implementation Workflow

A local agent may make real code, scene, UI, test, and documentation changes when explicitly assigned.

- Real implementation requires a feature branch.
- `main` must not be edited directly.
- Work should begin from `develop` unless instructed otherwise.
- The agent may edit scripts, scenes, UI, documentation, tests, resources, and project wiring as needed to complete the assigned goal.
- Important/protected files may be edited only when explicitly listed in the task scope.
- The agent should avoid unnecessary rewrites, renames, deletions, or broad refactors unless clearly useful for the assigned goal.
- If a refactor is needed, it should be done in a checkpointed way.
- The agent must make checkpoint commits.
- The agent must run validation/tests before checkpoint commits when practical.
- Final reports must include branch, commit hashes, changed files, validation results, assumptions, and open questions.
- `main` receives changes only through reviewed feature branches.
- The agent must report what changed, what worked, what failed, and what remains.

## Checkpoint Requirements

Checkpoints are reviewable commits.

- Use milestone-based checkpoints with a 30-45 minute maximum gap.
- Checkpoints should be frequent enough that the owner can redirect the project without losing hours of work.
- Checkpoint commits are only for clean, reviewable progress.
- Checkpoint commits should be meaningful and not hide unrelated changes.
- If validation fails at a checkpoint, the agent should either fix within scope or stop and report.
- If the project is in a system-error state, validation is failing, imports are broken, or the feature cannot run, do not create a checkpoint commit merely because the time limit was reached.
- If roughly 45 minutes pass without a working/reviewable state, roll back to the previous clean commit/state, preserve a written note of what was attempted, and report the blocker.
- A failed experiment may be documented, but should not be committed as a normal checkpoint unless explicitly requested.
- Rollback means returning code to the previous clean commit/state before the failing attempt, while preserving a written summary of the failure in the final report or an approved docs note.
- The agent should not hide failed attempts; it should report them clearly.
- If rollback itself is unsafe or ambiguous, the agent should stop immediately and report instead of trying more changes.
- Each checkpoint report should name the branch, commit hash, changed files, validation result, behavior changed, assumptions, open questions, and known risks.

## Three-Attempt Stop Rule

If the agent makes three attempts to solve the same issue without meaningful progress, it must stop, roll back to the previous clean commit if needed, and write a note explaining:

- What it attempted.
- What failed.
- Current suspected cause.
- Files touched during the attempts.
- Recommended next human/Codex decision.

## Proof Task Scope Enforcement

A proof task is only a workflow verification.

- By default, a proof task may only add or update `docs/AGENT_PROOF_OF_WORK.md`.
- Any change to `AGENTS.md`, validation scripts, project files, gameplay scripts, scenes, resources, or import settings is outside default proof scope and must be separately approved.
- A successful validation exit code does not automatically approve out-of-scope file changes.
- This proof-task restriction does not prevent later real implementation tasks. It only keeps proof verification clean.
- The proof report must include git status, `git diff --stat`, validation command/result, current branch, commit hash if committed, and an explicit list of assumptions.
- If toolchain changes are required, stop and create a separate tooling task before continuing the proof run.

## Proof Task

A real agent should perform this harmless proof task without touching gameplay code:

1. Create branch `agent/proof-of-work`.
2. Add or update `docs/AGENT_PROOF_OF_WORK.md`.
3. Include timestamp, active branch, git status, `git diff --stat`, validation command attempted, validation result, assumptions, and commit hash if committed.
4. Commit with message `test: verify agent runtime workflow`.
5. Report the diff summary and explicitly confirm whether only `docs/AGENT_PROOF_OF_WORK.md` changed.

Suggested command sequence:

```powershell
git branch --show-current
git branch --list agent/proof-of-work
git switch -c agent/proof-of-work
```

If the branch already exists:

```powershell
git switch agent/proof-of-work
```

After editing `docs/AGENT_PROOF_OF_WORK.md`:

```powershell
git status --short --branch
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
git status --short
git diff --stat
git add docs/AGENT_PROOF_OF_WORK.md
git commit -m "test: verify agent runtime workflow"
git show --stat --oneline --summary HEAD
```

Use the project's preferred validation script, but record the exact command used.

Do not perform destructive changes. Do not modify gameplay code, validation scripts, project files, scenes, resources, import settings, or governance docs for the default proof task unless separately approved.
