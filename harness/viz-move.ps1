<#
  viz-move.ps1 -- put a unit at an exact MGRS coordinate.

  The PROPERTIES panel's MGRS field is editable, and typing into it is the only way to place a
  unit precisely: at typical zoom one pixel is about 1.3 m, so dragging cannot hit a given
  10-digit grid reference. Use this whenever a case says "the unit is at <MGRS>".

      click the MGRS field -> ctrl+a -> delete -> type the coordinate -> Enter

  The unit must be SELECTED first, so the panel is showing UNIT properties. Pass -UnitAt to
  click it, or leave it out if it is already selected (a freshly placed unit is).

  Usage:
    viz-move.ps1 -AppPid 240 -Mgrs "36U UA 03889 93291"
    viz-move.ps1 -AppPid 240 -Mgrs "36U UA 03889 93291" -UnitAt "1165,540" -Verify out.png

  Parameters:
    -AppPid   pid of the running Theater.Viz player (required)
    -Mgrs     target grid reference, e.g. "36U UA 03889 93291" (required)
    -UnitAt   "x,y" of the unit to select first; omit if it is already selected
    -FieldAt  screen position of the MGRS input (default "204,814" -- where it sits when the
              panel is showing a selected UNIT; it moves with the panel's contents)
    -Verify   write a PNG crop of the MGRS field after committing, so the caller can read back
              the digits it actually holds
    -SettleMs pause between steps (default 900)

  Exit: non-zero if the field's contents did not change at all, which is what a missed click on
  the field looks like -- the typing goes nowhere and the unit silently stays put.

  This script cannot read text, so it proves the field CHANGED, not that it holds the right
  digits. Use -Verify and look at the crop when the exact value matters.
#>
param(
  [Parameter(Mandatory=$true)][int]$AppPid,
  [Parameter(Mandatory=$true)][string]$Mgrs,
  [string]$UnitAt,
  [string]$FieldAt = "204,814",
  [string]$Verify,
  [int]$SettleMs = 900
)

$ErrorActionPreference = "Stop"
$winput = Join-Path $PSScriptRoot "winput.ps1"
if (-not (Test-Path $winput)) { throw "winput.ps1 not found next to this script ($winput)" }

function W { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $winput @args }
function Pt($s, $what) {
  $p = $s.Trim() -split '\s*,\s*'
  if ($p.Count -ne 2) { throw "bad $what '$s' -- expected 'x,y'" }
  return @([int]$p[0], [int]$p[1])
}

$f = Pt $FieldAt "-FieldAt"
$tmp = [System.IO.Path]::GetTempPath()
function SnapField($tag) {
  $out = Join-Path $tmp "viz-move-$tag-$PID.png"
  W region $out ($f[0] - 194) ($f[1] - 32) 390 40 $AppPid | Out-Null
  if (-not (Test-Path $out)) { throw "capture refused -- Theater.Viz is not frontmost" }
  return $out
}
function Same($a, $b) { (Get-FileHash $a -Algorithm MD5).Hash -eq (Get-FileHash $b -Algorithm MD5).Hash }

W wake $AppPid | Out-Null
$fg = (W fg) -replace '.*fg_pid=(\d+).*', '$1'
if ($fg -ne "$AppPid") { throw "Theater.Viz (pid $AppPid) is not frontmost (foreground is $fg) -- refusing to send blind input" }

if ($UnitAt) {
  $u = Pt $UnitAt "-UnitAt"
  W click $u[0] $u[1] | Out-Null
  Start-Sleep -Milliseconds $SettleMs
}

$before = SnapField "before"

W click $f[0] $f[1] | Out-Null;      Start-Sleep -Milliseconds $SettleMs
W chord "ctrl+a"    | Out-Null;      Start-Sleep -Milliseconds 200
W key delete        | Out-Null;      Start-Sleep -Milliseconds 200
W type $Mgrs        | Out-Null;      Start-Sleep -Milliseconds $SettleMs
W key enter         | Out-Null;      Start-Sleep -Milliseconds $SettleMs

$after = SnapField "after"
if (Same $before $after) {
  Write-Error "MGRS field is unchanged -- the click at $FieldAt probably missed it, so nothing was typed and the unit did not move"
  exit 1
}

if ($Verify) { W region $Verify ($f[0] - 194) ($f[1] - 32) 390 40 $AppPid | Out-Null }

"moved to $Mgrs"
if ($Verify) { "verify crop: $Verify (read it to confirm the digits)" }
