# Local Agent Multi-Agent Workflow

This document defines a proposed local multi-agent failure-handling workflow for the project-local agent runner. It is a design document only. It does not implement orchestration, gameplay changes, new model calls, or automatic commits.

The goal is to make local-agent failures easier to classify, repair, tune, and review without turning the runner into an open-ended autonomous system.

## Principles

- The runner keeps operational authority over files, validation, branches, staging, commits, and reports.
- Agents produce bounded analysis, task edits, or repair proposals inside runner-enforced scope.
- Downstream agents inherit the original task's allowed paths, blocked paths, budgets, and validation rules unless the owner approves a new task.
- One downstream specialist pass is the default after a failure.
- Repeated failures should produce a classification report and stop.
- No agent commits automatically.
- No agent creates new agents, new tools, or new runner capabilities without owner approval.
- Runner self-modification requires explicit owner approval and a runner-hardening task.
- Every agent pass writes or updates a report.

## Agent Roles

### Implementation Agent

Purpose: Produce the first bounded implementation attempt from an approved task file.

Inputs:

- Task file.
- Repository instructions.
- Runner constraints.
- Relevant source files and docs supplied by the runner.

Outputs:

- JSON edit manifest or unified diff, depending on task mode.
- Runner-generated report after validation or rejection.

Allowed files:

- Only the task's allowed paths.

Forbidden actions:

- Running commands directly.
- Staging, committing, merging, pushing, rebasing, or resetting.
- Editing blocked paths.
- Expanding scope beyond the task.
- Creating new agents or altering runner behavior.

Run when:

- The owner starts an explicit local-agent task.

Stop or escalate when:

- The runner rejects the manifest.
- Validation fails.
- The task requires out-of-scope files.
- The same failure repeats.
- Product or design intent is unclear.

### Repair Agent

Purpose: Repair a failed implementation attempt when the failure is local, mechanical, and still inside the original task scope.

Inputs:

- Original task file.
- Failed edit manifest or patch.
- Runner rejection messages.
- Validation logs if validation ran.
- Current diff if the runner kept failed changes.

Outputs:

- A corrected edit manifest or patch.
- Repair notes in the run report.

Allowed files:

- Original allowed paths only.
- Same-run created files may be replaced only under existing runner rules.

Forbidden actions:

- Changing the task goal.
- Adding new paths.
- Weakening blocked paths.
- Modifying gameplay formulas unless the original task explicitly allowed it.
- Touching runner code.

Run when:

- A parse error, validation parse error, or simple omitted required token can be repaired directly.
- The anchor is close but needs a small correction and exact context is available.
- A same-run created helper file needs a small syntax or type fix.

Stop or escalate when:

- The same rejection repeats.
- The model invented anchors or stub code.
- Repair requires changing task acceptance criteria.
- Repair requires main-script integration beyond the model's supplied context.

### Task Tuning Agent

Purpose: Tune a task after clean rejection when the task specification, anchors, required tokens, or file-operation instructions caused avoidable failure.

Inputs:

- Original task file.
- Runner report.
- Rejected edit manifests.
- Real source files needed to identify anchors or task conflicts.

Outputs:

- Updated task file.
- Notes explaining what was too brittle or underspecified.
- Exact command for a future rerun.

Allowed files:

- `tasks/`
- Relevant docs if the tuning itself needs documentation.

Forbidden actions:

- Implementing gameplay.
- Editing source files for the feature itself.
- Rerunning the feature task automatically.
- Weakening safety constraints without owner approval.

Run when:

- Required content was too literal.
- The task asked for nonexistent anchors.
- The task allowed an existing doc path and the model tried to create it.
- The task contained contradictory instructions.

Stop or escalate when:

- The correct task shape depends on a product decision.
- The tuned task would need broader paths or higher risk than originally approved.
- Repeated tuning does not produce a viable local-agent task.

### Integration Context Agent

Purpose: Gather exact real integration anchors and local patterns before a high-risk integration task touches files such as `scripts/main.gd`.

Inputs:

- Target integration files.
- Integration maps.
- Existing helper scripts.
- Previous failure reports.

Outputs:

- Verified Project Context section for a task.
- Exact insertion anchors copied from real files.
- Recommendation to split helper and integration if needed.

Allowed files:

- Read-only source and docs inspection.
- Task file updates only if explicitly assigned.

Forbidden actions:

- Implementing the integration unless separately assigned.
- Inventing anchors.
- Replacing large files.
- Editing domain, simulation, or world logic.

Run when:

- The task touches high-risk files.
- A prior run failed with `anchor_not_found`.
- The model generated stub anchors or fake functions.

Stop or escalate when:

- Real anchors are unstable or too broad.
- The integration requires a manual design choice.
- The safest path is a helper-only split.

### Reviewer Agent

Purpose: Review a passed local-agent output before commit or before manual integration continues.

Inputs:

- Git diff.
- Runner report.
- Edit manifest.
- Changed files.
- Validation logs.

Outputs:

- Findings or approval.
- Small repair recommendation if needed.
- Readiness assessment for commit or next step.

Allowed files:

- Read-only by default.
- Small repairs only when explicitly allowed.

Forbidden actions:

- Broad refactors.
- Reverting unrelated changes.
- Committing without owner approval when the task says not to commit.

Run when:

- A local-agent task passes validation.
- A helper-only split produced a candidate helper.
- A high-risk integration needs review before owner retest.

Stop or escalate when:

- Behavioral risk cannot be judged from validation.
- Manual runtime testing is required.
- The diff is larger or broader than expected.

### Runner Hardening Agent

Purpose: Improve the runner, docs, or task system when repeated failures reveal a deterministic tooling gap.

Inputs:

- Multiple failure reports.
- Runner source.
- Runner docs.
- Representative task files.

Outputs:

- Runner changes.
- Documentation updates.
- Backward compatibility notes.
- Validation result.

Allowed files:

- `scripts/agent_runner.ps1`
- `scripts/agent_runner.config.json`
- `docs/LOCAL_AGENT_RUNNER.md`
- Task files used as examples, when explicitly scoped.

Forbidden actions:

- Gameplay edits.
- Running feature tasks.
- Reducing safety checks silently.
- Automatic runner self-modification without owner approval.

Run when:

- Several failures share the same runner-level cause.
- Existing task syntax cannot express a safe acceptance rule.
- Reports are too vague to guide repair.

Stop or escalate when:

- The change would expand model authority over the repo.
- The change affects commits, merges, pushes, or rollback behavior.
- Backward compatibility is uncertain.

### Specialist Agent Registry

Purpose: Define approved specialist roles that can be invoked for one bounded pass when a failure needs a focused review.

Inputs:

- A specific failure class.
- A scoped task or report.
- The original allowed and blocked paths.

Outputs:

- One specialist report or proposed task tuning.

Allowed files:

- Inherited from the original task unless the owner approves a new task.

Forbidden actions:

- Creating new specialist roles without approval.
- Running more than one downstream specialist pass by default.
- Continuing after a repeated same failure.

Initial specialist types:

- Anchor Specialist: verifies real anchors and insertion points.
- Validation Specialist: reads validation errors and maps them to likely script or import causes.
- Scope Specialist: detects task-spec conflicts and path-budget problems.
- UI Integration Specialist: reviews read-only UI/helper integration patterns.
- Runner Safety Specialist: reviews whether a repeated failure belongs in runner hardening.

## Failure Classes

### content_check_failed

Likely cause:

- Exact required tokens are too brittle.
- The output is behaviorally close but uses different wording.
- The output omitted a required class, function, or label.

Recommended next agent:

- Repair Agent for missing identifiers.
- Task Tuning Agent for brittle player-facing words.

Auto-repair safe:

- Sometimes, if the missing token is an exact identifier or required visible label.

Task tuning better:

- Yes, when the token expresses intent rather than a required literal.

Owner review required:

- Only if tuning would weaken acceptance criteria materially.

### blocked_content_found

Likely cause:

- The model introduced forbidden concepts, placeholder code, assets, scenes, or formulas.

Recommended next agent:

- Repair Agent for a small removable token.
- Reviewer Agent or Task Tuning Agent if blocked content reveals misunderstanding.

Auto-repair safe:

- Sometimes, for harmless accidental words in comments.

Task tuning better:

- Yes, if the prompt invited the blocked concept.

Owner review required:

- Yes, if blocked content touches high-risk systems or product boundaries.

### anchor_not_found

Likely cause:

- The task used stale or invented anchors.
- The model generated stub functions instead of real code context.
- The target file changed after the task was written.

Recommended next agent:

- Integration Context Agent.

Auto-repair safe:

- No, unless the real anchor is already provided and the error is a minor whitespace mismatch.

Task tuning better:

- Usually.

Owner review required:

- Yes for repeated failures in high-risk files.

### validation_parse_error

Likely cause:

- Syntax error, missing class reference, invalid GDScript type, or malformed resource.

Recommended next agent:

- Repair Agent.

Auto-repair safe:

- Often, for small helper files or same-run created files.

Task tuning better:

- Only if the task requested invalid syntax or unavailable APIs.

Owner review required:

- If the repair touches high-risk files or broadens scope.

### validation_runtime_error

Likely cause:

- Import-time script execution, missing resource, bad preload, invalid scene reference, or logic that runs during validation.

Recommended next agent:

- Validation Specialist or Reviewer Agent.

Auto-repair safe:

- Sometimes, when a missing reference is obvious and in scope.

Task tuning better:

- If the failure comes from a forbidden implementation path such as assets or scenes.

Owner review required:

- Usually, because runtime errors may hide product or architecture issues.

### large_replacement_rejected

Likely cause:

- The model tried to replace an existing large file instead of using targeted insertions.

Recommended next agent:

- Task Tuning Agent or Integration Context Agent.

Auto-repair safe:

- No.

Task tuning better:

- Yes. Provide exact `insert_after` or `insert_before` anchors.

Owner review required:

- Yes for high-risk files.

### model_api_error

Likely cause:

- Endpoint unavailable, model missing, context overflow, timeout, or malformed model response.

Recommended next agent:

- None by default. Runner should report and stop.

Auto-repair safe:

- No.

Task tuning better:

- Sometimes, if context overflow means the task needs splitting.

Owner review required:

- Yes if the task should be split or rerun with different model settings.

### task_spec_conflict

Likely cause:

- Required paths conflict with blocked paths.
- The task asks for implementation but forbids the necessary file.
- Acceptance tokens contradict blocked tokens.

Recommended next agent:

- Scope Specialist or Task Tuning Agent.

Auto-repair safe:

- No.

Task tuning better:

- Yes.

Owner review required:

- Yes if resolving the conflict changes product or risk scope.

### repeated_same_failure

Likely cause:

- The task is not suitable for the chosen model or context.
- The failure needs human/Codex integration.
- The acceptance rule is wrong.

Recommended next agent:

- Task Tuning Agent, Integration Context Agent, or Reviewer Agent depending on failure type.

Auto-repair safe:

- No after two similar failures.

Task tuning better:

- Usually.

Owner review required:

- Yes before another rerun.

### broad_integration_failure

Likely cause:

- The model cannot safely integrate across draw, input, state, and helper logic in a large script.

Recommended next agent:

- Integration Context Agent, then Codex/manual integration.

Auto-repair safe:

- No.

Task tuning better:

- Split helper/catalog creation from integration.

Owner review required:

- Yes before touching high-risk files.

## Failure Routing Matrix

| Failure class | Next agent | Auto-repair | Tune task | Owner review |
| --- | --- | --- | --- | --- |
| `content_check_failed` | Repair or Task Tuning | Sometimes | Often | Sometimes |
| `blocked_content_found` | Repair or Reviewer | Sometimes | Sometimes | Often |
| `anchor_not_found` | Integration Context | Rarely | Usually | Often |
| `validation_parse_error` | Repair | Often | Sometimes | Sometimes |
| `validation_runtime_error` | Validation Specialist | Sometimes | Sometimes | Usually |
| `large_replacement_rejected` | Task Tuning | No | Yes | Yes |
| `model_api_error` | Stop/report | No | Sometimes | Sometimes |
| `task_spec_conflict` | Scope Specialist | No | Yes | Yes |
| `repeated_same_failure` | Task Tuning or Reviewer | No | Usually | Yes |
| `broad_integration_failure` | Integration Context | No | Split task | Yes |

## Helper And Integration Split Pattern

Use this split when a task touches a large or high-risk integration file:

1. Helper-only task:
   - Creates or updates a small helper/catalog script.
   - No `main.gd` changes.
   - No draw/input code.
   - No scenes or assets.
   - Strong content checks.
2. Review:
   - Confirm helper is read-only and scoped.
   - Validate.
   - Commit helper.
3. Manual or Codex integration:
   - Use exact real anchors.
   - Preserve existing behavior.
   - Keep diff small.
   - Run validation and manual runtime checks.

This pattern should be preferred for `scripts/main.gd`, selected-building overlays, city sidebar integration, and any task that combines data catalog creation with draw/input handling.

## Guardrails

- No automatic commits from downstream agents.
- No infinite retry loops.
- One downstream specialist pass by default.
- Stop after repeated same failure unless the owner approves another run.
- No runner self-modification without owner approval.
- Downstream agents inherit original allowed and blocked paths.
- No new agent creation without owner approval.
- Always write reports.
- Keep failure reports factual and include exact file paths, rejection messages, validation output, and recommended next step.
- Do not weaken blocked paths or safety checks to make a run pass.

## Recommended First Implementation Phase

Phase 1 should add failure classification reporting only.

Goal:

- Classify failed runs into one or more failure classes.
- Include the classification in the run report.
- Recommend the next agent role without invoking it automatically.

Non-goals:

- No automatic specialist invocation.
- No new model calls after classification.
- No task rewriting.
- No runner self-repair.
- No automatic commits.

Suggested report fields:

- Failure classes.
- Primary failure class.
- Evidence lines.
- Recommended next agent.
- Auto-repair safety: yes/no.
- Task tuning recommended: yes/no.
- Owner review required: yes/no.

Definition of done:

- Existing runner behavior remains unchanged except for additional report text.
- Failed runs receive a deterministic classification from runner-observed errors.
- Validation and reports still work.
- Documentation includes examples for interpreting classifications.

## Example Routing

Production Requirement Helper v0:

- Failure: missing exact tokens `assigned labor` and `food shortage`.
- Class: `content_check_failed`.
- Recommended next agent: Task Tuning Agent.
- Auto-repair safe: not ideal, because wording was player-facing rather than an identifier.
- Better action: use `required_phrase_or_terms_by_path`.

Build Menu / Building Selector v0:

- Failure: nonexistent anchors in `scripts/main.gd`.
- Class: `anchor_not_found` and `broad_integration_failure`.
- Recommended next agent: Integration Context Agent.
- Auto-repair safe: no.
- Better action: split helper/catalog from manual integration.

Placeholder asset attempt:

- Failure: blocked content `placeholder.png` and `texture = preload`.
- Class: `blocked_content_found`.
- Recommended next agent: Reviewer Agent or Task Tuning Agent.
- Auto-repair safe: only if the blocked lines are isolated and removable.
- Better action: clarify draw-only/no-assets scope.
