<#
  viz-route.ps1 -- build a movement route for a unit in the Theater Viz scenario editor.

  Wraps the click choreography the editor needs, so callers do not have to remember it:

      select the unit  ->  press R  ->  click each point  ->  double-click the last one

  Why R and not the "Create Route" button: the button lives in the PROPERTIES panel, whose
  layout shifts with the selected element, so its coordinates are not stable. `R` is.

  IMPORTANT -- how the editor actually behaves (verified against v1.1.0-rc.2):
    * The FIRST click after R is the route's starting point, and the unit relocates to it.
      It is not a waypoint. Pass the unit's intended start position as the first point.
    * Every later click adds a waypoint.
    * A double-click places the final waypoint AND ends the route.
    * While route mode is active the PROPERTIES panel reads "Nothing selected" -- that is
      normal and does NOT mean the mode failed to start.

  Usage:
    viz-route.ps1 -AppPid 16860 -Points "1320,470;1450,560;1580,480"
    viz-route.ps1 -AppPid 16860 -Points "..." -UnitAt "1165,535" -Shot out.png

  Parameters:
    -AppPid   pid of the running Theater.Viz player (required)
    -Points   "x,y;x,y;..." in screen coordinates; at least 2. First = start, last = end.
    -UnitAt   click here first to select the unit. Omit if it is already selected.
    -SettleMs pause after each click (default 900) -- the editor drops clicks sent too fast.
    -Shot     write a PNG of the map area afterwards so the caller can verify the result.
#>
param(
  [Parameter(Mandatory=$true)][int]$AppPid,
  [Parameter(Mandatory=$true)][string]$Points,
  [string]$UnitAt,
  [int]$SettleMs = 900,
  [string]$Shot
)

$ErrorActionPreference = "Stop"
$winput = Join-Path $PSScriptRoot "winput.ps1"
if (-not (Test-Path $winput)) { throw "winput.ps1 not found next to this script ($winput)" }

function W { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $winput @args }

function Parse-Point($s) {
  $p = $s.Trim() -split '\s*,\s*'
  if ($p.Count -ne 2) { throw "bad point '$s' -- expected 'x,y'" }
  return @([int]$p[0], [int]$p[1])
}

$pts = @()
foreach ($chunk in ($Points -split ';')) {
  if ($chunk.Trim()) { $pts += ,(Parse-Point $chunk) }
}
if ($pts.Count -lt 2) { throw "need at least 2 points: the first is the route start, the last ends it" }

# The app ignores synthetic input unless its window is genuinely activated.
W wake $AppPid | Out-Null
$fg = (W fg) -replace '.*fg_pid=(\d+).*', '$1'
if ($fg -ne "$AppPid") { throw "Theater.Viz (pid $AppPid) is not frontmost (foreground is $fg) -- refusing to send blind input" }

if ($UnitAt) {
  $u = Parse-Point $UnitAt
  W click $u[0] $u[1] | Out-Null
  Start-Sleep -Milliseconds $SettleMs
}

# Start route mode. The panel going blank afterwards is expected, not a failure.
W key r | Out-Null
Start-Sleep -Milliseconds $SettleMs

for ($i = 0; $i -lt $pts.Count; $i++) {
  $p = $pts[$i]
  if ($i -eq $pts.Count - 1) {
    W dbl $p[0] $p[1] | Out-Null      # final waypoint + finish
  } else {
    W click $p[0] $p[1] | Out-Null
  }
  Start-Sleep -Milliseconds $SettleMs
}

if ($Shot) {
  # Map area of a 1920x1080 window; the left panel is not interesting here.
  W region $Shot 410 75 1510 920 $AppPid | Out-Null
}

$startTxt = "$($pts[0][0]),$($pts[0][1])"
$endTxt   = "$($pts[-1][0]),$($pts[-1][1])"
"route built: start $startTxt -> $($pts.Count - 2) waypoint(s) -> end $endTxt (double-clicked)"
if ($Shot) { "shot: $Shot" }
