param(
	# Labels of runs made by run_divergence.ps1 (test-logs/div/<label>/).
	[Parameter(Mandatory = $true)][string]$Base,
	[string]$New = "",
	[int]$Year = 6,
	# Write the tables here as well as to the screen.
	[string]$OutFile = ""
)

# Reads the "[DIV] TOWN" lines of one or two sets of divergence runs and prints markdown tables per
# environment and condition: survival, people, shortages, specialisation, woods and goods made, as
# median [min-max] over the towns, base beside new. Also counts invariant violations and repeats
# that differed.
#   .\scripts\compare_divergence.ps1 -Base B0 -New S1b -OutFile docs/economic_foundations/S1b_tables.md

$ErrorActionPreference = "Stop"
$Here = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")).Path

function Read-Towns([string]$Label) {
	$Dir = Join-Path $Here "test-logs/div/$Label"
	if (-not (Test-Path -LiteralPath $Dir)) { throw "No runs labelled $Label in $Dir" }
	$Towns = @()
	$Problems = @()
	foreach ($File in Get-ChildItem -LiteralPath $Dir -Filter "*.log") {
		foreach ($Line in [System.IO.File]::ReadLines($File.FullName)) {
			if ($Line.StartsWith("[DIV] TOWN ")) {
				$Parts = $Line.Substring(11) -split " \| ", 7
				$Towns += [pscustomobject]@{
					env = $Parts[0].Trim(); condition = $Parts[1].Trim(); policy = $Parts[2].Trim()
					start = [int]($Parts[3] -replace "start ", ""); year = [int]($Parts[4] -replace "year ", ""); seed = $Parts[5] -replace "seed ", ""
					m = ($Parts[6] | ConvertFrom-Json)
				}
			} elseif ($Line.StartsWith("[DIV] INV ") -or ($Line.StartsWith("[DIV] REPEAT ") -and -not $Line.EndsWith("identical"))) {
				$Problems += $Line
			}
		}
	}
	return @{ towns = $Towns; problems = $Problems }
}

# "median [min-max]"; $Format is a number format such as "0.#".
function Get-Spread([double[]]$Values, [string]$Format = "0.#") {
	if ($Values.Count -eq 0) { return "-" }
	$Sorted = @($Values | Sort-Object)
	return ("{0:$Format} [{1:$Format}-{2:$Format}]" -f $Sorted[[int][Math]::Floor($Sorted.Count / 2)], $Sorted[0], $Sorted[-1])
}

function Get-Summary($Towns) {
	$N = [Math]::Max(1, @($Towns).Count)
	$Made = @{}
	$Holdings = @{}
	foreach ($Town in $Towns) {
		foreach ($Good in $Town.m.flows.PSObject.Properties) {
			$Value = $Good.Value.PSObject.Properties["made"]
			if ($Value) { $Made[$Good.Name] = [double]$Made[$Good.Name] + [double]$Value.Value }
		}
		foreach ($Trade in $Town.m.trades.PSObject.Properties) { $Holdings[$Trade.Name] = [double]$Holdings[$Trade.Name] + [double]$Trade.Value }
	}
	$Rows = [ordered]@{}
	$Rows["towns"] = "$(@($Towns).Count)"
	$Rows["alive / kept founders / off the ground"] = "{0} / {1} / {2}" -f @($Towns | Where-Object { $_.m.households -gt 0 }).Count, @($Towns | Where-Object { $_.m.households -ge 4 }).Count, @($Towns | Where-Object { $_.m.off_the_ground }).Count
	$Rows["people"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.people })
	$Rows["departed households"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.departed })
	$Rows["food shortage days"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.short_days })
	$Rows["first-year shortage days"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.first_year_short_days })
	$Rows["days hearths went short (S3)"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.fuel_short_days })
	$Rows["firewood burned (S3)"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.fuel_burned })
	$Rows["tools-out days"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.tools_out_days })
	$Rows["food days in store"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.food_days })
	$Rows["share of holdings outside food"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.outside_food_share }) "0.00"
	$Rows["trade diversity"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.trade_diversity }) "0.00"
	$Rows["woods left (share of start)"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.woods_now / [Math]::Max(1, [double]$_.m.woods_start) }) "0.00"
	$Rows["made per town"] = (($Made.Keys | Sort-Object | ForEach-Object { "{0} {1:0}" -f $_, ($Made[$_] / $N) }) -join ", ")
	$Rows["holdings per town"] = (($Holdings.Keys | Sort-Object | ForEach-Object { "{0} {1:0.0}" -f $_, ($Holdings[$_] / $N) }) -join ", ")
	$Rows["succeeding / failing (test plan 10b)"] = "{0} / {1}" -f @($Towns | Where-Object { $_.m.success }).Count, @($Towns | Where-Object { $_.m.failure }).Count
	$Rows["town tick ms (mean)"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.tick_ms_mean }) "0.0"
	$Rows["ms per day (mean)"] = Get-Spread @($Towns | ForEach-Object { [double]$_.m.day_ms_mean }) "0.0"
	return $Rows
}

$Sets = @{ $Base = Read-Towns $Base }
if ($New -ne "") { $Sets[$New] = Read-Towns $New }
$Labels = @($Base) + @(if ($New -ne "") { $New })
$Lines = @()
foreach ($Label in $Labels) {
	$Lines += "**$Label**: $(@($Sets[$Label].towns).Count) town snapshots; problems: $(@($Sets[$Label].problems).Count)"
	foreach ($Problem in $Sets[$Label].problems | Select-Object -First 10) { $Lines += "- $Problem" }
}
$Groups = $Sets[$Base].towns | Where-Object { $_.year -eq $Year } | ForEach-Object { "$($_.env)|$($_.condition)|$($_.policy)" } | Sort-Object -Unique
foreach ($Group in $Groups) {
	$Env, $Condition, $Policy = $Group -split "\|"
	$Lines += ""
	$Lines += "### $Env, $Condition, $Policy, year $Year"
	$Lines += ""
	$Summaries = @{}
	foreach ($Label in $Labels) {
		$Summaries[$Label] = Get-Summary @($Sets[$Label].towns | Where-Object { $_.env -eq $Env -and $_.condition -eq $Condition -and $_.policy -eq $Policy -and $_.year -eq $Year })
	}
	$Lines += "| Measure | " + ($Labels -join " | ") + " |"
	$Lines += "|---|" + (($Labels | ForEach-Object { "---" }) -join "|") + "|"
	foreach ($Key in $Summaries[$Base].Keys) {
		$Lines += "| $Key | " + (($Labels | ForEach-Object { $Summaries[$_][$Key] }) -join " | ") + " |"
	}
}
$Lines | ForEach-Object { Write-Host $_ }
if ($OutFile -ne "") { Set-Content -LiteralPath $OutFile -Value $Lines -Encoding utf8 }
