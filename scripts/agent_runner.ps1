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
$RunStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$ProgressLogPath = $null
$ProgressLogBuffer = @()

function Write-RunnerLog {
	param([string]$Message)

	$Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
	$Elapsed = "{0:hh\:mm\:ss}" -f $RunStopwatch.Elapsed
	$Line = "[$Timestamp +$Elapsed] $Message"
	Write-Host $Line
	if ($script:ProgressLogPath) {
		Append-TextFile $script:ProgressLogPath ($Line + [Environment]::NewLine)
	} else {
		$script:ProgressLogBuffer += $Line
	}
}

function Initialize-RunnerLogFile {
	param([string]$Path)

	$script:ProgressLogPath = $Path
	Write-TextFile $script:ProgressLogPath ""
	foreach ($Line in $script:ProgressLogBuffer) {
		Append-TextFile $script:ProgressLogPath ($Line + [Environment]::NewLine)
	}
	$script:ProgressLogBuffer = @()
}

function Format-Duration {
	param([TimeSpan]$Duration)

	return "{0:hh\:mm\:ss\.fff}" -f $Duration
}

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

	$PreviousErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$Output = & git @Arguments 2>&1
		$ExitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $PreviousErrorActionPreference
	}
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

function Get-TextLineCount {
	param([string]$Text)

	if ([string]::IsNullOrEmpty($Text)) {
		return 0
	}
	return @($Text -split "\r?\n").Count
}

function Test-CurrentDiffSafety {
	param(
		[string[]]$IgnorePrefixes,
		[int]$MaxFilesChanged,
		[int]$MaxLinesAdded,
		[int]$MaxLinesDeleted,
		[double]$MaxDeletedLinesRatio,
		[string[]]$PreserveContent
	)

	$Budget = Get-CurrentDiffBudget -IgnorePrefixes $IgnorePrefixes
	$Errors = @()
	if ($Budget.Files.Count -gt $MaxFilesChanged) {
		$Errors += "Cumulative diff changes $($Budget.Files.Count) files; limit is $MaxFilesChanged."
	}
	if ($Budget.Added -gt $MaxLinesAdded) {
		$Errors += "Cumulative diff adds $($Budget.Added) lines; limit is $MaxLinesAdded."
	}
	if ($Budget.Deleted -gt $MaxLinesDeleted) {
		$Errors += "Cumulative diff deletes $($Budget.Deleted) lines; limit is $MaxLinesDeleted."
	}

	$Numstat = (Invoke-Git @("diff", "--numstat") ).Output
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
			if ($Parts[1] -notmatch '^\d+$') { continue }
			$Deleted = [int]$Parts[1]
			$Original = (Invoke-Git @("show", "HEAD:$Path") -AllowFailure)
			if ($Original.ExitCode -ne 0) { continue }
			$OriginalLineCount = Get-TextLineCount $Original.Output
			if ($OriginalLineCount -gt 0) {
				$DeletedRatio = [double]$Deleted / [double]$OriginalLineCount
				if ($DeletedRatio -gt $MaxDeletedLinesRatio) {
					$Errors += "Cumulative diff deletes $Deleted of $OriginalLineCount line(s) in ${Path}; ratio $([math]::Round($DeletedRatio, 3)) exceeds limit $MaxDeletedLinesRatio."
				}
			}
			if ($PreserveContent.Count -gt 0 -and (Test-Path -LiteralPath (Join-Path $RepoRoot $Path))) {
				$OriginalText = $Original.Output
				$CurrentText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot $Path))
				foreach ($Token in $PreserveContent) {
					if ([string]::IsNullOrEmpty($Token)) { continue }
					if ($OriginalText.Contains($Token) -and -not $CurrentText.Contains($Token)) {
						$Errors += "Preserve check failed for ${Path}: original contained '$Token' but changed file does not."
					}
				}
			}
		}
	}

	return [pscustomobject]@{
		Budget = $Budget
		Errors = @($Errors | Sort-Object -Unique)
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

function Test-KnownHarmlessGodotLogLine {
	param(
		[string]$Line
	)

	$Trimmed = $Line.Trim()
	if ($Trimmed -match "^ERROR: Cannot navigate to 'res://main\.tscn' as it has not been found in the file system!$") {
		return $true
	}
	if ($Trimmed -match "^ERROR: Cannot save file '.+[\\/]Godot[\\/]editor_settings-4\.6\.tres'\.$") {
		return $true
	}
	if ($Trimmed -match "^ERROR: Error saving editor settings to .+[\\/]Godot[\\/]editor_settings-4\.6\.tres$") {
		return $true
	}
	return $false
}

function Get-SeriousGodotLogLines {
	param(
		[string]$Text
	)

	$Serious = @()
	foreach ($Line in ($Text -split "\r?\n")) {
		if ([string]::IsNullOrWhiteSpace($Line)) { continue }
		if (Test-KnownHarmlessGodotLogLine $Line) { continue }

		$Trimmed = $Line.Trim()
		if (
			$Trimmed.Contains("Parse Error") -or
			$Trimmed.Contains("SCRIPT ERROR:") -or
			$Trimmed.Contains("Failed loading resource") -or
			$Trimmed.Contains("Cannot load") -or
			$Trimmed.Contains("Invalid get index") -or
			$Trimmed.Contains("Invalid call") -or
			$Trimmed.StartsWith("ERROR:") -or
			$Trimmed.Contains("res://")
		) {
			$Serious += $Line
		}
	}
	return @($Serious)
}

function Convert-Scalar {
	param([string]$Value)

	$Trimmed = $Value.Trim()
	if ($Trimmed.Length -ge 2 -and (($Trimmed.StartsWith('"') -and $Trimmed.EndsWith('"')) -or ($Trimmed.StartsWith("'") -and $Trimmed.EndsWith("'")))) {
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
		$CurrentMapKey = $null
		foreach ($Line in ($FrontMatter -split "\r?\n")) {
			if ($Line -match '^\s*-\s*(.+?)\s*$' -and $CurrentKey) {
				if ($CurrentMapKey) {
					if (-not ($Meta[$CurrentKey] -is [hashtable])) {
						$Meta[$CurrentKey] = @{}
					}
					if (-not $Meta[$CurrentKey].ContainsKey($CurrentMapKey)) {
						$Meta[$CurrentKey][$CurrentMapKey] = @()
					}
					$Meta[$CurrentKey][$CurrentMapKey] = @($Meta[$CurrentKey][$CurrentMapKey]) + @((Convert-Scalar $Matches[1]))
				} else {
					if (-not $Meta.ContainsKey($CurrentKey)) {
						$Meta[$CurrentKey] = @()
					}
					$Meta[$CurrentKey] = @($Meta[$CurrentKey]) + @((Convert-Scalar $Matches[1]))
				}
				continue
			}
			if ($Line -match '^\s+([^:\s][^:]*?):\s*(.*?)\s*$' -and $CurrentKey) {
				if (-not ($Meta[$CurrentKey] -is [hashtable])) {
					$Meta[$CurrentKey] = @{}
				}
				$NestedKey = Convert-Scalar $Matches[1]
				$NestedValue = $Matches[2]
				if ([string]::IsNullOrWhiteSpace($NestedValue)) {
					$Meta[$CurrentKey][$NestedKey] = @()
					$CurrentMapKey = $NestedKey
				} else {
					$Meta[$CurrentKey][$NestedKey] = Convert-Scalar $NestedValue
					$CurrentMapKey = $null
				}
				continue
			}
			if ($Line -match '^([A-Za-z0-9_]+):\s*(.*)$') {
				$CurrentKey = $Matches[1]
				$CurrentMapKey = $null
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

function Get-MetaMap {
	param(
		[hashtable]$Metadata,
		[string]$Key
	)

	if ($Metadata.ContainsKey($Key) -and $Metadata[$Key] -is [hashtable]) {
		return $Metadata[$Key]
	}
	return @{}
}

function Get-MetaListMap {
	param(
		[hashtable]$Metadata,
		[string]$Key
	)

	$Result = @{}
	if (-not ($Metadata.ContainsKey($Key) -and $Metadata[$Key] -is [hashtable])) {
		return $Result
	}
	foreach ($MapKey in $Metadata[$Key].Keys) {
		$RepoPath = Normalize-RepoPath ([string]$MapKey)
		$Result[$RepoPath] = @($Metadata[$Key][$MapKey])
	}
	return $Result
}

function Format-ListMapSummary {
	param([hashtable]$Map)

	if ($Map.Keys.Count -eq 0) {
		return ""
	}
	return ((@($Map.Keys) | Sort-Object | ForEach-Object { "$_=$(@($Map[$_]).Count)" }) -join ', ')
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

function Convert-ModelOutputToPatch {
	param([string]$RawOutput)

	$Errors = @()
	$Trimmed = $RawOutput.Trim()
	$Sanitized = $false
	$PatchText = $Trimmed

	$FenceMatches = [regex]::Matches($RawOutput, '```')
	if ($FenceMatches.Count -eq 0) {
		return [pscustomobject]@{
			PatchText = $PatchText
			Sanitized = $false
			Errors = @()
		}
	}

	if ($FenceMatches.Count -ne 2) {
		$Errors += "Patch contains multiple or incomplete Markdown code fences."
		return [pscustomobject]@{
			PatchText = $PatchText
			Sanitized = $false
			Errors = $Errors
		}
	}

	$FencePattern = '(?s)^\s*```(?<language>[A-Za-z0-9_-]*)[ \t]*\r?\n(?<body>.*?)\r?\n```\s*$'
	$Match = [regex]::Match($RawOutput, $FencePattern)
	if (-not $Match.Success) {
		$Errors += "Patch contains Markdown fences with text outside the single fenced block."
		return [pscustomobject]@{
			PatchText = $PatchText
			Sanitized = $false
			Errors = $Errors
		}
	}

	$Language = $Match.Groups["language"].Value
	if ($Language -and @("diff", "patch") -notcontains $Language.ToLowerInvariant()) {
		$Errors += "Patch fenced block language '$Language' is not allowed."
		return [pscustomobject]@{
			PatchText = $PatchText
			Sanitized = $false
			Errors = $Errors
		}
	}

	$PatchText = $Match.Groups["body"].Value.Trim()
	$Sanitized = $true
	return [pscustomobject]@{
		PatchText = $PatchText
		Sanitized = $Sanitized
		Errors = @()
	}
}

function Convert-ModelOutputToJson {
	param([string]$RawOutput)

	$Errors = @()
	$Trimmed = $RawOutput.Trim()
	$Sanitized = $false
	$JsonText = $Trimmed

	$FenceMatches = [regex]::Matches($RawOutput, '```')
	if ($FenceMatches.Count -eq 0) {
		return [pscustomobject]@{
			JsonText = $JsonText
			Sanitized = $false
			Errors = @()
		}
	}

	if ($FenceMatches.Count -ne 2) {
		$Errors += "JSON contains multiple or incomplete Markdown code fences."
		return [pscustomobject]@{
			JsonText = $JsonText
			Sanitized = $false
			Errors = $Errors
		}
	}

	$FencePattern = '(?s)^\s*```(?<language>[A-Za-z0-9_-]*)[ \t]*\r?\n(?<body>.*?)\r?\n```\s*$'
	$Match = [regex]::Match($RawOutput, $FencePattern)
	if (-not $Match.Success) {
		$Errors += "JSON contains Markdown fences with text outside the single fenced block."
		return [pscustomobject]@{
			JsonText = $JsonText
			Sanitized = $false
			Errors = $Errors
		}
	}

	$Language = $Match.Groups["language"].Value
	if ($Language -and $Language.ToLowerInvariant() -ne "json") {
		$Errors += "JSON fenced block language '$Language' is not allowed."
		return [pscustomobject]@{
			JsonText = $JsonText
			Sanitized = $false
			Errors = $Errors
		}
	}

	$JsonText = $Match.Groups["body"].Value.Trim()
	return [pscustomobject]@{
		JsonText = $JsonText
		Sanitized = $true
		Errors = @()
	}
}

function Test-BinaryLookingContent {
	param([string]$Content)

	if ($Content -match "`0") { return $true }
	foreach ($Char in $Content.ToCharArray()) {
		$Code = [int][char]$Char
		if ($Code -lt 32 -and $Code -notin @(9, 10, 13)) {
			return $true
		}
	}
	return $false
}

function ConvertTo-NormalizedTextContent {
	param([string]$Content)

	if (Test-BinaryLookingContent $Content) {
		return [pscustomobject]@{
			Content = $Content
			Changed = $false
			TrimmedLines = 0
		}
	}

	$Lines = @([regex]::Split($Content, "\r?\n"))
	if ($Lines.Count -gt 0 -and $Lines[-1] -eq "") {
		$Lines = @($Lines | Select-Object -First ($Lines.Count - 1))
	}

	$TrimmedLines = 0
	$NormalizedLines = @()
	foreach ($Line in $Lines) {
		$NormalizedLine = $Line -replace "[`t ]+$", ""
		if ($NormalizedLine -ne $Line) {
			$TrimmedLines += 1
		}
		$NormalizedLines += $NormalizedLine
	}

	$NormalizedContent = ($NormalizedLines -join "`n") + "`n"
	return [pscustomobject]@{
		Content = $NormalizedContent
		Changed = ($NormalizedContent -ne $Content)
		TrimmedLines = $TrimmedLines
	}
}

function Normalize-JsonEditManifestText {
	param([object]$Manifest)

	$SummaryLines = @()
	foreach ($Edit in @($Manifest.edits)) {
		if ($null -eq $Edit.content -or -not ($Edit.content -is [string])) { continue }
		$RepoPath = Normalize-RepoPath ([string]$Edit.path)
		$Normalization = ConvertTo-NormalizedTextContent ([string]$Edit.content)
		if ($Normalization.Changed) {
			$Edit.content = $Normalization.Content
			$SummaryLines += "- ${RepoPath}: normalized text whitespace ($($Normalization.TrimmedLines) trailing-whitespace line(s) trimmed; final newline enforced)."
		}
	}

	return [pscustomobject]@{
		Changed = ($SummaryLines.Count -gt 0)
		SummaryLines = @($SummaryLines)
	}
}

function Test-RepoPathAllowed {
	param(
		[string]$Path,
		[string[]]$AllowedPaths,
		[string[]]$BlockedPaths,
		[string[]]$GlobalBlockedPaths,
		[string[]]$BlockedGlobs
	)

	$Errors = @()
	$File = Normalize-RepoPath $Path
	if ([System.IO.Path]::IsPathRooted($File)) {
		$Errors += "Path is absolute: $File"
	}
	if ($File -match '(^|/)\.\.(/|$)') {
		$Errors += "Path uses traversal: $File"
	}
	foreach ($Blocked in @($GlobalBlockedPaths + $BlockedPaths)) {
		if (-not [string]::IsNullOrWhiteSpace($Blocked) -and (Test-PathUnderPrefix $File $Blocked)) {
			$Errors += "Path is blocked: $File"
		}
	}
	foreach ($Glob in $BlockedGlobs) {
		if (Test-GlobMatch $File $Glob) {
			$Errors += "Path matches blocked glob ${Glob}: $File"
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
			$Errors += "Path is outside allowed_paths: $File"
		}
	}
	return [pscustomobject]@{
		Path = $File
		Errors = @($Errors)
	}
}

function Read-JsonEditManifest {
	param([string]$JsonText)

	try {
		return $JsonText | ConvertFrom-Json
	} catch {
		throw "Invalid JSON: $($_.Exception.Message)"
	}
}

function Test-JsonEditManifest {
	param(
		[object]$Manifest,
		[string[]]$AllowedPaths,
		[string[]]$BlockedPaths,
		[string[]]$GlobalBlockedPaths,
		[string[]]$BlockedGlobs,
		[string[]]$RequiredPaths,
		[string[]]$RequiredContent,
		[string[]]$BlockedContent,
		[hashtable]$RequiredContentByPath,
		[hashtable]$BlockedContentByPath,
		[string[]]$PreserveContent,
		[hashtable]$MinLines,
		[string[]]$SameRunReplacePaths,
		[bool]$AllowNewFiles,
		[bool]$AllowReplacements,
		[int]$MaxFilesChanged,
		[bool]$AllowLargeReplacements,
		[int]$MaxReplacedFileLines
	)

	$Errors = @()
	$Files = [ordered]@{}
	$SameRunReplacementFiles = [ordered]@{}
	$AllowedRootFields = @("edits")
	$RootFields = @($Manifest.PSObject.Properties | ForEach-Object { $_.Name })
	foreach ($Field in $RootFields) {
		if ($AllowedRootFields -notcontains $Field) {
			$Errors += "Unknown root field: $Field"
		}
	}
	if (-not $Manifest.PSObject.Properties["edits"]) {
		$Errors += "Missing required root field: edits"
	}
	if (-not ($Manifest.edits -is [array])) {
		$Errors += "Field 'edits' must be an array."
	}

	$EditIndex = 0
	foreach ($Edit in @($Manifest.edits)) {
		$EditIndex += 1
		$AllowedEditFields = @("action", "path", "content", "anchor", "occurrence")
		foreach ($Field in @($Edit.PSObject.Properties | ForEach-Object { $_.Name })) {
			if ($AllowedEditFields -notcontains $Field) {
				$Errors += "Edit ${EditIndex} has unknown field: $Field"
			}
		}
		$Action = [string]$Edit.action
		$Path = [string]$Edit.path
		$Content = $Edit.content
		if (@("create", "replace_entire_file", "insert_after", "insert_before") -notcontains $Action) {
			$Errors += "Edit ${EditIndex} has unsupported action: $Action"
		}
		if ([string]::IsNullOrWhiteSpace($Path)) {
			$Errors += "Edit ${EditIndex} has missing path."
			continue
		}
		if ($null -eq $Content -or -not ($Content -is [string])) {
			$Errors += "Edit ${EditIndex} content must be a string."
		} elseif (Test-BinaryLookingContent $Content) {
			$Errors += "Edit ${EditIndex} content looks binary."
		}
		$PathCheck = Test-RepoPathAllowed -Path $Path -AllowedPaths $AllowedPaths -BlockedPaths $BlockedPaths -GlobalBlockedPaths $GlobalBlockedPaths -BlockedGlobs $BlockedGlobs
		$Errors += $PathCheck.Errors
		$RepoPath = $PathCheck.Path
		$Files[$RepoPath] = $true
		$IsSameRunFile = @($SameRunReplacePaths) -contains $RepoPath
		$FullPath = Join-Path $RepoRoot $RepoPath
		$Exists = Test-Path -LiteralPath $FullPath
		if ($Action -eq "create") {
			if (-not $AllowNewFiles) {
				$Errors += "Edit ${EditIndex} creates a file, but allow_new_files is false."
			}
			if ($Exists -and $IsSameRunFile) {
				$SameRunReplacementFiles[$RepoPath] = $true
			} elseif ($Exists) {
				$Errors += "Edit ${EditIndex} create target already exists: $RepoPath"
			}
		}
		if ($Action -eq "replace_entire_file") {
			if (-not $AllowReplacements -and $IsSameRunFile) {
				$SameRunReplacementFiles[$RepoPath] = $true
			} elseif (-not $AllowReplacements) {
				$Errors += "Edit ${EditIndex} replaces a file, but allow_replacements is false."
			}
			if (-not $Exists) {
				$Errors += "Edit ${EditIndex} replace target does not exist: $RepoPath"
			} else {
				$ExistingText = [System.IO.File]::ReadAllText($FullPath)
				$ExistingLineCount = Get-TextLineCount $ExistingText
				if (-not $AllowLargeReplacements -and $ExistingLineCount -gt $MaxReplacedFileLines) {
					$Errors += "Edit ${EditIndex} replaces large file ${RepoPath} with $ExistingLineCount line(s); limit is $MaxReplacedFileLines unless allow_large_replacements is true."
				}
				foreach ($Token in $PreserveContent) {
					if ([string]::IsNullOrEmpty($Token)) { continue }
					if ($ExistingText.Contains($Token) -and -not ([string]$Content).Contains($Token)) {
						$Errors += "Edit ${EditIndex} fails preserve_content for ${RepoPath}: missing '$Token'."
					}
				}
			}
		}
		if ($Action -eq "insert_after" -or $Action -eq "insert_before") {
			if (-not $Exists) {
				$Errors += "Edit ${EditIndex} ${Action} target does not exist: $RepoPath"
			}
			if (-not $Edit.PSObject.Properties["anchor"] -or [string]::IsNullOrEmpty([string]$Edit.anchor)) {
				$Errors += "Edit ${EditIndex} ${Action} requires a non-empty anchor."
			}
			if ($Edit.PSObject.Properties["occurrence"]) {
				$Occurrence = 1
				if (-not [int]::TryParse([string]$Edit.occurrence, [ref]$Occurrence) -or $Occurrence -lt 1) {
					$Errors += "Edit ${EditIndex} occurrence must be a positive integer."
				}
			}
			if ($Exists -and $Edit.PSObject.Properties["anchor"] -and -not [string]::IsNullOrEmpty([string]$Edit.anchor)) {
				$Occurrence = 1
				if ($Edit.PSObject.Properties["occurrence"] -and [int]::TryParse([string]$Edit.occurrence, [ref]$Occurrence)) {
					# Parsed above; reused for anchor match validation.
				}
				$ExistingText = [System.IO.File]::ReadAllText($FullPath)
				$Matches = [regex]::Matches($ExistingText, [regex]::Escape([string]$Edit.anchor))
				if ($Matches.Count -lt $Occurrence) {
					$Errors += "Edit ${EditIndex} ${Action} anchor was not found $Occurrence time(s) in ${RepoPath}: $($Edit.anchor)"
				}
			}
		}
	}
	if ($Files.Keys.Count -gt $MaxFilesChanged) {
		$Errors += "Edit manifest changes $($Files.Keys.Count) files; limit is $MaxFilesChanged."
	}
	foreach ($RequiredPath in $RequiredPaths) {
		$RequiredCheck = Test-RepoPathAllowed -Path $RequiredPath -AllowedPaths $AllowedPaths -BlockedPaths $BlockedPaths -GlobalBlockedPaths $GlobalBlockedPaths -BlockedGlobs $BlockedGlobs
		$Errors += $RequiredCheck.Errors
		if (-not $Files.Contains($RequiredCheck.Path)) {
			$Errors += "Missing required path in edit manifest: $($RequiredCheck.Path)"
		}
	}
	$ContentInfo = Test-JsonEditContent -Manifest $Manifest -RequiredPaths $RequiredPaths -RequiredContent $RequiredContent -BlockedContent $BlockedContent -RequiredContentByPath $RequiredContentByPath -BlockedContentByPath $BlockedContentByPath -MinLines $MinLines
	$Errors += $ContentInfo.Errors
	return [pscustomobject]@{
		Errors = @($Errors | Sort-Object -Unique)
		Files = @($Files.Keys)
		ContentCheckLines = @($ContentInfo.SummaryLines)
		SameRunReplacementFiles = @($SameRunReplacementFiles.Keys)
	}
}

function Test-JsonEditContent {
	param(
		[object]$Manifest,
		[string[]]$RequiredPaths,
		[string[]]$RequiredContent,
		[string[]]$BlockedContent,
		[hashtable]$RequiredContentByPath,
		[hashtable]$BlockedContentByPath,
		[hashtable]$MinLines
	)

	$Errors = @()
	$SummaryLines = @()
	$RequireTargets = @($RequiredPaths | ForEach-Object { Normalize-RepoPath $_ })
	foreach ($Edit in @($Manifest.edits)) {
		$RepoPath = Normalize-RepoPath ([string]$Edit.path)
		$Content = [string]$Edit.content
		$ShouldRequireContent = $RequireTargets.Count -eq 0 -or @($RequireTargets) -contains $RepoPath
		if ($ShouldRequireContent) {
			foreach ($Token in $RequiredContent) {
				if ([string]::IsNullOrEmpty($Token)) { continue }
				if (-not $Content.Contains($Token)) {
					$Errors += "Content check failed for ${RepoPath}: missing required_content token '$Token'."
				}
			}
		}
		foreach ($Token in $BlockedContent) {
			if ([string]::IsNullOrEmpty($Token)) { continue }
			if ($Content.Contains($Token)) {
				$Errors += "Content check failed for ${RepoPath}: contains blocked_content token '$Token'."
			}
		}
		if ($RequiredContentByPath.ContainsKey($RepoPath)) {
			foreach ($Token in @($RequiredContentByPath[$RepoPath])) {
				if ([string]::IsNullOrEmpty($Token)) { continue }
				if (-not $Content.Contains($Token)) {
					$Errors += "Content check failed for ${RepoPath}: missing required_content_by_path token '$Token'."
				}
			}
			$SummaryLines += "- ${RepoPath}: path-specific required content tokens checked: $(@($RequiredContentByPath[$RepoPath]).Count)."
		}
		if ($BlockedContentByPath.ContainsKey($RepoPath)) {
			foreach ($Token in @($BlockedContentByPath[$RepoPath])) {
				if ([string]::IsNullOrEmpty($Token)) { continue }
				if ($Content.Contains($Token)) {
					$Errors += "Content check failed for ${RepoPath}: contains blocked_content_by_path token '$Token'."
				}
			}
			$SummaryLines += "- ${RepoPath}: path-specific blocked content tokens checked: $(@($BlockedContentByPath[$RepoPath]).Count)."
		}
		if ($MinLines.ContainsKey($RepoPath)) {
			$RequiredLineCount = [int]$MinLines[$RepoPath]
			$ActualLineCount = if ([string]::IsNullOrEmpty($Content)) { 0 } else { @($Content -split "\r?\n").Count }
			if ($ActualLineCount -lt $RequiredLineCount) {
				$Errors += "Content check failed for ${RepoPath}: has $ActualLineCount line(s); min_lines requires $RequiredLineCount."
			}
			$SummaryLines += "- ${RepoPath}: $ActualLineCount line(s), minimum $RequiredLineCount."
		}
	}
	if ($RequiredContent.Count -gt 0) {
		$SummaryLines += "- Global required content tokens checked: $($RequiredContent.Count)."
	}
	if ($BlockedContent.Count -gt 0) {
		$SummaryLines += "- Global blocked content tokens checked: $($BlockedContent.Count)."
	}
	if ($RequiredContentByPath.Keys.Count -gt 0) {
		$SummaryLines += "- Path-specific required content entries checked: $($RequiredContentByPath.Keys.Count)."
	}
	if ($BlockedContentByPath.Keys.Count -gt 0) {
		$SummaryLines += "- Path-specific blocked content entries checked: $($BlockedContentByPath.Keys.Count)."
	}
	return [pscustomobject]@{
		Errors = @($Errors | Sort-Object -Unique)
		SummaryLines = @($SummaryLines)
	}
}

function Apply-JsonEditManifest {
	param([object]$Manifest)

	foreach ($Edit in @($Manifest.edits)) {
		$RepoPath = Normalize-RepoPath ([string]$Edit.path)
		$FullPath = Join-Path $RepoRoot $RepoPath
		$Action = [string]$Edit.action
		if ($Action -eq "create" -or $Action -eq "replace_entire_file") {
			Write-TextFile $FullPath ([string]$Edit.content)
			continue
		}

		if ($Action -eq "insert_after" -or $Action -eq "insert_before") {
			$ExistingText = [System.IO.File]::ReadAllText($FullPath)
			$LineEnding = if ($ExistingText.Contains("`r`n")) { "`r`n" } else { "`n" }
			$Lines = [System.Collections.Generic.List[string]]::new()
			foreach ($Line in ($ExistingText -split "\r?\n", -1)) {
				$Lines.Add($Line)
			}
			if ($Lines.Count -gt 0 -and $Lines[$Lines.Count - 1] -eq "") {
				$Lines.RemoveAt($Lines.Count - 1)
			}
			$Occurrence = 1
			if ($Edit.PSObject.Properties["occurrence"]) {
				$Occurrence = [int]$Edit.occurrence
			}
			$Seen = 0
			$AnchorIndex = -1
			for ($I = 0; $I -lt $Lines.Count; $I++) {
				if ($Lines[$I].Contains([string]$Edit.anchor)) {
					$Seen += 1
					if ($Seen -eq $Occurrence) {
						$AnchorIndex = $I
						break
					}
				}
			}
			if ($AnchorIndex -lt 0) {
				throw "Anchor not found for ${Action} in ${RepoPath}: $($Edit.anchor)"
			}
			$InsertLines = [System.Collections.Generic.List[string]]::new()
			foreach ($Line in (([string]$Edit.content).TrimEnd("`r", "`n") -split "\r?\n", -1)) {
				$InsertLines.Add($Line)
			}
			$InsertIndex = if ($Action -eq "insert_after") { $AnchorIndex + 1 } else { $AnchorIndex }
			$Lines.InsertRange($InsertIndex, $InsertLines)
			Write-TextFile $FullPath (($Lines -join $LineEnding) + $LineEnding)
		}
	}
}

function Get-PatchDiagnostic {
	param([string]$PatchText)

	$Diagnostics = @()
	foreach ($Line in ($PatchText -split "\r?\n")) {
		if ($Line -match '^@@ .*[\+\-]\d+ @@') {
			$Diagnostics += "Malformed hunk header uses shorthand line count: '$Line'. Use explicit start,count form such as '@@ -0,0 +1,1 @@'."
		}
	}
	return ($Diagnostics | Sort-Object -Unique) -join " "
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
	$PreviousErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$Output = & ([scriptblock]::Create($Command)) 2>&1
		$ExitCode = $LASTEXITCODE
		if ($null -eq $ExitCode) { $ExitCode = 0 }
	} catch {
		$Output += $_.Exception.Message
		$ExitCode = 1
	} finally {
		$ErrorActionPreference = $PreviousErrorActionPreference
	}
	$Text = ($Output | Out-String)
	$SeriousLogLines = @(Get-SeriousGodotLogLines $Text)
	if ($SeriousLogLines.Count -gt 0) {
		$Text = $Text.TrimEnd() + @"

Serious Godot validation log lines detected:
$($SeriousLogLines -join "`n")
"@
		if ($ExitCode -eq 0) {
			$ExitCode = 1
		}
	}
	Write-TextFile $LogPath $Text
	return [pscustomobject]@{
		ExitCode = $ExitCode
		Output = $Text
		SeriousLogLines = $SeriousLogLines
	}
}

function Restore-RunnerChanges {
	param(
		[string[]]$Paths
	)

	foreach ($Path in ($Paths | Sort-Object -Unique)) {
		$ExistsInHead = (Invoke-Git @("cat-file", "-e", "HEAD:$Path") -AllowFailure).ExitCode -eq 0
		Invoke-Git @("restore", "--staged", "--", $Path) -AllowFailure | Out-Null
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
Write-RunnerLog "Runner start."

$ConfigPath = Join-Path $ScriptDir "agent_runner.config.json"
if (-not (Test-Path -LiteralPath $ConfigPath)) {
	Stop-Run "Config file not found: $ConfigPath"
}
$Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
Write-RunnerLog "Config loaded: $ConfigPath"

if ([string]::IsNullOrWhiteSpace($Task)) { Stop-Run "Pass -Task <path-to-task.md>." }
if ([string]::IsNullOrWhiteSpace($Endpoint)) { $Endpoint = $Config.endpoint }
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = $Config.model }
if (-not $PSBoundParameters.ContainsKey("MaxAttempts")) { $MaxAttempts = [int]$Config.maxAttempts }
if (-not $PSBoundParameters.ContainsKey("MaxFilesChanged")) { $MaxFilesChanged = [int]$Config.maxFilesChanged }
if (-not $PSBoundParameters.ContainsKey("MaxLinesAdded")) { $MaxLinesAdded = [int]$Config.maxLinesAdded }
if (-not $PSBoundParameters.ContainsKey("MaxLinesDeleted")) { $MaxLinesDeleted = [int]$Config.maxLinesDeleted }
$DefaultAllowLargeReplacements = if ($null -ne $Config.allowLargeReplacements) { [bool]$Config.allowLargeReplacements } else { $false }
$DefaultMaxReplacedFileLines = if ($null -ne $Config.maxReplacedFileLines) { [int]$Config.maxReplacedFileLines } else { 300 }
$DefaultMaxDeletedLinesRatio = if ($null -ne $Config.maxDeletedLinesRatio) { [double]$Config.maxDeletedLinesRatio } else { 0.25 }

$GitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $GitCommand) { Stop-Run "Git was not found on PATH." }
if (-not (Get-Command powershell -ErrorAction SilentlyContinue)) { Stop-Run "Windows PowerShell was not found on PATH." }
Write-RunnerLog "Git preflight started."

$GitRoot = (Invoke-Git @("rev-parse", "--show-toplevel")).Output
if ([string]::IsNullOrWhiteSpace($GitRoot)) { Stop-Run "Not inside a Git repository." }
$GitRoot = (Resolve-Path -LiteralPath $GitRoot).Path
if ($GitRoot -ne $RepoRoot) { Set-Location $GitRoot; $RepoRoot = $GitRoot }
Write-RunnerLog "Git preflight completed. Repo root: $RepoRoot"

$TaskPath = $Task
if (-not [System.IO.Path]::IsPathRooted($TaskPath)) {
	$TaskPath = Join-Path $RepoRoot $TaskPath
}
if (-not (Test-Path -LiteralPath $TaskPath)) {
	Stop-Run "Task file not found: $Task"
}

$TaskData = Read-TaskFile $TaskPath
$Meta = $TaskData.Metadata
Write-RunnerLog "Task parsed: $TaskPath"

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
$AllowReplacements = [bool](Get-MetaValue $Meta "allow_replacements" $false)
$EditMode = Get-MetaValue $Meta "edit_mode" "unified_diff"
if (@("unified_diff", "json_file_ops") -notcontains $EditMode) {
	Stop-Run "Unsupported edit_mode '$EditMode'. Supported modes: unified_diff, json_file_ops."
}
$CommitMessage = Get-MetaValue $Meta "commit_message" "chore: apply local agent patch"
$TaskTitle = Get-MetaValue $Meta "title" (Split-Path -Leaf $TaskPath)
$AllowedPaths = @(Get-MetaValue $Meta "allowed_paths" @())
$TaskBlockedPaths = @(Get-MetaValue $Meta "blocked_paths" @())
$RequiredPaths = @((Get-MetaValue $Meta "required_paths" @()) | ForEach-Object { Normalize-RepoPath $_ })
$RequiredContent = @(Get-MetaValue $Meta "required_content" @())
$BlockedContent = @(Get-MetaValue $Meta "blocked_content" @())
$RequiredContentByPath = Get-MetaListMap $Meta "required_content_by_path"
$BlockedContentByPath = Get-MetaListMap $Meta "blocked_content_by_path"
$PreserveContent = @(Get-MetaValue $Meta "preserve_content" @())
$MinLines = Get-MetaMap $Meta "min_lines"
$AllowLargeReplacements = [bool](Get-MetaValue $Meta "allow_large_replacements" $DefaultAllowLargeReplacements)
$MaxReplacedFileLines = [int](Get-MetaValue $Meta "max_replaced_file_lines" $DefaultMaxReplacedFileLines)
$MaxDeletedLinesRatio = [double](Get-MetaValue $Meta "max_deleted_lines_ratio" $DefaultMaxDeletedLinesRatio)
$GlobalBlockedPaths = @($Config.globalBlockedPaths)
$BlockedGlobs = @($Config.defaultBlockedGlobs)
$ArtifactRoot = $Config.artifactRoot

Write-RunnerLog "LM Studio endpoint check started: $($Endpoint.TrimEnd('/'))/models"
Write-RunnerLog "Model availability check started: $Model"
if (-not (Test-ModelAvailable $Endpoint $Model)) {
	Stop-Run "Endpoint responded, but model '$Model' was not listed at $($Endpoint.TrimEnd('/'))/models."
}
Write-RunnerLog "LM Studio endpoint check completed."
Write-RunnerLog "Model availability check completed: $Model"

$InitialDirty = @(Get-StatusPaths)
if ($InitialDirty.Count -gt 0) {
	if (-not $Resume) {
		Stop-Run "Working tree is dirty. Commit, stash, or clean changes before running."
	}
	if (-not (Test-OnlyAllowedDirtyPaths @("$ArtifactRoot/"))) {
		Stop-Run "Working tree is dirty outside runner-owned artifacts; refusing resume."
	}
}

$BranchExists = (Invoke-Git @("rev-parse", "--verify", $BranchName) -AllowFailure).ExitCode -eq 0
if ($BranchExists -and -not $Resume) {
	Stop-Run "Branch '$BranchName' already exists. Pass -Resume to continue on it."
}

Write-RunnerLog "Branch setup started. Base: $BaseBranch; feature: $BranchName; exists: $BranchExists"
if ($BranchExists) {
	Invoke-Git @("switch", $BranchName) | Out-Null
} else {
	Invoke-Git @("switch", $BaseBranch) | Out-Null
	Invoke-Git @("switch", "-c", $BranchName) | Out-Null
}
Write-RunnerLog "Branch setup completed. Current branch: $BranchName"

$RunId = Get-Date -Format "yyyyMMdd-HHmmss"
$RunDirRel = (Join-Path $ArtifactRoot $RunId) -replace '\\', '/'
$RunDir = Join-Path $RepoRoot $RunDirRel
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$RunnerLogPath = Join-Path $RunDir "runner.log"
Initialize-RunnerLogFile $RunnerLogPath
Write-RunnerLog "Artifact directory created: $RunDirRel"

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
- Required paths: $($RequiredPaths -join ', ')
- Required content: $($RequiredContent -join ', ')
- Blocked content: $($BlockedContent -join ', ')
- Required content by path: $(Format-ListMapSummary $RequiredContentByPath)
- Blocked content by path: $(Format-ListMapSummary $BlockedContentByPath)
- Preserve content: $($PreserveContent -join ', ')
- Min lines: $((@($MinLines.Keys) | ForEach-Object { "$_=$($MinLines[$_])" }) -join ', ')
- Blocked paths: $(@($GlobalBlockedPaths + $TaskBlockedPaths) -join ', ')
- Blocked globs: $($BlockedGlobs -join ', ')
- Allow new files: $AllowNewFiles
- Allow deletes: $AllowDeletes
- Allow renames: $AllowRenames
- Allow replacements: $AllowReplacements
- Allow large replacements: $AllowLargeReplacements
- Max replaced file lines: $MaxReplacedFileLines
- Max deleted lines ratio: $MaxDeletedLinesRatio
- Edit mode: $EditMode
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
Write-RunnerLog "Planning prompt written: $RunDirRel/prompt-plan.txt"
Write-RunnerLog "Sending planning request to LM Studio."
Write-RunnerLog "Waiting for LM Studio response..."
$PlanRequestStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$Plan = Invoke-LocalChat -Endpoint $Endpoint -Model $Model -SystemPrompt "You are a careful local coding planner. You do not claim to run tools." -UserPrompt $PlanPrompt -MaxTokens 2048
$PlanRequestStopwatch.Stop()
Write-RunnerLog "LM Studio response received. Planning request duration: $(Format-Duration $PlanRequestStopwatch.Elapsed)"
Write-RunnerLog "Planning response received."
Write-TextFile $RawPlanPath $Plan
Write-TextFile $PlanPath $Plan
Write-RunnerLog "Plan written: $RunDirRel/plan.md"

$PatchSystemPrompt = "You produce valid unified git diffs only. No Markdown, no code fences, no explanations, no prose. Always use explicit hunk ranges with comma counts, for example +1,1 instead of +1."
$UnifiedDiffInstructions = @'
Unified diff requirements:
- Use real repo-relative paths.
- Use `diff --git a/path b/path` headers.
- Use `--- a/path` and `+++ b/path` for existing-file edits.
- For a new file, include `diff --git a/path b/path`, `new file mode 100644`, `index 0000000..<hash-or-0000000>`, `--- /dev/null`, `+++ b/path`, and a valid `@@` hunk.
- Keep `a/` and `b/` prefixes consistent when the unified diff format requires them.
- Hunk headers must match the actual lines in the hunk.
- Hunk headers use `@@ -old_start,old_count +new_start,new_count @@`.
- Always include comma counts in both old and new ranges.
- Never use shorthand hunk ranges like `+1` or `-3`; use `+1,1` or `-3,1`.
- For a one-line new file, use `@@ -0,0 +1,1 @@`, not `@@ -0,0 +1 @@`.
- Every added content line in a hunk must start with `+`.
- Every removed content line in a hunk must start with `-`.
- Context lines must start with one space.
- Do not include placeholder metadata, invented absolute paths, or explanatory text.

Minimal valid new-file example:
diff --git a/docs/example.md b/docs/example.md
new file mode 100644
index 0000000..0000000
--- /dev/null
+++ b/docs/example.md
@@ -0,0 +1,1 @@
+Example line.
'@
$JsonSystemPrompt = "You produce strict JSON edit manifests only. No Markdown, no code fences unless the entire response is one json fenced block, no explanations, no prose."
$JsonEditInstructions = @'
JSON file-operation requirements:
- Return exactly one JSON object with this shape:
{
  "edits": [
    {
      "action": "create",
      "path": "docs/example.md",
      "content": "file contents here\n"
    }
  ]
}
- Supported actions are only "create", "replace_entire_file", "insert_after", and "insert_before".
- Prefer insert_after or insert_before for existing large files.
- insert_after and insert_before require "path", "anchor", and "content". Optional "occurrence" selects which anchor match to use.
- Do not use replace_entire_file for large existing files unless the task explicitly allows large replacements.
- Do not include delete, rename, shell commands, patches, partial edits, comments, or extra fields.
- Use real repo-relative paths with forward slashes.
- If required paths are listed in the runner constraints, include every required path exactly.
- Do not use absolute paths or ../ traversal.
- For each task, edit only the paths required or directly necessary for the task.
- The runner will write files, generate the Git diff, run validation, and commit if allowed.
'@
if ($EditMode -eq "json_file_ops") {
	$PatchSystemPrompt = $JsonSystemPrompt
	$PatchPromptBase = @"
Create the implementation edits for the task below.

Return ONLY strict JSON.
No Markdown unless the entire response is exactly one fenced json block.
No explanations.
No tool-call text.
No prose before or after the JSON.

$JsonEditInstructions

$ConstraintText

Plan:
$Plan

Task file:
$($TaskData.Content)
"@
} else {
	$PatchPromptBase = @"
Create the implementation patch for the task below.

Return ONLY a unified diff.
No Markdown.
No code fences.
No explanations.
No tool-call text.
No prose before or after the diff.

$UnifiedDiffInstructions

$ConstraintText

Plan:
$Plan

Task file:
$($TaskData.Content)
"@
}

Write-TextFile $PromptPatchPath $PatchPromptBase
Write-RunnerLog "Edit prompt written: $RunDirRel/prompt-patch.txt"

$AttemptLines = @()
$SafetyLines = @(
	"- Parsed task front matter.",
	"- Confirmed Git repository and repo root.",
	"- Confirmed LM Studio/OpenAI-compatible endpoint and configured model.",
	"- Enforced branch ownership.",
	"- Edit mode: $EditMode.",
	"- Enforced blocked paths, allowed paths, file budget, and line budgets.",
	"- Used explicit staging only; never git add .."
)
if ($EditMode -eq "json_file_ops") {
	$SafetyLines += "- JSON file-operation mode uses runner-owned file writes and Git-generated diffs."
	$SafetyLines += "- Accepted raw JSON or exactly one fenced json block with no surrounding prose."
	$SafetyLines += "- Normalized JSON text edits before writing by trimming trailing line whitespace and enforcing a final newline."
	$SafetyLines += "- Allowed same-run repair replacement only for files created earlier by this runner run."
	$SafetyLines += "- Rejected destructive large-file replacement unless explicitly allowed by task."
	$SafetyLines += "- Enforced preserve_content tokens for changed existing files."
	if ($RequiredContent.Count -gt 0 -or $BlockedContent.Count -gt 0 -or $MinLines.Keys.Count -gt 0) {
		$SafetyLines += "- Enforced task content checks before writing JSON file-operation edits."
		$SafetyLines += "- Global required content tokens: $($RequiredContent.Count); global blocked content tokens: $($BlockedContent.Count); min_lines entries: $($MinLines.Keys.Count)."
	}
	if ($RequiredContentByPath.Keys.Count -gt 0 -or $BlockedContentByPath.Keys.Count -gt 0) {
		$SafetyLines += "- Enforced path-specific content checks before writing JSON file-operation edits."
		$SafetyLines += "- Path-specific required content entries: $($RequiredContentByPath.Keys.Count); path-specific blocked content entries: $($BlockedContentByPath.Keys.Count)."
	}
} else {
	$SafetyLines += "- Accepted raw unified diffs or exactly one fenced diff/patch block with no surrounding prose."
	$SafetyLines += "- Used git apply --check --whitespace=error before applying patches."
}
$ApprovedPatchFiles = @()
$FinalStatus = "failed"
$StopReason = "attempts exhausted"
$CommitHash = ""
$ValidationExitCode = -1
$ValidationSummary = "Validation did not run."
$LastPatchInfo = $null
$LastRejectedPatch = ""
$LastFailure = ""
$AppliedAnyPatch = $false
$RunnerCreatedPaths = @()

for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
	Write-RunnerLog "Edit attempt $Attempt started."
	$RawPatchPath = Join-Path $RunDir ("raw-patch-attempt-{0}.txt" -f $Attempt)
	$PatchPath = Join-Path $RunDir ("patch-attempt-{0}.diff" -f $Attempt)
	$JsonPath = Join-Path $RunDir ("edits-attempt-{0}.json" -f $Attempt)
	$ManifestPath = Join-Path $RunDir ("edit-manifest-attempt-{0}.json" -f $Attempt)

	if ($Attempt -eq 1) {
		$PatchPrompt = $PatchPromptBase
	} else {
		$CurrentDiff = (Invoke-Git @("diff", "--") ).Output
		$ValidationText = if (Test-Path -LiteralPath $ValidationLogPath) { [System.IO.File]::ReadAllText($ValidationLogPath) } else { "" }
		if ($EditMode -eq "json_file_ops") {
			$PatchPrompt = @"
Repair the current failed JSON file-operation edits.

Return ONLY strict JSON.
No Markdown unless the entire response is exactly one fenced json block.
No explanations.
No tool-call text.
No prose before or after the JSON.

$JsonEditInstructions

$ConstraintText

Last failure:
$LastFailure

Rejected sanitized JSON or current diff:
$LastRejectedPatch

Original task:
$($TaskData.Content)

Original plan:
$Plan

Current diff:
$CurrentDiff

Validation log:
$ValidationText
"@
		} else {
			$PatchPrompt = @"
Repair the current failed patch.

Return ONLY a unified diff.
No Markdown.
No code fences.
No explanations.
No tool-call text.
No prose before or after the diff.

$UnifiedDiffInstructions

$ConstraintText

Last failure:
$LastFailure

Rejected sanitized patch:
$LastRejectedPatch

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
	}
	Write-RunnerLog "Edit prompt prepared for attempt $Attempt."

	$EditRequestStopwatch = $null
	try {
		Write-RunnerLog "Sending edit request to LM Studio for attempt $Attempt."
		Write-RunnerLog "Waiting for LM Studio response..."
		$EditRequestStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
		$RawPatch = Invoke-LocalChat -Endpoint $Endpoint -Model $Model -SystemPrompt $PatchSystemPrompt -UserPrompt $PatchPrompt -MaxTokens 4096
		$EditRequestStopwatch.Stop()
		Write-RunnerLog "LM Studio response received. Edit request attempt $Attempt duration: $(Format-Duration $EditRequestStopwatch.Elapsed)"
		Write-RunnerLog "Edit response received for attempt $Attempt."
	} catch {
		if ($EditRequestStopwatch) {
			$EditRequestStopwatch.Stop()
			Write-RunnerLog "LM Studio request failed after $(Format-Duration $EditRequestStopwatch.Elapsed)."
		}
		$LastFailure = "Model/API request failed: $($_.Exception.Message)"
		$AttemptLines += "- Attempt ${Attempt}: model/API request failed: $($_.Exception.Message)"
		$ValidationExitCode = 1
		$ValidationSummary = "Model/API request failed before validation."
		$StopReason = "model/API failure; runner-applied files rolled back if any"
		break
	}
	Write-TextFile $RawPatchPath $RawPatch

	if ($EditMode -eq "json_file_ops") {
		Write-RunnerLog "JSON sanitization started for attempt $Attempt."
		$SanitizedJson = Convert-ModelOutputToJson $RawPatch
		if ($SanitizedJson.Errors.Count -gt 0) {
			Write-TextFile $JsonPath $RawPatch.Trim()
			$LastRejectedPatch = $RawPatch.Trim()
			$LastFailure = "JSON sanitization failed: $($SanitizedJson.Errors -join '; ')"
			$AttemptLines += "- Attempt ${Attempt}: rejected during JSON sanitization: $($SanitizedJson.Errors -join '; ')"
			Write-RunnerLog "JSON sanitization failed for attempt $Attempt."
			continue
		}
		Write-RunnerLog "JSON sanitization completed for attempt $Attempt."
		Write-TextFile $JsonPath $SanitizedJson.JsonText

		try {
			$Manifest = Read-JsonEditManifest $SanitizedJson.JsonText
		} catch {
			$LastRejectedPatch = $SanitizedJson.JsonText
			$LastFailure = $_.Exception.Message
			$AttemptLines += "- Attempt ${Attempt}: rejected invalid JSON: $LastFailure"
			Write-RunnerLog "Edit manifest JSON parse failed for attempt $Attempt."
			continue
		}
		$NormalizationInfo = Normalize-JsonEditManifestText $Manifest
		Write-TextFile $ManifestPath ($Manifest | ConvertTo-Json -Depth 20)
		foreach ($NormalizationLine in @($NormalizationInfo.SummaryLines)) {
			$AttemptLines += "- Attempt ${Attempt}: whitespace normalization $($NormalizationLine.TrimStart('-').Trim())"
		}

		Write-RunnerLog "Edit manifest validation started for attempt $Attempt."
		Write-RunnerLog "Content checks started for attempt $Attempt."
		$ManifestInfo = Test-JsonEditManifest -Manifest $Manifest -AllowedPaths $AllowedPaths -BlockedPaths $TaskBlockedPaths -GlobalBlockedPaths $GlobalBlockedPaths -BlockedGlobs $BlockedGlobs -RequiredPaths $RequiredPaths -RequiredContent $RequiredContent -BlockedContent $BlockedContent -RequiredContentByPath $RequiredContentByPath -BlockedContentByPath $BlockedContentByPath -PreserveContent $PreserveContent -MinLines $MinLines -SameRunReplacePaths $RunnerCreatedPaths -AllowNewFiles $AllowNewFiles -AllowReplacements $AllowReplacements -MaxFilesChanged $MaxFilesChanged -AllowLargeReplacements $AllowLargeReplacements -MaxReplacedFileLines $MaxReplacedFileLines
		if ($ManifestInfo.Errors.Count -gt 0) {
			$JsonSanitizationStatus = if ($SanitizedJson.Sanitized) { "single fenced json extracted" } else { "raw JSON" }
			$LastRejectedPatch = $SanitizedJson.JsonText
			$LastFailure = "JSON edit manifest checks failed after sanitization '$JsonSanitizationStatus': $($ManifestInfo.Errors -join '; ')"
			$AttemptLines += "- Attempt ${Attempt}: rejected JSON edit manifest after sanitization '$JsonSanitizationStatus': $($ManifestInfo.Errors -join '; ')"
			Write-RunnerLog "Edit manifest validation failed for attempt $Attempt."
			Write-RunnerLog "Content checks failed for attempt $Attempt."
			continue
		}
		Write-RunnerLog "Edit manifest validation completed for attempt $Attempt."
		Write-RunnerLog "Content checks completed for attempt $Attempt."
		foreach ($ContentCheckLine in @($ManifestInfo.ContentCheckLines)) {
			$AttemptLines += "- Attempt ${Attempt}: content check $($ContentCheckLine.TrimStart('-').Trim())"
		}
		foreach ($SameRunPath in @($ManifestInfo.SameRunReplacementFiles)) {
			$AttemptLines += "- Attempt ${Attempt}: same-run repair replacement allowed for $SameRunPath."
		}

		Write-RunnerLog "File writes started for attempt $Attempt."
		Apply-JsonEditManifest $Manifest
		Write-RunnerLog "File writes completed for attempt $Attempt."
		$AppliedAnyPatch = $true
		$ApprovedPatchFiles = @($ApprovedPatchFiles + $ManifestInfo.Files) | Sort-Object -Unique
		foreach ($ManifestPathItem in $ManifestInfo.Files) {
			$ExistsInHead = (Invoke-Git @("cat-file", "-e", "HEAD:$ManifestPathItem") -AllowFailure).ExitCode -eq 0
			if (-not $ExistsInHead) {
				Invoke-Git @("add", "-N", "--", $ManifestPathItem) | Out-Null
				$RunnerCreatedPaths = @($RunnerCreatedPaths + $ManifestPathItem) | Sort-Object -Unique
			}
		}
		$JsonSanitizationStatus = if ($SanitizedJson.Sanitized) { "single fenced json extracted" } else { "raw JSON" }
		$AttemptLines += "- Attempt ${Attempt}: JSON edits applied to $($ManifestInfo.Files.Count) file(s); sanitization: $JsonSanitizationStatus."

		Write-RunnerLog "Cumulative diff safety checks started for attempt $Attempt."
		$DiffSafety = Test-CurrentDiffSafety -IgnorePrefixes @($ArtifactRoot) -MaxFilesChanged $MaxFilesChanged -MaxLinesAdded $MaxLinesAdded -MaxLinesDeleted $MaxLinesDeleted -MaxDeletedLinesRatio $MaxDeletedLinesRatio -PreserveContent $PreserveContent
		$Budget = $DiffSafety.Budget
		if ($DiffSafety.Errors.Count -gt 0) {
			$AttemptLines += "- Attempt ${Attempt}: cumulative diff safety checks failed ($($Budget.Files.Count) files, +$($Budget.Added), -$($Budget.Deleted)): $($DiffSafety.Errors -join '; ')"
			$ValidationExitCode = 1
			$ValidationSummary = "Cumulative diff safety checks failed."
			$LastRejectedPatch = (Invoke-Git @("diff", "--") ).Output
			$LastFailure = "Cumulative diff safety checks failed: $($DiffSafety.Errors -join '; ')"
			Write-RunnerLog "Cumulative diff safety checks failed for attempt $Attempt."
			continue
		}
		Write-RunnerLog "Cumulative diff safety checks completed for attempt $Attempt."

		Write-RunnerLog "git diff check started for attempt $Attempt."
		$DiffCheck = Invoke-Git @("diff", "--check") -AllowFailure
		if ($DiffCheck.ExitCode -ne 0) {
			$AttemptLines += "- Attempt ${Attempt}: git diff --check failed: $($DiffCheck.Output)"
			$ValidationExitCode = $DiffCheck.ExitCode
			$ValidationSummary = "git diff --check failed."
			$LastRejectedPatch = (Invoke-Git @("diff", "--") ).Output
			$LastFailure = "git diff --check failed after applying JSON edits: $($DiffCheck.Output)"
			Write-RunnerLog "git diff check failed for attempt $Attempt."
			continue
		}
		Write-RunnerLog "git diff check completed for attempt $Attempt."

		Write-RunnerLog "Validation command started for attempt $Attempt."
		$ValidationStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
		$Validation = Invoke-ValidationCommand -Command $ValidationCommand -LogPath $ValidationLogPath
		$ValidationStopwatch.Stop()
		Write-RunnerLog "Validation command completed for attempt $Attempt. Duration: $(Format-Duration $ValidationStopwatch.Elapsed)"
		$ValidationExitCode = $Validation.ExitCode
		$ValidationSummary = if ($Validation.ExitCode -eq 0) { "Validation passed." } elseif (@($Validation.SeriousLogLines).Count -gt 0) { "Validation failed because serious Godot log lines were detected. See validation.log." } else { "Validation failed. See validation.log." }
		$AttemptLines += "- Attempt ${Attempt}: validation exit code $ValidationExitCode."
		if ($Validation.ExitCode -ne 0) {
			$LastRejectedPatch = (Invoke-Git @("diff", "--") ).Output
			$LastFailure = "Validation failed with exit code $ValidationExitCode. See validation log below."
		}
		if ($Validation.ExitCode -eq 0) {
			$FinalStatus = "passed"
			$StopReason = if ($NoCommit) { "validation passed; NoCommit set" } else { "validation passed and committed" }
			break
		}
		continue
	}

	$SanitizedPatch = Convert-ModelOutputToPatch $RawPatch
	if ($SanitizedPatch.Errors.Count -gt 0) {
		Write-TextFile $PatchPath $RawPatch.Trim()
		$LastRejectedPatch = $RawPatch.Trim()
		$LastFailure = "Sanitization failed: $($SanitizedPatch.Errors -join '; ')"
		$AttemptLines += "- Attempt ${Attempt}: rejected during sanitization: $($SanitizedPatch.Errors -join '; ')"
		continue
	}
	$PatchText = $SanitizedPatch.PatchText
	Write-TextFile $PatchPath $PatchText

	Write-RunnerLog "Patch safety checks started for attempt $Attempt."
	$PatchInfo = Get-PatchInfo -PatchText $PatchText -AllowedPaths $AllowedPaths -BlockedPaths $TaskBlockedPaths -GlobalBlockedPaths $GlobalBlockedPaths -BlockedGlobs $BlockedGlobs -AllowNewFiles $AllowNewFiles -AllowDeletes $AllowDeletes -AllowRenames $AllowRenames -MaxFilesChanged $MaxFilesChanged -MaxLinesAdded $MaxLinesAdded -MaxLinesDeleted $MaxLinesDeleted
	$LastPatchInfo = $PatchInfo

	if ($PatchInfo.Errors.Count -gt 0) {
		$SanitizationStatus = if ($SanitizedPatch.Sanitized) { "single fenced diff extracted" } else { "raw unified diff" }
		$LastRejectedPatch = $PatchText
		$LastFailure = "Patch safety checks failed after sanitization '$SanitizationStatus': $($PatchInfo.Errors -join '; ')"
		$AttemptLines += "- Attempt ${Attempt}: rejected before apply after sanitization '$SanitizationStatus': $($PatchInfo.Errors -join '; ')"
		Write-RunnerLog "Patch safety checks failed for attempt $Attempt."
		continue
	}
	Write-RunnerLog "Patch safety checks completed for attempt $Attempt."

	Write-RunnerLog "git apply check started for attempt $Attempt."
	$Check = Invoke-Git @("apply", "--check", "--whitespace=error", $PatchPath) -AllowFailure
	if ($Check.ExitCode -ne 0) {
		$SanitizationStatus = if ($SanitizedPatch.Sanitized) { "single fenced diff extracted" } else { "raw unified diff" }
		$LastRejectedPatch = $PatchText
		$PatchDiagnostic = Get-PatchDiagnostic $PatchText
		$DiagnosticSuffix = if ($PatchDiagnostic) { " Diagnostic: $PatchDiagnostic" } else { "" }
		$LastFailure = "git apply --check --whitespace=error failed after sanitization '$SanitizationStatus': $($Check.Output)$DiagnosticSuffix"
		$AttemptLines += "- Attempt ${Attempt}: git apply --check failed after sanitization '$SanitizationStatus': $($Check.Output)"
		Write-RunnerLog "git apply check failed for attempt $Attempt."
		continue
	}
	Write-RunnerLog "git apply check completed for attempt $Attempt."

	Write-RunnerLog "File writes started for attempt $Attempt."
	Invoke-Git @("apply", "--whitespace=error", $PatchPath) | Out-Null
	Write-RunnerLog "File writes completed for attempt $Attempt."
	$AppliedAnyPatch = $true
	$ApprovedPatchFiles = @($ApprovedPatchFiles + $PatchInfo.Files) | Sort-Object -Unique
	$SanitizationStatus = if ($SanitizedPatch.Sanitized) { "single fenced diff extracted" } else { "raw unified diff" }
	$AttemptLines += "- Attempt ${Attempt}: patch applied to $($PatchInfo.Files.Count) file(s); sanitization: $SanitizationStatus."

	Write-RunnerLog "Cumulative diff safety checks started for attempt $Attempt."
	$DiffSafety = Test-CurrentDiffSafety -IgnorePrefixes @($ArtifactRoot) -MaxFilesChanged $MaxFilesChanged -MaxLinesAdded $MaxLinesAdded -MaxLinesDeleted $MaxLinesDeleted -MaxDeletedLinesRatio $MaxDeletedLinesRatio -PreserveContent $PreserveContent
	$Budget = $DiffSafety.Budget
	if ($DiffSafety.Errors.Count -gt 0) {
		$AttemptLines += "- Attempt ${Attempt}: cumulative diff safety checks failed ($($Budget.Files.Count) files, +$($Budget.Added), -$($Budget.Deleted)): $($DiffSafety.Errors -join '; ')"
		$ValidationExitCode = 1
		$ValidationSummary = "Cumulative diff safety checks failed."
		$LastRejectedPatch = (Invoke-Git @("diff", "--") ).Output
		$LastFailure = "Cumulative diff safety checks failed: $($DiffSafety.Errors -join '; ')"
		Write-RunnerLog "Cumulative diff safety checks failed for attempt $Attempt."
		continue
	}
	Write-RunnerLog "Cumulative diff safety checks completed for attempt $Attempt."

	Write-RunnerLog "git diff check started for attempt $Attempt."
	$DiffCheck = Invoke-Git @("diff", "--check") -AllowFailure
	if ($DiffCheck.ExitCode -ne 0) {
		$AttemptLines += "- Attempt ${Attempt}: git diff --check failed: $($DiffCheck.Output)"
		$ValidationExitCode = $DiffCheck.ExitCode
		$ValidationSummary = "git diff --check failed."
		$LastRejectedPatch = (Invoke-Git @("diff", "--") ).Output
		$LastFailure = "git diff --check failed after applying patch: $($DiffCheck.Output)"
		Write-RunnerLog "git diff check failed for attempt $Attempt."
		continue
	}
	Write-RunnerLog "git diff check completed for attempt $Attempt."

	Write-RunnerLog "Validation command started for attempt $Attempt."
	$ValidationStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
	$Validation = Invoke-ValidationCommand -Command $ValidationCommand -LogPath $ValidationLogPath
	$ValidationStopwatch.Stop()
	Write-RunnerLog "Validation command completed for attempt $Attempt. Duration: $(Format-Duration $ValidationStopwatch.Elapsed)"
	$ValidationExitCode = $Validation.ExitCode
	$ValidationSummary = if ($Validation.ExitCode -eq 0) { "Validation passed." } elseif (@($Validation.SeriousLogLines).Count -gt 0) { "Validation failed because serious Godot log lines were detected. See validation.log." } else { "Validation failed. See validation.log." }
	$AttemptLines += "- Attempt ${Attempt}: validation exit code $ValidationExitCode."
	if ($Validation.ExitCode -ne 0) {
		$LastRejectedPatch = (Invoke-Git @("diff", "--") ).Output
		$LastFailure = "Validation failed with exit code $ValidationExitCode. See validation log below."
	}

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
	"$RunDirRel/runner.log",
	"$RunDirRel/validation.log",
	"$RunDirRel/report.md"
)
for ($I = 1; $I -le $MaxAttempts; $I++) {
	$ArtifactRelPaths += "$RunDirRel/raw-patch-attempt-$I.txt"
	$ArtifactRelPaths += "$RunDirRel/patch-attempt-$I.diff"
	$ArtifactRelPaths += "$RunDirRel/edits-attempt-$I.json"
	$ArtifactRelPaths += "$RunDirRel/edit-manifest-attempt-$I.json"
}
$ArtifactRelPaths = @($ArtifactRelPaths | Where-Object { Test-Path -LiteralPath (Join-Path $RepoRoot $_) })

$RequestedScope = @(
	"- Allowed paths: $($AllowedPaths -join ', ')",
	"- Required paths: $($RequiredPaths -join ', ')",
	"- Task blocked paths: $($TaskBlockedPaths -join ', ')",
	"- Global blocked paths: $($GlobalBlockedPaths -join ', ')",
	"- New files allowed: $AllowNewFiles",
	"- Replacements allowed: $AllowReplacements",
	"- Large replacements allowed: $AllowLargeReplacements",
	"- Max replaced file lines: $MaxReplacedFileLines",
	"- Max deleted lines ratio: $MaxDeletedLinesRatio",
	"- Preserve content: $($PreserveContent -join ', ')",
	"- Global required content tokens: $($RequiredContent.Count)",
	"- Global blocked content tokens: $($BlockedContent.Count)",
	"- Path-specific required content: $(Format-ListMapSummary $RequiredContentByPath)",
	"- Path-specific blocked content: $(Format-ListMapSummary $BlockedContentByPath)",
	"- Deletes allowed: $AllowDeletes",
	"- Renames allowed: $AllowRenames",
	"- Edit mode: $EditMode"
)
$ArtifactLines = @($ArtifactRelPaths | ForEach-Object { "- $_" })
$ResidualRisks = @(
	"- Validation is an import pass and does not prove every gameplay path.",
	"- v0 rejects noisy model output instead of attempting broad extraction.",
	"- A report committed in the same commit cannot contain its own final commit hash; the runner prints the final hash after commit.",
	"- Task success is bounded by the model context supplied to the prompt."
)

if ($FinalStatus -ne "passed" -and $AppliedAnyPatch -and -not $KeepFailedChanges) {
	Write-RunnerLog "Rollback started."
	Restore-RunnerChanges $ApprovedPatchFiles
	Write-RunnerLog "Rollback completed."
	$FilesChanged = @(Get-StatusPaths)
	$StopReason = "attempts exhausted; runner-applied files rolled back"
}

$ReportCommitHash = $CommitHash
if ($FinalStatus -eq "passed" -and -not $NoCommit) {
	$ReportCommitHash = "(pending; final hash printed by runner)"
}

New-Report -Path $ReportPath -TaskTitle $TaskTitle -RunId $RunId -Started $Started -Finished $Finished -BaseBranch $BaseBranch -BranchName $BranchName -Model $Model -Endpoint $Endpoint -MaxAttempts $MaxAttempts -FinalStatus $FinalStatus -StopReason $StopReason -CommitHash $ReportCommitHash -RequestedScope $RequestedScope -FilesChanged (@($ApprovedPatchFiles | ForEach-Object { "- $_" })) -DiffSummary $DiffSummary -ValidationCommand $ValidationCommand -ValidationExitCode $ValidationExitCode -ValidationSummary $ValidationSummary -AttemptLines $AttemptLines -SafetyLines $SafetyLines -ArtifactLines $ArtifactLines -ResidualRisks $ResidualRisks
Write-RunnerLog "Report written: $RunDirRel/report.md"

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

Write-RunnerLog "Final status: $FinalStatus. Stop reason: $StopReason. Total duration: $(Format-Duration $RunStopwatch.Elapsed)"
Write-Host "Run ID: $RunId"
Write-Host "Status: $FinalStatus"
Write-Host "Stop reason: $StopReason"
if ($CommitHash) { Write-Host "Commit: $CommitHash" }
Write-Host "Report: $RunDirRel/report.md"

if ($FinalStatus -ne "passed") {
	exit 1
}
