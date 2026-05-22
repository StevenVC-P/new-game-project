# Agent Run Artifacts

This directory stores timestamped logs produced by `scripts/agent_runner.ps1`.

Each run directory may include prompts, raw model responses, accepted or rejected patches, validation output, and a final report. These files are intentionally inspectable so local-agent work can be reviewed after the fact.

For v0, successful runs may commit selected report artifacts alongside the approved patch. Failed runs preserve artifacts but do not commit failed code changes.
