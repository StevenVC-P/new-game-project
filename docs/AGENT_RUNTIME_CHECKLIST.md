# Agent Runtime Checklist

Use this checklist to verify that an agent workflow is actually backed by a model runtime with bounded tool access. Record the command used and the observed result for each step.

## Codex CLI

### Confirm Codex Is Installed

PowerShell:

```powershell
Get-Command codex -ErrorAction SilentlyContinue
```

If `codex` is found:

```powershell
codex --version
```

Result:

```text
TODO
```

### Confirm Authentication

Run the authentication or status command supported by the installed Codex CLI.

Common possibilities to check:

```powershell
codex auth status
codex login
codex --help
```

Use `codex --help` if the installed CLI does not support `auth status`, then record the correct command for that version.

Result:

```text
TODO
```

### Confirm Codex Can Read This Repo

Ask Codex to inspect repository files without editing them:

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

### Confirm Codex Can Create a Test Branch

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

### Confirm Codex Can Make a Harmless File Edit

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

### Confirm Codex Can Run Validation

Attempt the repository validation script:

```powershell
.\scripts\check-godot.ps1
```

If Godot is not globally available, configure one of the supported local options:

```powershell
$env:GODOT_EXE = "C:\Path\To\Godot.exe"
.\scripts\check-godot.ps1
```

or:

```powershell
.\scripts\check-godot.ps1 -GodotExe "C:\Path\To\Godot.exe"
```

Do not assume either path exists. Record missing executable or permission failures as valid verification results.

Result:

```text
TODO
```

### Confirm Codex Can Summarize the Diff

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
- Use Codex or another cloud model for planning, architecture, hard debugging, review, and changes with higher blast radius.
- Avoid open-ended prompts such as "continue forever" or "keep improving this."
- Use bounded tasks with acceptance criteria, expected files, and stopping conditions.
- Require branches and commits for every meaningful change.

## Proof Task

A real agent should perform this harmless proof task without touching gameplay code:

1. Create branch `agent/proof-of-work`.
2. Add or update `docs/AGENT_PROOF_OF_WORK.md`.
3. Include timestamp, active branch, validation command attempted, and result.
4. Commit with message `test: verify agent runtime workflow`.
5. Report the diff summary.

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
.\scripts\check-godot.ps1
git status --short
git diff --stat
git add docs/AGENT_PROOF_OF_WORK.md
git commit -m "test: verify agent runtime workflow"
git show --stat --oneline --summary HEAD
```

Do not perform destructive changes. Do not modify gameplay code for the proof task.
