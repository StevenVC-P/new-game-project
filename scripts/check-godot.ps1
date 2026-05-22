param(
	[string]$GodotExe = $env:GODOT_EXE
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$ProjectFile = Join-Path $ProjectRoot "project.godot"
$LocalGodotFile = Join-Path $ProjectRoot ".godot-exe"

function Stop-WithMessage {
	param(
		[string]$Message,
		[int]$Code = 1
	)

	Write-Host "ERROR: $Message" -ForegroundColor Red
	exit $Code
}

if (Test-Path -LiteralPath $LocalGodotFile) {
    $GodotExe = (Get-Content -LiteralPath $LocalGodotFile -TotalCount 1).Trim()
}

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	Stop-WithMessage "Godot executable not configured. Set GODOT_EXE, pass -GodotExe, or create a .godot-exe file containing the full path to Godot.exe."
}

$ResolvedGodotExe = ""
try {
	$ResolvedGodotExe = (Resolve-Path -LiteralPath $GodotExe).Path
} catch {
	Stop-WithMessage "Godot executable was not found at: $GodotExe"
}

if (-not (Test-Path -LiteralPath $ProjectFile)) {
	Stop-WithMessage "project.godot was not found at: $ProjectFile"
}

Write-Host "Using Godot: $ResolvedGodotExe"
Write-Host "Checking project: $ProjectRoot"

& $ResolvedGodotExe --headless --editor --quit --path $ProjectRoot
$ExitCode = $LASTEXITCODE

if ($ExitCode -ne 0) {
	Stop-WithMessage "Godot validation failed with exit code $ExitCode." $ExitCode
}

Write-Host "Godot validation completed successfully."
