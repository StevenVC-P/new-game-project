param(
	[string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$ProjectFile = Join-Path $ProjectRoot "project.godot"
$GodotArgs = @("--headless", "--import", "--path", $ProjectRoot)

function Stop-WithMessage {
	param(
		[string]$Message,
		[int]$Code = 1
	)

	Write-Host "ERROR: $Message" -ForegroundColor Red
	exit $Code
}

function Format-CommandPart {
	param(
		[string]$Part
	)

	if ($Part -match '\s') {
		return '"' + ($Part -replace '"', '\"') + '"'
	}

	return $Part
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

if (-not (Test-Path -LiteralPath $ProjectFile)) {
	Stop-WithMessage "project.godot was not found at: $ProjectFile"
}

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
	$Command = Get-Command godot -ErrorAction SilentlyContinue
	if ($Command) {
		$GodotBin = $Command.Source
	}
}

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
	Stop-WithMessage "Godot executable not configured. Set GODOT_BIN to the full Godot executable path or put godot on PATH."
}

$ResolvedGodotBin = ""
try {
	$ResolvedGodotBin = (Resolve-Path -LiteralPath $GodotBin).Path
} catch {
	Stop-WithMessage "Godot executable was not found at: $GodotBin"
}

$CommandDisplay = (@($ResolvedGodotBin) + $GodotArgs | ForEach-Object { Format-CommandPart $_ }) -join " "

Write-Host "Godot executable: $ResolvedGodotBin"
Write-Host "Project path: $ProjectRoot"
Write-Host "Command: $CommandDisplay"
Write-Host "Validation mode: headless editor import pass; does not run the main scene."

$ArgumentString = ($GodotArgs | ForEach-Object { Format-CommandPart $_ }) -join " "

$Timer = [System.Diagnostics.Stopwatch]::StartNew()
$StdOutPath = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-validate-{0}.out.log" -f ([guid]::NewGuid().ToString("N")))
$StdErrPath = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-validate-{0}.err.log" -f ([guid]::NewGuid().ToString("N")))
$Process = Start-Process -FilePath $ResolvedGodotBin -ArgumentList $ArgumentString -WorkingDirectory $ProjectRoot -Wait -PassThru -NoNewWindow -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath
$Timer.Stop()

$ExitCode = $Process.ExitCode
$StdOut = if (Test-Path -LiteralPath $StdOutPath) { [System.IO.File]::ReadAllText($StdOutPath) } else { "" }
$StdErr = if (Test-Path -LiteralPath $StdErrPath) { [System.IO.File]::ReadAllText($StdErrPath) } else { "" }
Remove-Item -LiteralPath $StdOutPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $StdErrPath -Force -ErrorAction SilentlyContinue
$CombinedOutput = ($StdOut, $StdErr) -join "`n"
if (-not [string]::IsNullOrWhiteSpace($StdOut)) {
	Write-Host $StdOut.TrimEnd()
}
if (-not [string]::IsNullOrWhiteSpace($StdErr)) {
	Write-Host $StdErr.TrimEnd()
}

Write-Host ("Exit code: {0}" -f $ExitCode)
Write-Host ("Elapsed time: {0:n2}s" -f $Timer.Elapsed.TotalSeconds)

if ($ExitCode -ne 0) {
	Stop-WithMessage "Godot validation failed with exit code $ExitCode." $ExitCode
}

$SeriousLogLines = @(Get-SeriousGodotLogLines $CombinedOutput)
if ($SeriousLogLines.Count -gt 0) {
	Write-Host "Serious Godot validation log lines:" -ForegroundColor Red
	foreach ($Line in $SeriousLogLines) {
		Write-Host $Line -ForegroundColor Red
	}
	Stop-WithMessage "Godot validation log contained serious errors even though the process exited successfully."
}

Write-Host "Godot validation completed successfully."
