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

# Start-Process with -Wait and -PassThru provides a reliable process exit code
# on Windows. Arguments are quoted before joining so project paths with spaces
# remain single command-line arguments.
$ArgumentString = ($GodotArgs | ForEach-Object { Format-CommandPart $_ }) -join " "

$Timer = [System.Diagnostics.Stopwatch]::StartNew()
$Process = Start-Process -FilePath $ResolvedGodotBin -ArgumentList $ArgumentString -WorkingDirectory $ProjectRoot -Wait -PassThru -NoNewWindow
$Timer.Stop()

$ExitCode = $Process.ExitCode

Write-Host ("Exit code: {0}" -f $ExitCode)
Write-Host ("Elapsed time: {0:n2}s" -f $Timer.Elapsed.TotalSeconds)

if ($ExitCode -ne 0) {
	Stop-WithMessage "Godot validation failed with exit code $ExitCode." $ExitCode
}

Write-Host "Godot validation completed successfully."
