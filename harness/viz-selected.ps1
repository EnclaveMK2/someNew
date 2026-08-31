<#
  viz-selected.ps1 -- report WHAT is currently selected in the scenario editor.

  Four states are easy to confuse and impossible to tell apart from a map screenshot, yet they
  decide what the next keystroke does. Pressing Delete removes a unit, a whole route, or one
  waypoint depending purely on this, so a case that acts without checking is guessing:

      nothing | unit | route | waypoint

  It reads the PROPERTIES panel, not the map, and needs no OCR. Two bands are enough:

    type band  (10,430 200x24)   the word under PROPERTIES.
                                 "Nothing selected..." is a wrapped sentence and fills it (~187);
                                 "UNIT" is 4 letters (~27); "ROUTE" is 5 (~40).
    coord band (10,740 390x140)  the COORDINATES section. Absent for a route (~368, which is
                                 just the Simulate button below it); present for a unit (~784)
                                 and for a waypoint (~734).

  So: a route and a waypoint share a panel type but differ by COORDINATES; a unit and a waypoint
  both have COORDINATES but differ by the type word.

  Usage:
    viz-selected.ps1 -AppPid 22672
    viz-selected.ps1 -AppPid 22672 -Expect waypoint     # exit non-zero on any other state

  Thresholds were measured on v1.1.0-rc.2 at 1920x1080. If the panel layout changes they must be
  re-measured -- run with -Counts to see the raw numbers.
#>
param(
  [Parameter(Mandatory=$true)][int]$AppPid,
  [ValidateSet("nothing","unit","route","waypoint")][string]$Expect,
  [switch]$Counts
)

$ErrorActionPreference = "Stop"
$winput = Join-Path $PSScriptRoot "winput.ps1"
if (-not (Test-Path $winput)) { throw "winput.ps1 not found next to this script ($winput)" }
Add-Type -AssemblyName System.Drawing

function W { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $winput @args }

W wake $AppPid | Out-Null
$fg = (W fg) -replace '.*fg_pid=(\d+).*', '$1'
if ($fg -ne "$AppPid") { throw "Theater.Viz (pid $AppPid) is not frontmost (foreground is $fg)" }

# Capture both bands first, then measure. Doing the capture through one call per band keeps the
# guard meaningful: a refused capture writes no file and is caught here rather than counted as 0.
$tmp = [System.IO.Path]::GetTempPath()
function Grab($name, $x, $y, $w, $h) {
  $f = Join-Path $tmp "viz-selected-$name-$PID.png"
  if (Test-Path $f) { Remove-Item $f -Force }
  W region $f $x $y $w $h $AppPid | Out-Null
  if (-not (Test-Path $f)) { throw "capture refused -- Theater.Viz is not frontmost" }
  return $f
}
function Light($file) {
  $b = [System.Drawing.Bitmap]::FromFile($file)
  $n = 0
  for ($y = 0; $y -lt $b.Height; $y++) {
    for ($x = 0; $x -lt $b.Width; $x++) {
      $p = $b.GetPixel($x, $y)
      if ($p.R -gt 120 -and $p.G -gt 120 -and $p.B -gt 120) { $n++ }
    }
  }
  $b.Dispose()
  Remove-Item $file -Force -ErrorAction SilentlyContinue
  return $n
}

$typeFile  = Grab "type"  10 430 200 24
$coordFile = Grab "coord" 10 740 390 140
$type  = Light $typeFile
$coord = Light $coordFile

# Measured: nothing 187/0, unit 27/784, route 40/368, waypoint 40/734.
if     ($type  -gt 100) { $state = "nothing" }
elseif ($type  -lt 34)  { $state = "unit" }
elseif ($coord -lt 500) { $state = "route" }
else                    { $state = "waypoint" }

if ($Counts) { "type=$type coord=$coord" }
$state

if ($Expect -and $state -ne $Expect) {
  Write-Error "expected '$Expect' to be selected, but it is '$state'"
  exit 1
}
