param(
	# A name for this set of runs; logs go to test-logs/div/<Label>/.
	[Parameter(Mandatory = $true)][string]$Label,
	[string[]]$Environments = @("rocky_highland", "fertile_valley", "forested", "marginal", "balanced"),
	[string[]]$Conditions = @("ordinary", "stressed"),
	[string[]]$Policies = @("none"),
	[int]$Starts = 12,
	[int]$Years = 6,
	# Extra arguments for every run, e.g. "--meta=no_quarry_deposits".
	[string]$Extra = "",
	# The worktree to run in (a fixed commit for a baseline); defaults to this one.
	[string]$ProjectRoot = "",
	[int]$Parallel = 4,
	# Don't start another Godot process with less free memory than this.
	[int]$MinFreeMB = 3000,
	[string]$GodotBin = $env:GODOT_BIN
)

# Runs tests/sim/divergence_check.gd once per environment, condition and policy, at most $Parallel
# Godot processes at once (the owner's limit is four), waiting while free memory is low. Each run's
# log is written to a file (piping stalls Godot on Windows).
#   .\scripts\run_divergence.ps1 -Label B0
#   .\scripts\run_divergence.ps1 -Label S1b-off -Extra "--meta=no_quarry_deposits" -Starts 8
# Then: .\scripts\compare_divergence.ps1 -Base B0 -New S1b

$ErrorActionPreference = "Stop"
$Here = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")).Path
if ($ProjectRoot -eq "") { $ProjectRoot = $Here }
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = (Get-Content -LiteralPath (Join-Path $Here ".godot-exe")).Trim() }
$OutDir = Join-Path $Here "test-logs/div/$Label"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Commit = (& git -c safe.directory=* -C $ProjectRoot rev-parse --short HEAD)
Set-Content -LiteralPath (Join-Path $OutDir "run.txt") -Value @("label $Label", "commit $Commit", "root $ProjectRoot", "starts $Starts years $Years", "extra $Extra", "started $(Get-Date -Format s)") -Encoding utf8

$Jobs = New-Object System.Collections.Queue
foreach ($Condition in $Conditions) { foreach ($Policy in $Policies) { foreach ($Environment in $Environments) {
	$Jobs.Enqueue(@{ name = "${Environment}_${Condition}_${Policy}"; args = "--environments=$Environment --conditions=$Condition --policies=$Policy --starts=$Starts --years=$Years $Extra" })
} } }

function Get-FreeMB { [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024) }

$Running = @()
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
while ($Jobs.Count -gt 0 -or $Running.Count -gt 0) {
	while ($Jobs.Count -gt 0 -and $Running.Count -lt $Parallel -and (Get-FreeMB) -ge $MinFreeMB) {
		$Job = $Jobs.Dequeue()
		$Log = Join-Path $OutDir "$($Job.name).log"
		$Arguments = "--headless --path `"$ProjectRoot`" --script res://tests/sim/divergence_check.gd -- $($Job.args)"
		$Process = Start-Process -FilePath $GodotBin -ArgumentList $Arguments -WorkingDirectory $ProjectRoot -PassThru -NoNewWindow -RedirectStandardOutput $Log -RedirectStandardError "$Log.err"
		$null = $Process.Handle
		$Running += @{ job = $Job; process = $Process; started = Get-Date }
		Write-Host ("start  {0} (free {1} MB)" -f $Job.name, (Get-FreeMB))
	}
	Start-Sleep -Seconds 5
	$Still = @()
	foreach ($Run in $Running) {
		if (-not $Run.process.HasExited) { $Still += $Run; continue }
		Write-Host ("done   {0} exit {1} in {2:n0} s" -f $Run.job.name, $Run.process.ExitCode, ((Get-Date) - $Run.started).TotalSeconds)
	}
	$Running = $Still
}
Add-Content -LiteralPath (Join-Path $OutDir "run.txt") -Value ("finished $(Get-Date -Format s) after {0:n0} s" -f $Timer.Elapsed.TotalSeconds)
Write-Host ("All runs finished in {0:n0} s: {1}" -f $Timer.Elapsed.TotalSeconds, $OutDir)
