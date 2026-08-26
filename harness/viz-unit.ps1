<#
  viz-unit.ps1 -- place a unit in the Theater Viz scenario editor, through the real UI.

  Two input paths, because an e2e pass should be able to exercise either:

    -Via hotkey   press Space                      (default; deterministic)
    -Via button   click the Unit tool, click the map

  The button path is the flaky one and the script compensates. The Unit tool is a TOGGLE
  whose state cannot be read from the screen: its amber highlight means "last used tool",
  not "armed", and it never clears -- not by clicking it, not by Esc. So a single click may
  arm it or disarm it, with no way to tell in advance. The script detects whether a unit
  actually appeared and clicks once more if it did not.

  A placed unit always appears at the CENTRE of the map viewport, never where you clicked,
  and it arrives selected -- so it is ready for viz-route.ps1 straight away. It is also a
  COPY of the last selected unit (side, size, type), so place a red one by selecting a red
  one first. Use -MoveTo to drag it off the centre; otherwise the next unit lands on top of
  it and the two are indistinguishable.

  Usage:
    viz-unit.ps1 -AppPid 16860
    viz-unit.ps1 -AppPid 16860 -Via button -MoveTo "800,400"

  Exit: non-zero if no unit appeared, so a test run fails loudly instead of silently.
#>
param(
  [Parameter(Mandatory=$true)][int]$AppPid,
  [ValidateSet("hotkey","button")][string]$Via = "hotkey",
  [string]$MoveTo,
  [int]$SettleMs = 900,
  [string]$Shot
)

$ErrorActionPreference = "Stop"
$winput = Join-Path $PSScriptRoot "winput.ps1"
if (-not (Test-Path $winput)) { throw "winput.ps1 not found next to this script ($winput)" }

function W { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $winput @args }

# Centre of the map viewport in a 1920x1080 window -- where a new unit always lands.
$CentreX = 1165
$CentreY = 535

$tmp = [System.IO.Path]::GetTempPath()
function Snap($tag) {
  $f = Join-Path $tmp "viz-unit-$tag-$PID.png"
  W region $f ($CentreX - 60) ($CentreY - 60) 120 120 $AppPid | Out-Null
  if (-not (Test-Path $f)) { throw "capture refused -- Theater.Viz is not frontmost" }
  return $f
}
function Same($a, $b) {
  (Get-FileHash $a -Algorithm MD5).Hash -eq (Get-FileHash $b -Algorithm MD5).Hash
}

W wake $AppPid | Out-Null
$fg = (W fg) -replace '.*fg_pid=(\d+).*', '$1'
if ($fg -ne "$AppPid") { throw "Theater.Viz (pid $AppPid) is not frontmost (foreground is $fg) -- refusing to send blind input" }

$before = Snap "before"

if ($Via -eq "hotkey") {
  W key space | Out-Null
  Start-Sleep -Milliseconds $SettleMs
} else {
  # First attempt: the toggle may have been left armed or disarmed by whatever ran before.
  W click 57 196 | Out-Null; Start-Sleep -Milliseconds $SettleMs
  W click $CentreX $CentreY | Out-Null; Start-Sleep -Milliseconds $SettleMs
  if (Same $before (Snap "try1")) {
    # Nothing appeared: that click disarmed the tool instead of arming it. Arm and retry.
    W click 57 196 | Out-Null; Start-Sleep -Milliseconds $SettleMs
    W click $CentreX $CentreY | Out-Null; Start-Sleep -Milliseconds $SettleMs
  }
}

$after = Snap "after"
if (Same $before $after) {
  Write-Error "no unit appeared at the map centre via '$Via' -- nothing placed"
  exit 1
}

$where = "$CentreX,$CentreY"
if ($MoveTo) {
  $p = $MoveTo.Trim() -split '\s*,\s*'
  if ($p.Count -ne 2) { throw "bad -MoveTo '$MoveTo' -- expected 'x,y'" }
  W drag $CentreX $CentreY ([int]$p[0]) ([int]$p[1]) 25 | Out-Null
  Start-Sleep -Milliseconds $SettleMs
  $where = "$([int]$p[0]),$([int]$p[1])"
}

if ($Shot) { W region $Shot 410 75 1510 920 $AppPid | Out-Null }

"unit placed via $Via at $where (selected)"
if ($Shot) { "shot: $Shot" }
