param(
	[string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$ProjectFile = Join-Path $ProjectRoot "project.godot"

function Stop-WithMessage {
	param(
		[string]$Message,
		[int]$Code = 1
	)

	Write-Host "ERROR: $Message" -ForegroundColor Red
	exit $Code
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

Write-Host "Using Godot: $ResolvedGodotBin"
Write-Host "Checking project: $ProjectRoot"

& $ResolvedGodotBin --headless --editor --quit --path $ProjectRoot
$ExitCode = $LASTEXITCODE

if ($ExitCode -ne 0) {
	Stop-WithMessage "Godot validation failed with exit code $ExitCode." $ExitCode
}

Write-Host "Godot validation completed successfully."
