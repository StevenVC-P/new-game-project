param(
	[string]$Task,
	[string]$Endpoint,
	[string]$Model,
	[string]$BaseBranch,
	[string]$BranchName,
	[int]$MaxAttempts,
	[int]$MaxFilesChanged,
	[int]$MaxLinesAdded,
	[int]$MaxLinesDeleted,
	[string]$ValidationCommand,
	[switch]$NoCommit,
	[switch]$KeepFailedChanges,
	[switch]$Resume
)

$ErrorActionPreference = "Stop"

function Stop-Run {
	param(
		[string]$Message,
		[int]$Code = 1
	)

	Write-Host "ERROR: $Message" -ForegroundColor Red
	exit $Code
}

function Write-TextFile {
	param(
		[string]$Path,
		[string]$Content
	)

	$Parent = Split-Path -Parent $Path
	if (-not [string]::IsNullOrWhiteSpace($Parent)) {
		New-Item -ItemType Directory -Force -Path $Parent | Out-Null
	}
	[System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Append-TextFile {
	param(
		[string]$Path,
		[string]$Content
	)

	$Parent = Split-Path -Parent $Path
	if (-not [string]::IsNullOrWhiteSpace($Parent)) {
		New-Item -ItemType Directory -Force -Path $Parent | Out-Null
	}
	[System.IO.File]::AppendAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-Git {
	param(
		[string[]]$Arguments,
		[switch]$AllowFailure
	)

	$Output = & git @Arguments 2>&1
	$ExitCode = $LASTEXITCODE
	$Text = ($Output | Out-String).TrimEnd()
	if ($ExitCode -ne 0 -and -not $AllowFailure) {
		throw "git $($Arguments -join ' ') failed with exit code $ExitCode.`n$Text"
	}

	return [pscustomobject]@{
		ExitCode = $ExitCode
		Output = $Text
	}
}

function Get-CurrentDiffBudget {
	param(
		[string[]]$IgnorePrefixes
	)

	$Numstat = (Invoke-Git @("diff", "--numstat") ).Output
	$Files = @{}
	$Added = 0
	$Deleted = 0
	if (-not [string]::IsNullOrWhiteSpace($Numstat)) {
		foreach ($Line in ($Numstat -split "\r?\n")) {
			$Parts = $Line -split "\t"
			if ($Parts.Count -lt 3) { continue }
			$Path = Normalize-RepoPath $Parts[2]
			$Ignored = $false
			foreach ($Prefix in $IgnorePrefixes) {
				if (Test-PathUnderPrefix $Path $Prefix) {
					$Ignored = $true
					break
				}
			}
			if ($Ignored) { continue }
			$Files[$Path] = $true
			$AddPart = $Parts[0]
			$DelPart = $Parts[1]
			if ($AddPart -match '^\d+$') { $Added += [int]$AddPart }
			if ($DelPart -match '^\d+$') { $Deleted += [int]$DelPart }
		}
	}
	return [pscustomobject]@{
		Files = @($Files.Keys)
		Added = $Added
		Deleted = $Deleted
	}
}

function Normalize-RepoPath {
	param([string]$Path)

	$Normalized = ($Path -replace '\\', '/').Trim()
	if ($Normalized.StartsWith("a/") -or $Normalized.StartsWith("b/")) {
		$Normalized = $Normalized.Substring(2)
	}
	return $Normalized
}

function Test-GlobMatch {
	param(
		[string]$Path,
		[string]$Glob
	)

	$Regex = "^" + [regex]::Escape(($Glob -replace '\\', '/')).Replace("\*", ".*").Replace("\?", ".") + "$"
	return $Path -match $Regex
}

function Test-PathUnderPrefix {
	param(
		[string]$Path,
		[string]$Prefix
	)

	$CleanPath = Normalize-RepoPath $Path
	$CleanPrefix = Normalize-RepoPath $Prefix
	if ($CleanPrefix.EndsWith("/")) {
		return $CleanPath.StartsWith($CleanPrefix, [System.StringComparison]::OrdinalIgnoreCase)
	}
	return $CleanPath.Equals($CleanPrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Convert-Scalar {
	param([string]$Value)

	$Trimmed = $Value.Trim()
	if (($Trimmed.StartsWith('"') -and $Trimmed.EndsWith('"')) -or ($Trimmed.StartsWith("'") -and $Trimmed.EndsWith("'"))) {
		$Trimmed = $Trimmed.Substring(1, $Trimmed.Length - 2)
	}
	if ($Trimmed -ieq "true") { return $true }
	if ($Trimmed -ieq "false") { return $false }
	$Number = 0
	if ([int]::TryParse($Trimmed, [ref]$Number)) { return $Number }
	return $Trimmed
}

function Read-TaskFile {
	param([string]$Path)

	$Content = [System.IO.File]::ReadAllText($Path)
	$Meta = @{}
	if ($Content -match '(?s)^---\r?\n(.*?)\r?\n---\r?\n?(.*)$') {
		$FrontMatter = $Matches[1]
		$Body = $Matches[2]
		$CurrentKey = $null
		foreach ($Line in ($FrontMatter -split "\r?\n")) {
			if ($Line -match '^\s*-\s*(.+?)\s*$' -and $CurrentKey) {
				if (-not $Meta.ContainsKey($CurrentKey)) {
					$Meta[$CurrentKey] = @()
				}
				$Meta[$CurrentKey] = @($Meta[$CurrentKey]) + @((Convert-Scalar $Matches[1]))
				continue
			}
			if ($Line -match '^([A-Za-z0-9_]+):\s*(.*)$') {
				$CurrentKey = $Matches[1]
				$Value = $Matches[2]
				if ([string]::IsNullOrWhiteSpace($Value)) {
					$Meta[$CurrentKey] = @()
				} else {
					$Meta[$CurrentKey] = Convert-Scalar $Value
				}
			}
		}
		return [pscustomobject]@{
			Metadata = $Meta
			Body = $Body
			Content = $Content
		}
	}

	return [pscustomobject]@{
		Metadata = $Meta
		Body = $Content
		Content = $Content
	}
}

function Get-MetaValue {
	param(
		[hashtable]$Metadata,
		[string]$Key,
		$Default
	)

	if ($Metadata.ContainsKey($Key) -and $null -ne $Metadata[$Key] -and "$($Metadata[$Key])" -ne "") {
		return $Metadata[$Key]
	}
	return $Default
}

function Get-StatusPaths {
	$Status = (Invoke-Git @("status", "--porcelain=v1") ).Output
	if ([string]::IsNullOrWhiteSpace($Status)) {
		return @()
	}
	$Paths = @()
	foreach ($Line in ($Status -split "\r?\n")) {
		if ($Line.Length -lt 4) { continue }
		$PathPart = $Line.Substring(3).Trim()
		if ($PathPart -match ' -> ') {
			$Pieces = $PathPart -split ' -> '
			$PathPart = $Pieces[-1]
		}
		$Paths += Normalize-RepoPath $PathPart.Trim('"')
	}
	return $Paths | Sort-Object -Unique
}

function Test-OnlyAllowedDirtyPaths {
	param(
		[string[]]$AllowedPrefixes
	)

	$DirtyPaths = @(Get-StatusPaths)
	if ($DirtyPaths.Count -eq 0) { return $true }
	foreach ($Path in $DirtyPaths) {
		$Allowed = $false
		foreach ($Prefix in $AllowedPrefixes) {
			if (Test-PathUnderPrefix $Path $Prefix) {
				$Allowed = $true
				break
			}
		}
		if (-not $Allowed) { return $false }
	}
	return $true
}

function Invoke-LocalChat {
	param(
		[string]$Endpoint,
		[string]$Model,
		[string]$SystemPrompt,
		[string]$UserPrompt,
		[int]$MaxTokens = 4096
	)

	$ChatUri = "$($Endpoint.TrimEnd('/'))/chat/completions"
	$Body = @{
		model = $Model
		temperature = 0
		top_p = 1
		stream = $false
		max_tokens = $MaxTokens
		messages = @(
			@{ role = "system"; content = $SystemPrompt },
			@{ role = "user"; content = $UserPrompt }
		)
	} | ConvertTo-Json -Depth 10

	$Response = Invoke-RestMethod -Method Post -Uri $ChatUri -Body $Body -ContentType "application/json" -TimeoutSec 600
	if (-not $Response.choices -or -not $Response.choices[0].message.content) {
		throw "Model response did not include choices[0].message.content."
	}
	return [string]$Response.choices[0].message.content
}

function Test-ModelAvailable {
	param(
		[string]$Endpoint,
		[string]$Model
	)

	$ModelsUri = "$($Endpoint.TrimEnd('/'))/models"
	try {
		$Response = Invoke-RestMethod -Method Get -Uri $ModelsUri -TimeoutSec 10
	} catch {
		Stop-Run "Could not reach LM Studio/OpenAI-compatible endpoint at $ModelsUri. $($_.Exception.Message)"
	}
	$Ids = @()
	if ($Response.data) {
		$Ids = @($Response.data | ForEach-Object { $_.id })
	}
	return @($Ids) -contains $Model
}

function Get-PatchInfo {
	param(
		[string]$PatchText,
		[string[]]$AllowedPaths,
		[string[]]$BlockedPaths,
		[string[]]$GlobalBlockedPaths,
		[string[]]$BlockedGlobs,
		[bool]$AllowNewFiles,
		[bool]$AllowDeletes,
		[bool]$AllowRenames,
		[int]$MaxFilesChanged,
		[int]$MaxLinesAdded,
		[int]$MaxLinesDeleted
	)

	$Errors = @()
	$Trimmed = $PatchText.Trim()
	if ([string]::IsNullOrWhiteSpace($Trimmed)) {
		$Errors += "Patch is empty."
	}
	if ($Trimmed -match '```') {
		$Errors += "Patch contains Markdown code fences."
	}
	if ($Trimmed -notmatch '(?m)^diff --git a/.+ b/.+') {
		$Errors += "Patch does not contain unified git diff headers."
	}
	$FirstNonEmpty = (($Trimmed -split "\r?\n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
	if ($FirstNonEmpty -notmatch '^diff --git a/.+ b/.+') {
		$Errors += "Patch contains text before the first diff header."
	}

	$Files = [ordered]@{}
	$Added = 0
	$Deleted = 0
	$CurrentFiles = @()
	$CurrentHeader = $null
	$SawBinary = $false
	$SawDelete = $false
	$SawNew = $false
	$SawRename = $false

	foreach ($Line in ($Trimmed -split "\r?\n")) {
		if ($Line -match '^diff --git a/(.+?) b/(.+)$') {
			$Left = Normalize-RepoPath $Matches[1]
			$Right = Normalize-RepoPath $Matches[2]
			$CurrentHeader = @($Left, $Right)
			$CurrentFiles = @($Left, $Right) | Where-Object { $_ -ne "/dev/null" } | Sort-Object -Unique
			foreach ($File in $CurrentFiles) {
				$Files[$File] = $true
			}
			continue
		}
		if ($Line -match '^(Binary files|GIT binary patch)') {
			$SawBinary = $true
		}
		if ($Line -match '^new file mode ') {
			$SawNew = $true
		}
		if ($Line -match '^deleted file mode ') {
			$SawDelete = $true
		}
		if ($Line -match '^rename (from|to) ') {
			$SawRename = $true
		}
		if ($Line.StartsWith("+") -and -not $Line.StartsWith("+++")) {
			$Added += 1
		}
		if ($Line.StartsWith("-") -and -not $Line.StartsWith("---")) {
			$Deleted += 1
		}
	}

	if ($SawBinary) { $Errors += "Binary patches are not allowed." }
	if ($SawNew -and -not $AllowNewFiles) { $Errors += "Patch creates a file, but allow_new_files is false." }
	if ($SawDelete -and -not $AllowDeletes) { $Errors += "Patch deletes a file, but allow_deletes is false." }
	if ($SawRename -and -not $AllowRenames) { $Errors += "Patch renames a file, but allow_renames is false." }
	if ($Files.Keys.Count -gt $MaxFilesChanged) { $Errors += "Patch changes $($Files.Keys.Count) files; limit is $MaxFilesChanged." }
	if ($Added -gt $MaxLinesAdded) { $Errors += "Patch adds $Added lines; limit is $MaxLinesAdded." }
	if ($Deleted -gt $MaxLinesDeleted) { $Errors += "Patch deletes $Deleted lines; limit is $MaxLinesDeleted." }

	foreach ($File in $Files.Keys) {
		if ([System.IO.Path]::IsPathRooted($File)) {
			$Errors += "Patch uses absolute path: $File"
		}
		if ($File -match '(^|/)\.\.(/|$)') {
			$Errors += "Patch uses path traversal: $File"
		}
		foreach ($Blocked in @($GlobalBlockedPaths + $BlockedPaths)) {
			if (-not [string]::IsNullOrWhiteSpace($Blocked) -and (Test-PathUnderPrefix $File $Blocked)) {
				$Errors += "Patch touches blocked path: $File"
			}
		}
		foreach ($Glob in $BlockedGlobs) {
			if (Test-GlobMatch $File $Glob) {
				$Errors += "Patch touches blocked glob ${Glob}: $File"
			}
		}
		if ($AllowedPaths.Count -gt 0) {
			$Allowed = $false
			foreach ($AllowedPath in $AllowedPaths) {
				if (Test-PathUnderPrefix $File $AllowedPath) {
					$Allowed = $true
					break
				}
			}
			if (-not $Allowed) {
				$Errors += "Patch touches path outside allowed_paths: $File"
			}
		}
	}

	return [pscustomobject]@{
		Errors = @($Errors | Sort-Object -Unique)
		Files = @($Files.Keys)
		Added = $Added
		Deleted = $Deleted
		CreatesFile = $SawNew
		DeletesFile = $SawDelete
		RenamesFile = $SawRename
	}
}

function Invoke-ValidationCommand {
	param(
		[string]$Command,
		[string]$LogPath
	)

	$Output = @()
	$ExitCode = 0
	try {
		$Output = & ([scriptblock]::Create($Command)) 2>&1
		$ExitCode = $LASTEXITCODE
		if ($null -eq $ExitCode) { $ExitCode = 0 }
	} catch {
		$Output += $_.Exception.Message
		$ExitCode = 1
	}
	$Text = ($Output | Out-String)
	Write-TextFile $LogPath $Text
	return [pscustomobject]@{
		ExitCode = $ExitCode
		Output = $Text
	}
}

function Restore-RunnerChanges {
	param(
		[string[]]$Paths
	)

	foreach ($Path in ($Paths | Sort-Object -Unique)) {
		$ExistsInHead = (Invoke-Git @("cat-file", "-e", "HEAD:$Path") -AllowFailure).ExitCode -eq 0
		if ($ExistsInHead) {
			Invoke-Git @("restore", "--", $Path) | Out-Null
		} elseif (Test-Path -LiteralPath $Path) {
			Remove-Item -LiteralPath $Path -Force
		}
	}
}

function New-Report {
	param(
		[string]$Path,
		[string]$TaskTitle,
		[string]$RunId,
		[string]$Started,
		[string]$Finished,
		[string]$BaseBranch,
		[string]$BranchName,
		[string]$Model,
		[string]$Endpoint,
		[int]$MaxAttempts,
		[string]$FinalStatus,
		[string]$StopReason,
		[string]$CommitHash,
		[string[]]$RequestedScope,
		[string[]]$FilesChanged,
		[string]$DiffSummary,
		[string]$ValidationCommand,
		[int]$ValidationExitCode,
		[string]$ValidationSummary,
		[string[]]$AttemptLines,
		[string[]]$SafetyLines,
		[string[]]$ArtifactLines,
		[string[]]$ResidualRisks
	)

	$Report = @"
# Local Agent Run Report

- Task: $TaskTitle
- Run ID: $RunId
- Started: $Started
- Finished: $Finished
- Base branch: $BaseBranch
- Feature branch: $BranchName
- Model: $Model
- Endpoint: $Endpoint
- Max attempts: $MaxAttempts
- Final status: $FinalStatus
- Stop reason: $StopReason
- Commit: $CommitHash

## Requested Scope

$($RequestedScope -join "`n")

## Files Changed

$($FilesChanged -join "`n")

## Diff Summary

````text
$DiffSummary
````

## Validation

- Command: $ValidationCommand
- Exit code: $ValidationExitCode
- Summary: $ValidationSummary

## Attempts

$($AttemptLines -join "`n")

## Safety Checks

$($SafetyLines -join "`n")

## Runner Artifacts

$($ArtifactLines -join "`n")

## Residual Risks

$($ResidualRisks -join "`n")
"@
	Write-TextFile $Path $Report
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path
Set-Location $RepoRoot

$ConfigPath = Join-Path $ScriptDir "agent_runner.config.json"
if (-not (Test-Path -LiteralPath $ConfigPath)) {
	Stop-Run "Config file not found: $ConfigPath"
}
$Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($Task)) { Stop-Run "Pass -Task <path-to-task.md>." }
if ([string]::IsNullOrWhiteSpace($Endpoint)) { $Endpoint = $Config.endpoint }
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = $Config.model }
if (-not $PSBoundParameters.ContainsKey("MaxAttempts")) { $MaxAttempts = [int]$Config.maxAttempts }
if (-not $PSBoundParameters.ContainsKey("MaxFilesChanged")) { $MaxFilesChanged = [int]$Config.maxFilesChanged }
if (-not $PSBoundParameters.ContainsKey("MaxLinesAdded")) { $MaxLinesAdded = [int]$Config.maxLinesAdded }
if (-not $PSBoundParameters.ContainsKey("MaxLinesDeleted")) { $MaxLinesDeleted = [int]$Config.maxLinesDeleted }

$GitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $GitCommand) { Stop-Run "Git was not found on PATH." }
if (-not (Get-Command powershell -ErrorAction SilentlyContinue)) { Stop-Run "Windows PowerShell was not found on PATH." }

$GitRoot = (Invoke-Git @("rev-parse", "--show-toplevel")).Output
if ([string]::IsNullOrWhiteSpace($GitRoot)) { Stop-Run "Not inside a Git repository." }
$GitRoot = (Resolve-Path -LiteralPath $GitRoot).Path
if ($GitRoot -ne $RepoRoot) { Set-Location $GitRoot; $RepoRoot = $GitRoot }

$TaskPath = $Task
if (-not [System.IO.Path]::IsPathRooted($TaskPath)) {
	$TaskPath = Join-Path $RepoRoot $TaskPath
}
if (-not (Test-Path -LiteralPath $TaskPath)) {
	Stop-Run "Task file not found: $Task"
}

$TaskData = Read-TaskFile $TaskPath
$Meta = $TaskData.Metadata

$BaseBranch = Get-MetaValue $Meta "base_branch" $(if ($BaseBranch) { $BaseBranch } else { $Config.baseBranch })
$BranchName = Get-MetaValue $Meta "branch_name" $BranchName
if ([string]::IsNullOrWhiteSpace($BranchName)) { Stop-Run "BranchName was not provided and task front matter has no branch_name." }
if ($BaseBranch -eq "main") { Stop-Run "Refusing to use main as the implementation base branch." }
if ($BranchName -eq "main") { Stop-Run "Refusing to use main as the implementation branch." }
$ValidationCommand = Get-MetaValue $Meta "validation_command" $(if ($ValidationCommand) { $ValidationCommand } else { $Config.validationCommand })
$MaxFilesChanged = [int](Get-MetaValue $Meta "max_files_changed" $MaxFilesChanged)
$MaxLinesAdded = [int](Get-MetaValue $Meta "max_lines_added" $MaxLinesAdded)
$MaxLinesDeleted = [int](Get-MetaValue $Meta "max_lines_deleted" $MaxLinesDeleted)
$AllowNewFiles = [bool](Get-MetaValue $Meta "allow_new_files" $false)
$AllowDeletes = [bool](Get-MetaValue $Meta "allow_deletes" $false)
$AllowRenames = [bool](Get-MetaValue $Meta "allow_renames" $false)
$CommitMessage = Get-MetaValue $Meta "commit_message" "chore: apply local agent patch"
$TaskTitle = Get-MetaValue $Meta "title" (Split-Path -Leaf $TaskPath)
$AllowedPaths = @(Get-MetaValue $Meta "allowed_paths" @())
$TaskBlockedPaths = @(Get-MetaValue $Meta "blocked_paths" @())
$GlobalBlockedPaths = @($Config.globalBlockedPaths)
$BlockedGlobs = @($Config.defaultBlockedGlobs)
$ArtifactRoot = $Config.artifactRoot

if (-not (Test-ModelAvailable $Endpoint $Model)) {
	Stop-Run "Endpoint responded, but model '$Model' was not listed at $($Endpoint.TrimEnd('/'))/models."
}

$InitialDirty = @(Get-StatusPaths)
if ($InitialDirty.Count -gt 0) {
	if (-not $Resume) {
		Stop-Run "Working tree is dirty. Commit, stash, or clean changes before running."
	}
	if (-not (Test-OnlyAllowedDirtyPaths @($ArtifactRoot))) {
		Stop-Run "Working tree is dirty outside runner-owned artifacts; refusing resume."
	}
}

$BranchExists = (Invoke-Git @("rev-parse", "--verify", $BranchName) -AllowFailure).ExitCode -eq 0
if ($BranchExists -and -not $Resume) {
	Stop-Run "Branch '$BranchName' already exists. Pass -Resume to continue on it."
}

if ($BranchExists) {
	Invoke-Git @("switch", $BranchName) | Out-Null
} else {
	Invoke-Git @("switch", $BaseBranch) | Out-Null
	Invoke-Git @("switch", "-c", $BranchName) | Out-Null
}

$RunId = Get-Date -Format "yyyyMMdd-HHmmss"
$RunDirRel = (Join-Path $ArtifactRoot $RunId) -replace '\\', '/'
$RunDir = Join-Path $RepoRoot $RunDirRel
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$Started = (Get-Date).ToString("o")
$PlanPath = Join-Path $RunDir "plan.md"
$PromptPlanPath = Join-Path $RunDir "prompt-plan.txt"
$RawPlanPath = Join-Path $RunDir "raw-plan.txt"
$PromptPatchPath = Join-Path $RunDir "prompt-patch.txt"
$ValidationLogPath = Join-Path $RunDir "validation.log"
$ReportPath = Join-Path $RunDir "report.md"
$TaskArtifactPath = Join-Path $RunDir "task.md"

Copy-Item -LiteralPath $TaskPath -Destination $TaskArtifactPath -Force

$AgentsPath = Join-Path $RepoRoot "AGENTS.md"
$AgentsText = if (Test-Path -LiteralPath $AgentsPath) { [System.IO.File]::ReadAllText($AgentsPath) } else { "" }

$ConstraintText = @"
Runner constraints:
- Endpoint: $Endpoint
- Model: $Model
- Base branch: $BaseBranch
- Feature branch: $BranchName
- Max attempts: $MaxAttempts
- Max files changed: $MaxFilesChanged
- Max lines added: $MaxLinesAdded
- Max lines deleted: $MaxLinesDeleted
- Allowed paths: $($AllowedPaths -join ', ')
- Blocked paths: $(@($GlobalBlockedPaths + $TaskBlockedPaths) -join ', ')
- Blocked globs: $($BlockedGlobs -join ', ')
- Allow new files: $AllowNewFiles
- Allow deletes: $AllowDeletes
- Allow renames: $AllowRenames
- Validation command: $ValidationCommand
"@

$PlanPrompt = @"
You are planning a bounded repository change for a local patch runner.

Read the repository instructions, runner constraints, and task. Return a concise Markdown plan. Do not include a patch.

AGENTS.md:
$AgentsText

$ConstraintText

Task file:
$($TaskData.Content)
"@

Write-TextFile $PromptPlanPath $PlanPrompt
$Plan = Invoke-LocalChat -Endpoint $Endpoint -Model $Model -SystemPrompt "You are a careful local coding planner. You do not claim to run tools." -UserPrompt $PlanPrompt -MaxTokens 2048
Write-TextFile $RawPlanPath $Plan
Write-TextFile $PlanPath $Plan

$PatchSystemPrompt = "You produce unified git diffs only. No Markdown, no code fences, no explanations, no prose."
$PatchPromptBase = @"
Create the implementation patch for the task below.

Return ONLY a unified diff.
No Markdown.
No code fences.
No explanations.
No tool-call text.
No prose before or after the diff.

$ConstraintText

Plan:
$Plan

Task file:
$($TaskData.Content)
"@

Write-TextFile $PromptPatchPath $PatchPromptBase

$AttemptLines = @()
$SafetyLines = @(
	"- Parsed task front matter.",
	"- Confirmed Git repository and repo root.",
	"- Confirmed LM Studio/OpenAI-compatible endpoint and configured model.",
	"- Enforced branch ownership.",
	"- Enforced blocked paths, allowed paths, file budget, and line budgets.",
	"- Used git apply --check --whitespace=error before applying patches.",
	"- Used explicit staging only; never git add .."
)
$ApprovedPatchFiles = @()
$FinalStatus = "failed"
$StopReason = "attempts exhausted"
$CommitHash = ""
$ValidationExitCode = -1
$ValidationSummary = "Validation did not run."
$LastPatchInfo = $null
$AppliedAnyPatch = $false

for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
	$RawPatchPath = Join-Path $RunDir ("raw-patch-attempt-{0}.txt" -f $Attempt)
	$PatchPath = Join-Path $RunDir ("patch-attempt-{0}.diff" -f $Attempt)

	if ($Attempt -eq 1) {
		$PatchPrompt = $PatchPromptBase
	} else {
		$CurrentDiff = (Invoke-Git @("diff", "--") ).Output
		$ValidationText = if (Test-Path -LiteralPath $ValidationLogPath) { [System.IO.File]::ReadAllText($ValidationLogPath) } else { "" }
		$PatchPrompt = @"
Repair the current failed patch.

Return ONLY a unified diff.
No Markdown.
No code fences.
No explanations.
No tool-call text.
No prose before or after the diff.

$ConstraintText

Original task:
$($TaskData.Content)

Original plan:
$Plan

Current diff:
$CurrentDiff

Validation log:
$ValidationText
"@
	}

	$RawPatch = Invoke-LocalChat -Endpoint $Endpoint -Model $Model -SystemPrompt $PatchSystemPrompt -UserPrompt $PatchPrompt -MaxTokens 4096
	Write-TextFile $RawPatchPath $RawPatch
	$PatchText = $RawPatch.Trim()
	Write-TextFile $PatchPath $PatchText

	$PatchInfo = Get-PatchInfo -PatchText $PatchText -AllowedPaths $AllowedPaths -BlockedPaths $TaskBlockedPaths -GlobalBlockedPaths $GlobalBlockedPaths -BlockedGlobs $BlockedGlobs -AllowNewFiles $AllowNewFiles -AllowDeletes $AllowDeletes -AllowRenames $AllowRenames -MaxFilesChanged $MaxFilesChanged -MaxLinesAdded $MaxLinesAdded -MaxLinesDeleted $MaxLinesDeleted
	$LastPatchInfo = $PatchInfo

	if ($PatchInfo.Errors.Count -gt 0) {
		$AttemptLines += "- Attempt ${Attempt}: rejected before apply: $($PatchInfo.Errors -join '; ')"
		continue
	}

	$Check = Invoke-Git @("apply", "--check", "--whitespace=error", $PatchPath) -AllowFailure
	if ($Check.ExitCode -ne 0) {
		$AttemptLines += "- Attempt ${Attempt}: git apply --check failed: $($Check.Output)"
		continue
	}

	Invoke-Git @("apply", "--whitespace=error", $PatchPath) | Out-Null
	$AppliedAnyPatch = $true
	$ApprovedPatchFiles = @($ApprovedPatchFiles + $PatchInfo.Files) | Sort-Object -Unique
	$AttemptLines += "- Attempt ${Attempt}: patch applied to $($PatchInfo.Files.Count) file(s)."

	$Budget = Get-CurrentDiffBudget -IgnorePrefixes @($ArtifactRoot)
	if ($Budget.Files.Count -gt $MaxFilesChanged -or $Budget.Added -gt $MaxLinesAdded -or $Budget.Deleted -gt $MaxLinesDeleted) {
		$AttemptLines += "- Attempt ${Attempt}: cumulative diff budget exceeded ($($Budget.Files.Count) files, +$($Budget.Added), -$($Budget.Deleted))."
		$ValidationExitCode = 1
		$ValidationSummary = "Cumulative diff budget exceeded."
		continue
	}

	$DiffCheck = Invoke-Git @("diff", "--check") -AllowFailure
	if ($DiffCheck.ExitCode -ne 0) {
		$AttemptLines += "- Attempt ${Attempt}: git diff --check failed: $($DiffCheck.Output)"
		$ValidationExitCode = $DiffCheck.ExitCode
		$ValidationSummary = "git diff --check failed."
		continue
	}

	$Validation = Invoke-ValidationCommand -Command $ValidationCommand -LogPath $ValidationLogPath
	$ValidationExitCode = $Validation.ExitCode
	$ValidationSummary = if ($Validation.ExitCode -eq 0) { "Validation passed." } else { "Validation failed. See validation.log." }
	$AttemptLines += "- Attempt ${Attempt}: validation exit code $ValidationExitCode."

	if ($Validation.ExitCode -eq 0) {
		$FinalStatus = "passed"
		$StopReason = if ($NoCommit) { "validation passed; NoCommit set" } else { "validation passed and committed" }
		break
	}
}

$Finished = (Get-Date).ToString("o")
$DiffSummary = (Invoke-Git @("diff", "--stat") ).Output
$FilesChanged = @(Get-StatusPaths)
$ArtifactRelPaths = @(
	"$RunDirRel/task.md",
	"$RunDirRel/plan.md",
	"$RunDirRel/prompt-plan.txt",
	"$RunDirRel/raw-plan.txt",
	"$RunDirRel/prompt-patch.txt",
	"$RunDirRel/validation.log",
	"$RunDirRel/report.md"
)
for ($I = 1; $I -le $MaxAttempts; $I++) {
	$ArtifactRelPaths += "$RunDirRel/raw-patch-attempt-$I.txt"
	$ArtifactRelPaths += "$RunDirRel/patch-attempt-$I.diff"
}
$ArtifactRelPaths = @($ArtifactRelPaths | Where-Object { Test-Path -LiteralPath (Join-Path $RepoRoot $_) })

$RequestedScope = @(
	"- Allowed paths: $($AllowedPaths -join ', ')",
	"- Task blocked paths: $($TaskBlockedPaths -join ', ')",
	"- Global blocked paths: $($GlobalBlockedPaths -join ', ')",
	"- New files allowed: $AllowNewFiles",
	"- Deletes allowed: $AllowDeletes",
	"- Renames allowed: $AllowRenames"
)
$ArtifactLines = @($ArtifactRelPaths | ForEach-Object { "- $_" })
$ResidualRisks = @(
	"- Validation is an import pass and does not prove every gameplay path.",
	"- v0 rejects noisy model output instead of attempting patch extraction.",
	"- A report committed in the same commit cannot contain its own final commit hash; the runner prints the final hash after commit.",
	"- Task success is bounded by the model context supplied to the prompt."
)

if ($FinalStatus -ne "passed" -and $AppliedAnyPatch -and -not $KeepFailedChanges) {
	Restore-RunnerChanges $ApprovedPatchFiles
	$FilesChanged = @(Get-StatusPaths)
	$StopReason = "attempts exhausted; runner-applied files rolled back"
}

$ReportCommitHash = $CommitHash
if ($FinalStatus -eq "passed" -and -not $NoCommit) {
	$ReportCommitHash = "(pending; final hash printed by runner)"
}

New-Report -Path $ReportPath -TaskTitle $TaskTitle -RunId $RunId -Started $Started -Finished $Finished -BaseBranch $BaseBranch -BranchName $BranchName -Model $Model -Endpoint $Endpoint -MaxAttempts $MaxAttempts -FinalStatus $FinalStatus -StopReason $StopReason -CommitHash $ReportCommitHash -RequestedScope $RequestedScope -FilesChanged (@($ApprovedPatchFiles | ForEach-Object { "- $_" })) -DiffSummary $DiffSummary -ValidationCommand $ValidationCommand -ValidationExitCode $ValidationExitCode -ValidationSummary $ValidationSummary -AttemptLines $AttemptLines -SafetyLines $SafetyLines -ArtifactLines $ArtifactLines -ResidualRisks $ResidualRisks

if ($FinalStatus -eq "passed" -and -not $NoCommit) {
	$AllowedStatusPaths = @($ApprovedPatchFiles + $ArtifactRelPaths) | Sort-Object -Unique
	$CurrentStatusPaths = @(Get-StatusPaths)
	foreach ($Path in $CurrentStatusPaths) {
		if (@($AllowedStatusPaths) -notcontains $Path) {
			Stop-Run "Refusing to commit unexpected path: $Path"
		}
	}

	foreach ($Path in $AllowedStatusPaths) {
		if (Test-Path -LiteralPath (Join-Path $RepoRoot $Path)) {
			Invoke-Git @("add", "--", $Path) | Out-Null
		}
	}
	Invoke-Git @("commit", "-m", $CommitMessage) | Out-Null
	$CommitHash = (Invoke-Git @("rev-parse", "--short", "HEAD")).Output
}

Write-Host "Run ID: $RunId"
Write-Host "Status: $FinalStatus"
Write-Host "Stop reason: $StopReason"
if ($CommitHash) { Write-Host "Commit: $CommitHash" }
Write-Host "Report: $RunDirRel/report.md"

if ($FinalStatus -ne "passed") {
	exit 1
}
