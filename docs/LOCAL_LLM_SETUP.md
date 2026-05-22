# Local LLM Setup And Cost Control

This project is configured for local-first agent-assisted development, but this check did not find an active local inference runtime on this machine.

## Detection Summary

Checked from PowerShell in the project root on `develop`.

### Detected Local Runtimes

No local inference CLI was detected on `PATH`.

Commands checked:

```powershell
Get-Command ollama -ErrorAction SilentlyContinue
Get-Command lmstudio -ErrorAction SilentlyContinue
Get-Command local-ai -ErrorAction SilentlyContinue
Get-Command localai -ErrorAction SilentlyContinue
```

Result:

```text
No matching commands found.
```

Process and port checks also did not find a running local inference runtime.

Commands checked:

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'ollama|lm studio|lmstudio|localai|local-ai|llama|kobold|text-generation|jan' }
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 11434,1234,8080,5001,7860,8000,8081 }
```

Result:

```text
No matching local runtime processes or common inference ports found.
```

### Detected Local Endpoints

Common local inference endpoints were checked:

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2
Invoke-RestMethod -Uri 'http://127.0.0.1:1234/v1/models' -TimeoutSec 2
Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/models' -TimeoutSec 2
```

Result:

```text
No endpoint responded within the timeout.
```

Expected defaults:

- Ollama: `http://127.0.0.1:11434`
- LM Studio local server: `http://127.0.0.1:1234/v1`
- LocalAI: commonly `http://127.0.0.1:8080/v1`

### Detected Local Models

No local models were detected because no local model runtime was found or reachable.

Once a runtime is installed and running, use the matching command:

```powershell
ollama list
```

or for an OpenAI-compatible local server:

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:1234/v1/models'
Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/models'
```

## Current Inference Mode

Current Codex execution appears to be hosted/cloud inference with local filesystem and shell tools.

Evidence:

- No local inference runtime or endpoint was detected.
- The environment exposes Codex session variables such as `CODEX_THREAD_ID`.
- The current agent can run local commands, but the model itself is not served by a detected local runtime.

Practical meaning:

- File edits and shell commands are local.
- Model inference for this Codex session should be treated as hosted/cloud, not local.
- Use bounded prompts and commits to control cost and risk.

## Recommended Setup For This Machine

Recommended local-first setup:

1. Install one local runtime manually.
   - Ollama is the simplest command-line option.
   - LM Studio is a good desktop option with an OpenAI-compatible local server.
   - LocalAI is useful if you want a server-style runtime, often through containers.
2. Install or download one coding-capable model.
3. Verify the runtime is reachable before using it for project work.
4. Use the local runtime for repetitive, low-risk, or documentation-heavy tasks.
5. Keep hosted/cloud Codex for architecture, difficult debugging, reviews, and tasks that need stronger reasoning.

Do not install runtimes automatically from agent scripts. Installation should be a deliberate user action.

## Recommended Local Coding Model Options

Pick models based on available RAM/VRAM and acceptable speed.

Good starting options:

- `qwen2.5-coder:7b` or newer Qwen Coder 7B-class models for lightweight coding tasks.
- `qwen2.5-coder:14b` or newer 14B-class coder models if the machine has enough memory.
- `deepseek-coder` or newer DeepSeek coder variants where supported by the local runtime.
- `llama`/`codellama` coder-tuned variants for broad local code assistance.

Use smaller models for:

- Summaries.
- Task-file drafting.
- Documentation cleanup.
- Simple grep-and-edit tasks.

Use stronger hosted/cloud models for:

- Cross-system architecture.
- Hard Godot debugging.
- Large refactors.
- Code review.
- Ambiguous design decisions.

## How To Test A Local Prompt

### Ollama

After installing Ollama and pulling a model:

```powershell
ollama list
ollama run <model> "Reply with one sentence confirming local inference works."
```

Replace `<model>` with a model from `ollama list`.

### LM Studio

In LM Studio:

1. Download a model.
2. Start the local server.
3. Check models through the OpenAI-compatible endpoint:

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:1234/v1/models'
```

If using a client that can call OpenAI-compatible APIs, point it at:

```text
http://127.0.0.1:1234/v1
```

### LocalAI

If LocalAI is running on the common default port:

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/models'
```

Use the actual configured port if different.

## Tool Access Limitations

A local model by itself usually cannot edit files, run commands, or commit changes. It needs a wrapper that provides tool access.

Examples:

- Chat-only local app: can answer prompts but cannot inspect the repo unless context is pasted in.
- Local OpenAI-compatible server: provides inference only; file and shell access depend on the client.
- Coding-agent wrapper: can combine local inference with repo reads, edits, validation commands, and commits.

For this project, local models should follow `AGENTS.md` and task files under `tasks/`.

## Avoiding Token-Burning Loops

Use bounded tasks:

- Give one clear goal.
- Name expected files.
- Name files that must not be touched.
- Include acceptance criteria.
- Include the validation command.
- Require a diff summary.
- Require a commit for meaningful changes.

Avoid open-ended prompts:

- Do not ask an agent to "keep improving" without a stopping condition.
- Do not run "continue forever" workflows.
- Do not ask for broad refactors without a branch, scope, and rollback plan.
- Stop after validation, diff summary, and commit.

Recommended task shape:

```text
Goal:
Scope:
Files likely involved:
Files not allowed:
Acceptance criteria:
Validation command:
Rollback notes:
```

## Project Validation Command

Use the Godot import validation before committing meaningful changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

If Godot is not on `PATH`, set `GODOT_BIN` first:

```powershell
$env:GODOT_BIN = "C:\Path\To\Godot.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```
