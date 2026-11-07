param(
	# Labels of runs made by run_divergence.ps1 (test-logs/div/<label>/), in the order to show them.
	[Parameter(Mandatory = $true)][string[]]$Labels,
	[int]$Year = 6,
	[string]$OutFile = ""
)

# One compact table across many run sets: per label, environment, condition and player, the measures
# the review between sprints reads (docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md, section 10b). Medians
# unless said; "ok" is towns housed and fed with their founding families kept (the stand-in's
# off-the-ground judgment at the end of the run).
#   .\scripts\summarize_divergence.ps1 -Labels B0,S3b-as-S2,S3b-as-S3,S3b -OutFile docs/economic_foundations/summary.md

$ErrorActionPreference = "Stop"
$Here = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")).Path

function Get-Median([double[]]$Values) {
	if ($Values.Count -eq 0) { return 0 }
	$Sorted = @($Values | Sort-Object)
	return $Sorted[[int][Math]::Floor($Sorted.Count / 2)]
}

$Rows = @()
foreach ($Label in $Labels) {
	foreach ($File in Get-ChildItem -LiteralPath (Join-Path $Here "test-logs/div/$Label") -Filter "*.log") {
		foreach ($Line in [System.IO.File]::ReadLines($File.FullName)) {
			if (-not $Line.StartsWith("[DIV] TOWN ")) { continue }
			$Parts = $Line.Substring(11) -split " \| ", 7
			if ([int]($Parts[4] -replace "year ", "") -ne $Year) { continue }
			$Rows += [pscustomobject]@{ label = $Label; env = $Parts[0].Trim(); condition = $Parts[1].Trim(); policy = $Parts[2].Trim(); m = ($Parts[6] | ConvertFrom-Json) }
		}
	}
}
$Lines = @("| Run | Environment | Cond. | Player | Towns | ok | People | Hunger days | Cold days | Deaths (h/c) | Outside food | Stone made | Bricks made | Stone/brick homes | Tick ms |", "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
foreach ($Group in ($Rows | Group-Object { "$($_.label)|$($_.env)|$($_.condition)|$($_.policy)" })) {
	$T = @($Group.Group)
	$First = $T[0]
	$Ok = @($T | Where-Object { $_.m.off_the_ground }).Count
	$Stone = ($T | ForEach-Object { [double]$_.m.flows.stone_blocks.made } | Measure-Object -Sum).Sum / $T.Count
	$Bricks = ($T | ForEach-Object { [double]$_.m.flows.bricks.made } | Measure-Object -Sum).Sum / $T.Count
	$Homes = ($T | ForEach-Object { $mat = $_.m.materials; if ($mat) { [double]$mat.home_stone + [double]$mat.home_dressed_stone + [double]$mat.home_brick } else { 0 } } | Measure-Object -Sum).Sum / $T.Count
	$DeathsH = ($T | ForEach-Object { [int]$_.m.deaths_hunger } | Measure-Object -Sum).Sum
	$DeathsC = ($T | ForEach-Object { [int]$_.m.deaths_cold } | Measure-Object -Sum).Sum
	$Lines += "| {0} | {1} | {2} | {3} | {4} | {5} | {6:0} | {7:0} | {8:0} | {9}/{10} | {11:0.00} | {12:0} | {13:0} | {14:0.0} | {15:0.0} |" -f $First.label, $First.env, $First.condition, $First.policy, $T.Count, $Ok,
		(Get-Median @($T | ForEach-Object { [double]$_.m.people })), (Get-Median @($T | ForEach-Object { [double]$_.m.short_days })), (Get-Median @($T | ForEach-Object { [double]$_.m.fuel_short_days })),
		$DeathsH, $DeathsC, (Get-Median @($T | ForEach-Object { [double]$_.m.outside_food_share })), $Stone, $Bricks, $Homes, (Get-Median @($T | ForEach-Object { [double]$_.m.tick_ms_mean }))
}
$Lines | ForEach-Object { Write-Host $_ }
if ($OutFile -ne "") { Set-Content -LiteralPath $OutFile -Value $Lines -Encoding utf8 }
