# Agent Workflow

This repository is a Godot project. Agent work should preserve the project structure, avoid generated cache files, and keep gameplay changes isolated behind branches and commits.

## Working Rules

- Start every meaningful change from a named branch.
- Keep `.godot/`, `.godot-exe`, and other local machine state out of commits.
- Do not modify gameplay scripts for documentation-only tasks.
- Run validation before reporting work complete when a Godot executable is available.
- Commit each meaningful change with a clear message and a concise diff summary.
- Prefer small, reviewable changes with explicit acceptance criteria.

## Validation

Use the repository validation script when possible:

```powershell
.\scripts\check-godot.ps1
```

If Godot is not on `PATH`, provide it through `GODOT_EXE`, pass `-GodotExe`, or create a local `.godot-exe` file. The `.godot-exe` file is intentionally ignored by git.

## Agent Runtime Verification

This section exists to prove the workflow is backed by an actual model-driven agent process, not only documentation scaffolding. Use the checklist in `docs/AGENT_RUNTIME_CHECKLIST.md` to record the commands and results.

### Codex CLI Verification

Verify the Codex agent can perform a bounded repo task end to end:

1. Confirm Codex is installed.
   - Run `codex --version` if `codex` is available on `PATH`.
   - If the command is missing, document that the CLI is not installed or not on `PATH`.
2. Confirm the user is authenticated.
   - Run the Codex authentication/status command supported by the installed CLI.
   - If the CLI version does not expose a status command, document how authentication was confirmed.
3. Confirm Codex can read the repo.
   - Ask Codex to inspect `README.md`, `project.godot`, and `scripts/check-godot.ps1`.
   - The agent should report what it found without editing files.
4. Confirm Codex can create a test branch.
   - Use a branch such as `agent/proof-of-work`.
   - Do not overwrite or delete existing branches.
5. Confirm Codex can make a harmless file edit.
   - Add or update `docs/AGENT_PROOF_OF_WORK.md`.
   - Do not modify gameplay code for the proof task.
6. Confirm Codex can run the validation script.
   - Attempt `.\scripts\check-godot.ps1`.
   - Record the result, including missing Godot executable or environment setup failures.
7. Confirm Codex can summarize the diff.
   - Run `git diff --stat` and `git diff -- docs/AGENT_PROOF_OF_WORK.md`.
   - The agent should summarize changed files, validation status, and commit hash if committed.

### Local LLM Verification

Verify whether a local model runtime can support agent-style work:

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
- Use Codex or another cloud model for planning, architecture, hard debugging, and review.
- Never run open-ended "continue forever" tasks.
- Use bounded tasks with clear acceptance criteria.
- Require branches and commits for every meaningful change.
