param(
	[string]$GodotBin = $env:GODOT_BIN,
	# Wildcard on test file names, e.g. "shared_land*".
	[string]$Filter = "*",
	[int]$TimeoutSeconds = 900,
	[int]$Parallel = 4,
	[string]$OutFile = ""
)

# Runs every rules test in tests/ (not tests/sim, tests/visual or benchmarks) headless, at most
# $Parallel at a time (the owner's limit is four Godot processes), and writes one line per script.
# Exits 1 if any test failed. A test's own log goes to a file beside the summary, never a pipe:
# piping Godot's household log stalls it on Windows.
#   $env:GODOT_BIN = (Get-Content .godot-exe).Trim(); .\scripts\run_tests.ps1
# Known flaky (docs/HANDOFF.md): world_map_flow_validation, rerun once before it counts as failed.

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")).Path
if ([string]::IsNullOrWhiteSpace($GodotBin)) {
	$ExeFile = Join-Path $ProjectRoot ".godot-exe"
	if (Test-Path -LiteralPath $ExeFile) { $GodotBin = (Get-Content -LiteralPath $ExeFile).Trim() }
}
if ([string]::IsNullOrWhiteSpace($GodotBin) -or -not (Test-Path -LiteralPath $GodotBin)) {
	Write-Host "ERROR: set GODOT_BIN or .godot-exe to the Godot executable." -ForegroundColor Red
	exit 1
}
$Flaky = @("world_map_flow_validation.gd")
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogDir = Join-Path $ProjectRoot "test-logs/$Stamp"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
if ($OutFile -eq "") { $OutFile = Join-Path $LogDir "summary.txt" }

# A RefCounted test can't be run by --script; it has a SceneTree runner of its own.
$Tests = @(Get-ChildItem -Path (Join-Path $ProjectRoot "tests") -Filter "*.gd" -File | Where-Object {
	$_.Name -like "$Filter.gd" -and (Get-Content -LiteralPath $_.FullName -TotalCount 1) -match "^extends SceneTree"
} | Sort-Object Name)

function Start-Test([System.IO.FileInfo]$Test, [int]$Attempt) {
	$Log = Join-Path $LogDir ("{0}.{1}.log" -f $Test.BaseName, $Attempt)
	$Arguments = "--headless --path `"$ProjectRoot`" --script res://tests/$($Test.Name)"
	$Process = Start-Process -FilePath $GodotBin -ArgumentList $Arguments -WorkingDirectory $ProjectRoot -PassThru -NoNewWindow -RedirectStandardOutput $Log -RedirectStandardError "$Log.err"
	# Without the handle taken now, ExitCode reads as null once the process has exited.
	$null = $Process.Handle
	return @{ test = $Test; process = $Process; log = $Log; attempt = $Attempt; started = Get-Date }
}

$Queue = New-Object System.Collections.Queue
foreach ($Test in $Tests) { $Queue.Enqueue(@{ test = $Test; attempt = 1 }) }
$Running = @()
$Results = @()
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
while ($Queue.Count -gt 0 -or $Running.Count -gt 0) {
	while ($Queue.Count -gt 0 -and $Running.Count -lt $Parallel) {
		$Next = $Queue.Dequeue()
		$Running += Start-Test $Next.test $Next.attempt
	}
	Start-Sleep -Milliseconds 500
	$StillRunning = @()
	foreach ($Run in $Running) {
		$Seconds = ((Get-Date) - $Run.started).TotalSeconds
		if (-not $Run.process.HasExited -and $Seconds -lt $TimeoutSeconds) {
			$StillRunning += $Run
			continue
		}
		$Status = "PASS"
		if (-not $Run.process.HasExited) {
			Stop-Process -Id $Run.process.Id -Force -ErrorAction SilentlyContinue
			$Status = "TIMEOUT"
		} elseif ($Run.process.ExitCode -ne 0) {
			$Status = "FAIL"
		}
		if ($Status -ne "PASS" -and $Run.attempt -eq 1 -and $Flaky -contains $Run.test.Name) {
			$Queue.Enqueue(@{ test = $Run.test; attempt = 2 })
			continue
		}
		$Results += ("{0,-8} {1,-52} {2,6:n0}s  {3}" -f $Status, $Run.test.Name, $Seconds, $Run.log)
		Write-Host $Results[-1]
	}
	$Running = $StillRunning
}
$Failed = @($Results | Where-Object { -not $_.StartsWith("PASS") }).Count
$Summary = @("Ran $($Results.Count) tests in {0:n0}s; $Failed failed." -f $Timer.Elapsed.TotalSeconds) + ($Results | Sort-Object)
Set-Content -LiteralPath $OutFile -Value $Summary -Encoding utf8
Write-Host $Summary[0]
Write-Host "Summary: $OutFile"
exit ([int]($Failed -gt 0))
