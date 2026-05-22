# Local Agent Workflow

This repository is a Godot project. Coding-agent work is intended to run locally by default, using local tools, local git branches, and local model runtimes where available. Agent work should preserve the project structure, avoid generated cache files, and keep gameplay changes isolated behind branches and commits.

Cloud-backed agents or hosted model calls are not part of the default workflow. Use them only when explicitly requested for a bounded task.

## Godot Assumptions

- Project file: `project.godot`
- Main scene: `main.tscn`
- Godot feature tag: `4.6`
- Renderer feature: Forward Plus
- Physics engine setting: Jolt Physics
- Assumption: use a Godot 4.x executable compatible with the `4.6` project feature tag.
- Do not hard-code a Godot executable path. Validation scripts use `GODOT_BIN`.

## Working Rules

- Start every meaningful change from a named branch.
- Work from `develop` for ongoing development.
- Do not edit `main` directly.
- Keep `.godot/`, `.godot-exe`, and other local machine state out of commits.
- Do not modify gameplay scripts for documentation-only tasks.
- Run validation before reporting work complete when a Godot executable is available.
- Commit each meaningful change with a clear message and a concise diff summary.
- Prefer small, reviewable changes with explicit acceptance criteria.
- Keep agent setup local-only unless the user explicitly opts into a cloud-backed model for a specific task.
- Do not use destructive git rewrites such as force-push, reset, rebase, or history editing unless the user explicitly asks for that operation.
- Do not delete files without explicit instruction.
- Prefer additive, modular changes over broad rewrites.
- Add isolated test or demo scenes for new features when practical.
- If a setup choice is ambiguous, document the assumption here instead of making an invasive change.

## Branch Rules

- `main` is the stable baseline branch and should only receive reviewed or intentionally merged work.
- `backup/pre-agent-baseline` preserves the pre-agent setup baseline.
- `develop` is the integration branch for active development.
- Feature work should use named branches from `develop`, such as `feature/<short-name>`, `fix/<short-name>`, or `agent/<short-name>`.
- Every meaningful change should end in a commit with a clear message.
- Before committing, run validation or document why validation could not run.

## Validation

Use the repository validation script when possible:

```powershell
.\scripts\validate_project.ps1
```

On shells that support `sh`, use:

```sh
./scripts/validate_project.sh
```

Set `GODOT_BIN` to the full Godot executable path if Godot is not on `PATH`.

The validation scripts run Godot with `--headless --import --path <project>`. This is a safe, non-interactive Godot 4.x editor import pass that waits for resources to import and exits automatically without entering the main scene or gameplay loop.

Known limitation: Godot does not provide a single perfect "validate the whole project without running anything" mode. The import pass is the default pre-commit validation because it catches project loading, import, and many script parse/compile issues. It does not prove all gameplay paths are correct; use targeted demo/test scenes or manual checks for feature behavior.

The older `scripts/check-godot.ps1` helper also exists and supports `GODOT_EXE`, `-GodotExe`, and local `.godot-exe` workflows.

## Agent Runtime Verification

This section exists to prove the workflow is backed by an actual local model-driven agent process, not only documentation scaffolding. Use the checklist in `docs/AGENT_RUNTIME_CHECKLIST.md` to record the commands and results.

## Codex And Local Agent Roles

- Codex is for planning, architecture, owner questions, task definition, and review.
- The local LM Studio agent is for bounded implementation on explicit feature branches.
- The local agent must only work from explicit task files or handoff prompts.
- Do not start open-ended local-agent work.
- No overnight local-agent run should exceed the configured task or time limit.
- Stop local-agent work at the first missing product decision, validation failure, forbidden-file need, or unclear rollback path.

### Local Agent Verification

Verify the local agent can perform a bounded repo task end to end:

1. Confirm a local agent wrapper or local LLM runtime is installed.
   - Check for tools such as Ollama, LM Studio, Continue, Aider, Open Interpreter, or another explicitly chosen local setup.
   - Document missing tools instead of assuming they are installed.
2. Confirm the local runtime has at least one model available.
   - For Ollama, use `ollama list`.
   - For LM Studio, use the desktop app or its documented CLI/server status.
3. Confirm the agent can read the repo through the local wrapper or through copied context.
   - Ask the agent to inspect `README.md`, `project.godot`, and `scripts/check-godot.ps1`.
   - The agent should report what it found without editing files.
4. Confirm the agent can create a test branch through approved local shell access.
   - Use a branch such as `agent/proof-of-work`.
   - Do not overwrite or delete existing branches.
5. Confirm the agent can make a harmless file edit.
   - Add or update `docs/AGENT_PROOF_OF_WORK.md`.
   - Do not modify gameplay code for the proof task.
6. Confirm the agent can run the validation script through local shell access.
   - Attempt `.\scripts\check-godot.ps1`.
   - Record the result, including missing Godot executable or environment setup failures.
7. Confirm the agent can summarize the diff.
   - Run `git diff --stat` and `git diff -- docs/AGENT_PROOF_OF_WORK.md`.
   - The agent should summarize changed files, validation status, and commit hash if committed.

### Local LLM Verification

Verify whether a local model runtime can support agent-style work without relying on hosted inference:

1. Check whether Ollama, LM Studio, or another local runtime is installed.
   - Try version or help commands only when the tool exists on `PATH`.
   - Example checks: `ollama --version`, `lmstudio --version`, or the runtime's documented equivalent.
2. Check which local models are available.
   - For Ollama, use `ollama list`.
   - For LM Studio, use the installed app or its documented CLI/server endpoint.
   - For any other runtime, record the exact command or UI path used.
3. Document the command used to run a small local prompt.
   - Example for Ollama: `ollama run <model> "Reply with one sentence confirming local inference works."`
   - Replace `<model>` with a model actually listed on the machine.
4. Document whether the local model can access tools/files directly or only through a wrapper.
   - Most local chat runtimes only answer prompts.
   - Repo reads, file edits, shell commands, and commits usually require an agent wrapper or CLI integration.

### Cost-Control Guidance

- Default to a local LLM for repetitive or low-risk tasks when it is capable enough.
- Keep hosted/cloud models disabled by default.
- Use a cloud model only when the user explicitly opts in for planning, architecture, hard debugging, or review.
- Never run open-ended "continue forever" tasks.
- Use bounded tasks with clear acceptance criteria.
- Require branches and commits for every meaningful change.
