<#
  viz-route-nodes.ps1 -- find a route's waypoints on screen and report their coordinates.

  Verification, not action. Everything else in this harness reports what it DID; this reports
  what the app actually ENDED UP WITH, which is the gap that makes editor work guesswork:
  after a click you cannot otherwise tell a route that failed to build from one that built and
  was then destroyed.

  How it works: a SELECTED route is drawn bright red, a colour nothing on this map uses. The
  waypoints are small pale discs sitting on that line (the final one is grey). So: find the red
  pixels, then find small round pale blobs touching them. Roads are pale too, which is why blobs
  are filtered by size and squareness -- a road is long and thin, a waypoint is a dot.

  THE ROUTE MUST BE SELECTED (click it, so it turns red). An unselected route is black and this
  script will report nothing -- that is a state, not an error, and it says so.

  Usage:
    viz-route-nodes.ps1 -AppPid 240
    viz-route-nodes.ps1 -AppPid 240 -Expect 3      # exit non-zero unless exactly 3 are found

  Output: one line per node, "x,y", left to right, then a count.
#>
param(
  [Parameter(Mandatory=$true)][int]$AppPid,
  [int]$Expect = -1,
  [int]$MapX = 410, [int]$MapY = 75, [int]$MapW = 1510, [int]$MapH = 920,
  [string]$Shot
)

$ErrorActionPreference = "Stop"
$winput = Join-Path $PSScriptRoot "winput.ps1"
function W { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $winput @args }

W wake $AppPid | Out-Null
$fg = (W fg) -replace '.*fg_pid=(\d+).*', '$1'
if ($fg -ne "$AppPid") { throw "Theater.Viz (pid $AppPid) is not frontmost (foreground is $fg)" }

$png = if ($Shot) { $Shot } else { Join-Path ([System.IO.Path]::GetTempPath()) "viz-nodes-$PID.png" }
W region $png $MapX $MapY $MapW $MapH $AppPid | Out-Null
if (-not (Test-Path $png)) { throw "capture refused" }

Add-Type -AssemblyName System.Drawing
$bmp  = [System.Drawing.Bitmap]::FromFile($png)
$rect = New-Object System.Drawing.Rectangle 0,0,$bmp.Width,$bmp.Height
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$stride = $data.Stride
$bytes  = New-Object byte[] ($stride * $bmp.Height)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$bmp.UnlockBits($data)
$W0 = $bmp.Width; $H0 = $bmp.Height
$bmp.Dispose()

# Coarse grid marking where the red route runs, so "is this blob on the route" is a cheap lookup.
$cell = 8
$gw = [int][math]::Ceiling($W0 / $cell); $gh = [int][math]::Ceiling($H0 / $cell)
$near = New-Object 'bool[]' ($gw * $gh)
$redCount = 0
for ($y = 0; $y -lt $H0; $y++) {
  $row = $y * $stride
  for ($x = 0; $x -lt $W0; $x++) {
    $i = $row + $x * 3
    $b = $bytes[$i]; $g = $bytes[$i+1]; $r = $bytes[$i+2]
    if ($r -gt 170 -and $g -lt 95 -and $b -lt 95) {
      $redCount++
      $cx = [int]($x / $cell); $cy = [int]($y / $cell)
      for ($dy = -2; $dy -le 2; $dy++) { for ($dx = -2; $dx -le 2; $dx++) {
        $nx = $cx + $dx; $ny = $cy + $dy
        if ($nx -ge 0 -and $ny -ge 0 -and $nx -lt $gw -and $ny -lt $gh) { $near[$ny * $gw + $nx] = $true }
      } }
    }
  }
}
if ($redCount -lt 50) {
  "no selected route found (nothing is drawn in route red)"
  "hint: click the route first -- an unselected route is black and cannot be measured this way"
  if ($Expect -ge 0) { exit 1 }
  exit 0
}

# Candidate node pixels: pale, and sitting on the route.
$cand = New-Object 'bool[]' ($W0 * $H0)
for ($y = 0; $y -lt $H0; $y++) {
  $row = $y * $stride
  $cy = [int]($y / $cell)
  for ($x = 0; $x -lt $W0; $x++) {
    if (-not $near[$cy * $gw + [int]($x / $cell)]) { continue }
    $i = $row + $x * 3
    $b = $bytes[$i]; $g = $bytes[$i+1]; $r = $bytes[$i+2]
    $pale = ($r -gt 243 -and $g -gt 243 -and $b -gt 243)
    $grey = ($r -gt 120 -and $r -lt 190 -and [math]::Abs($r-$g) -lt 14 -and [math]::Abs($g-$b) -lt 14)
    if ($pale -or $grey) { $cand[$y * $W0 + $x] = $true }
  }
}

# Cluster the candidates; keep the ones shaped like a dot rather than a stretch of road.
$seen = New-Object 'bool[]' ($W0 * $H0)
$nodes = New-Object System.Collections.ArrayList
[int[]]$dxs = @(1,-1,0,0)
[int[]]$dys = @(0,0,1,-1)
for ($y = 0; $y -lt $H0; $y++) {
  for ($x = 0; $x -lt $W0; $x++) {
    $idx = $y * $W0 + $x
    if (-not $cand[$idx] -or $seen[$idx]) { continue }
    # Two parallel int stacks rather than one stack of pairs: PowerShell unwraps arrays in
    # ways that turn arithmetic on the popped values into array concatenation.
    $sxs = New-Object 'System.Collections.Generic.Stack[int]'
    $sys = New-Object 'System.Collections.Generic.Stack[int]'
    $sxs.Push($x); $sys.Push($y); $seen[$idx] = $true
    [int]$n = 0; [int]$sumx = 0; [int]$sumy = 0
    [int]$minx = $x; [int]$maxx = $x; [int]$miny = $y; [int]$maxy = $y
    while ($sxs.Count -gt 0) {
      [int]$px = $sxs.Pop(); [int]$py = $sys.Pop()
      $n++; $sumx += $px; $sumy += $py
      if ($px -lt $minx) { $minx = $px }; if ($px -gt $maxx) { $maxx = $px }
      if ($py -lt $miny) { $miny = $py }; if ($py -gt $maxy) { $maxy = $py }
      if ($n -gt 4000) { continue }   # runaway blob: a road, not a node
      for ($k = 0; $k -lt 4; $k++) {
        [int]$qx = $px + $dxs[$k]; [int]$qy = $py + $dys[$k]
        if ($qx -lt 0 -or $qy -lt 0 -or $qx -ge $W0 -or $qy -ge $H0) { continue }
        $qi = $qy * $W0 + $qx
        if ($cand[$qi] -and -not $seen[$qi]) { $seen[$qi] = $true; $sxs.Push($qx); $sys.Push($qy) }
      }
    }
    $w = $maxx - $minx + 1; $h = $maxy - $miny + 1
    if ($n -ge 45 -and $n -le 260 -and $w -ge 8 -and $w -le 18 -and $h -ge 8 -and $h -le 18) {
      $ratio = [double]$w / [double]$h
      if ($ratio -gt 0.55 -and $ratio -lt 1.8) {
        # Parenthesise each element: in PowerShell "," binds tighter than "+", so
        # @(a + b, c + d) builds an array from (b, c) and then tries to add -- which fails
        # with a baffling op_Addition error on System.Object[].
        # A unit draws its own pale anchor dot, which sits on the route start and otherwise
        # looks exactly like a waypoint. Units are filled cyan, so reject any blob with cyan
        # nearby.
        [int]$bx = [int]($sumx / $n); [int]$by = [int]($sumy / $n)
        $onUnit = $false
        for ($vy = [math]::Max(0, $by - 26); $vy -le [math]::Min($H0 - 1, $by + 26) -and -not $onUnit; $vy++) {
          $vrow = $vy * $stride
          for ($vx = [math]::Max(0, $bx - 26); $vx -le [math]::Min($W0 - 1, $bx + 26); $vx++) {
            $vi = $vrow + $vx * 3
            if ($bytes[$vi] -gt 195 -and $bytes[$vi+1] -gt 165 -and $bytes[$vi+2] -lt 165) { $onUnit = $true; break }
          }
        }
        if (-not $onUnit) {
          $ncx = $bx + $MapX
          $ncy = $by + $MapY
          [void]$nodes.Add(@($ncx, $ncy))
        }
      }
    }
  }
}

$sorted = @($nodes | Sort-Object { $_[0] })
foreach ($nd in $sorted) { "$($nd[0]),$($nd[1])" }
"count: $($sorted.Count)"
if ($Shot) { "shot: $Shot" }

if ($Expect -ge 0 -and $sorted.Count -ne $Expect) {
  Write-Error "expected $Expect node(s), found $($sorted.Count)"
  exit 1
}
