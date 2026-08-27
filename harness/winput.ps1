<#
  winput.ps1 — Win32 SendInput harness for driving the Theater Viz desktop app.
  DPI-aware (1:1 clicks). Used by the e2e worker subagents.

  Commands:
    launch [args]                       start the installed app, prints pid
    pid                                 print the running app pid, or "none"
    fg                                  print the pid that currently owns the foreground window
    wake  <pid>                         minimize+restore to force real activation
    shot  <png> [pid]                   full-screen capture; with pid, REFUSES unless that pid is foreground
    region <png> <x> <y> <w> <h> [pid]  cropped capture; same refusal guard
    click <x> <y> / dbl / move <x> <y>
    pick  <x> <y> [hoverMs]             hover-then-click; REQUIRED for left-panel controls
    drag  <x1> <y1> <x2> <y2> [steps]   press, move in [steps] increments (default 20), release
    type  "<text>"                      unicode typing
    key   <enter|tab|esc|backspace|delete|space|home|end|arrows|A-Z|VK-number>
    chord <ctrl|shift|alt|win>+...+<key>   e.g. ctrl+a to select a field's contents
    close <pid>

  The [pid] guard exists because captures are taken from the SCREEN: if another window steals
  focus between calls, an unguarded capture silently returns the wrong pixels. With the guard,
  the harness fails loudly instead of producing false evidence.
#>
param([Parameter(Mandatory=$true)][string]$cmd,[string]$a1,[string]$a2,[string]$a3,[string]$a4,[string]$a5,[string]$a6)

Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @"
using System;using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int n);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [StructLayout(LayoutKind.Sequential)] public struct MI { public int dx;public int dy;public uint d;public uint f;public uint t;public IntPtr e; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public MI mi; }
  [DllImport("user32.dll")] public static extern uint SendInput(uint n,INPUT[] p,int cb);
  [StructLayout(LayoutKind.Sequential)] public struct KB { public ushort vk;public ushort sc;public uint f;public uint t;public IntPtr e; }
  [StructLayout(LayoutKind.Sequential)] public struct KINPUT { public uint type; public KB ki; public int p0; public int p1; }
  [DllImport("user32.dll")] public static extern uint SendInput(uint n,KINPUT[] p,int cb);
  public static void Click(int x,int y){ SetCursorPos(x,y);
    INPUT[] i=new INPUT[2]; i[0].type=0; i[0].mi.f=0x0002; i[1].type=0; i[1].mi.f=0x0004;
    SendInput(2,i,Marshal.SizeOf(typeof(INPUT))); }
  // Press/release as separate events so a drag can hold the button across intermediate moves.
  // Unity ignores a teleporting drag: it needs real motion between down and up, hence Drag steps.
  public static void Down(int x,int y){ SetCursorPos(x,y);
    INPUT[] i=new INPUT[1]; i[0].type=0; i[0].mi.f=0x0002;
    SendInput(1,i,Marshal.SizeOf(typeof(INPUT))); }
  public static void Up(int x,int y){ SetCursorPos(x,y);
    INPUT[] i=new INPUT[1]; i[0].type=0; i[0].mi.f=0x0004;
    SendInput(1,i,Marshal.SizeOf(typeof(INPUT))); }
  public static void Drag(int x1,int y1,int x2,int y2,int steps,int pauseMs){
    SetCursorPos(x1,y1); System.Threading.Thread.Sleep(pauseMs);
    Down(x1,y1); System.Threading.Thread.Sleep(pauseMs);
    for(int s=1;s<=steps;s++){
      SetCursorPos(x1+(x2-x1)*s/steps, y1+(y2-y1)*s/steps);
      System.Threading.Thread.Sleep(pauseMs); }
    Up(x2,y2); }
  // Delete/Insert/Home/End/PageUp/PageDown/arrows are EXTENDED keys: without
  // KEYEVENTF_EXTENDEDKEY (0x0001) they arrive as their numpad twins and an app that listens
  // for the real key never sees it. Costs nothing to set for the keys that need it.
  static bool Ext(ushort vk){
    return vk==0x2D||vk==0x2E||vk==0x24||vk==0x23||vk==0x21||vk==0x22
        || vk==0x25||vk==0x26||vk==0x27||vk==0x28||vk==0x2C||vk==0x90; }
  public static void Vk(ushort vk){ uint e = Ext(vk) ? 0x0001u : 0u; KINPUT[] k=new KINPUT[2];
    k[0].type=1;k[0].ki.vk=vk;k[0].ki.f=e; k[1].type=1;k[1].ki.vk=vk;k[1].ki.f=e|0x0002;
    SendInput(2,k,Marshal.SizeOf(typeof(KINPUT))); }
  // Press and release split apart, so modifiers can be held across another key.
  public static void VkDown(ushort vk){ uint e = Ext(vk) ? 0x0001u : 0u; KINPUT[] k=new KINPUT[1];
    k[0].type=1;k[0].ki.vk=vk;k[0].ki.f=e; SendInput(1,k,Marshal.SizeOf(typeof(KINPUT))); }
  public static void VkUp(ushort vk){ uint e = Ext(vk) ? 0x0001u : 0u; KINPUT[] k=new KINPUT[1];
    k[0].type=1;k[0].ki.vk=vk;k[0].ki.f=e|0x0002; SendInput(1,k,Marshal.SizeOf(typeof(KINPUT))); }
  public static void Uni(char c){ KINPUT[] k=new KINPUT[2];
    k[0].type=1;k[0].ki.sc=(ushort)c;k[0].ki.f=0x0004;
    k[1].type=1;k[1].ki.sc=(ushort)c;k[1].ki.f=0x0006;
    SendInput(2,k,Marshal.SizeOf(typeof(KINPUT))); }
}
"@
[void][Win]::SetProcessDPIAware()

# Target: the INSTALLED application. Override with $env:THEATER_VIZ_EXE.
$EXE = if ($env:THEATER_VIZ_EXE) { $env:THEATER_VIZ_EXE } else { "C:/Program Files/Theater Viz/Theater.Viz.exe" }

function FgPid(){ $h=[Win]::GetForegroundWindow(); $p=[uint32]0; [void][Win]::GetWindowThreadProcessId($h,[ref]$p); return [int]$p }
function VScreen(){ [System.Windows.Forms.SystemInformation]::VirtualScreen }
function Player(){ Get-Process Theater.Viz -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1 }
function Grab($path,$x,$y,$w,$h){
  $bmp = New-Object System.Drawing.Bitmap $w,$h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x,$y,0,0,(New-Object System.Drawing.Size($w,$h)))
  $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose();$bmp.Dispose()
}
# Key name -> Win32 virtual-key code. Shared by "key" and "chord".
function KeyVk($name){
  switch -Regex ($name) {
    "^enter$"{0x0D} "^tab$"{0x09} "^esc$"{0x1B} "^backspace$"{0x08} "^delete$"{0x2E}
    "^space$"{0x20} "^home$"{0x24} "^end$"{0x23}
    "^up$"{0x26} "^down$"{0x28} "^left$"{0x25} "^right$"{0x27}
    "^[A-Za-z]$"{ [int][char]([string]$name).ToUpper() }  # a letter's VK is its uppercase ASCII code
    default{ [int]$name }                                  # raw VK number
  }
}

# Returns $true when it is safe to capture; prints the refusal otherwise.
function GuardOk($want){
  if (-not $want) { return $true }
  $f = FgPid
  if ($f -eq [int]$want) { return $true }
  $n = try { (Get-Process -Id $f -ErrorAction Stop).ProcessName } catch { "unknown" }
  [Console]::WriteLine("REFUSED: foreground is pid $f ($n), not $want. NOT a valid capture - wake $want and retry.")
  return $false
}

switch ($cmd) {
  "launch" { if (-not (Test-Path $EXE)) { "ERROR: not found: $EXE"; break }
             $p = if ($a1) { Start-Process -FilePath $EXE -ArgumentList $a1 -PassThru } else { Start-Process -FilePath $EXE -PassThru }
             Start-Sleep -Seconds 14; "pid=$($p.Id) exe=$EXE" }
  "pid"    { $p = Player; if($p){ "pid=$($p.Id)" } else { "none" } }
  "fg"     { $f = FgPid; $n = try { (Get-Process -Id $f).ProcessName } catch { "unknown" }; "fg_pid=$f name=$n" }
  "wake"   { $want = [int]$a1
             # 1. Already frontmost? Do nothing at all - no flashing.
             if ((FgPid) -eq $want) { "already-foreground $want"; break }
             $p = Get-Process -Id $want
             # 2. Try a plain raise first.
             [void][Win]::SetForegroundWindow($p.MainWindowHandle); Start-Sleep -Milliseconds 250
             if ((FgPid) -eq $want) { "raised $want (no minimize needed)"; break }
             # 3. Last resort: minimize+restore forces a real WM_ACTIVATE so Unity wakes its input loop.
             [void][Win]::ShowWindow($p.MainWindowHandle,6); Start-Sleep -Milliseconds 250
             [void][Win]::ShowWindow($p.MainWindowHandle,9); [void][Win]::SetForegroundWindow($p.MainWindowHandle)
             Start-Sleep -Milliseconds 400; "woke $a1 via minimize-restore (foreground now: $(FgPid))" }
  "shot"   { if (-not (GuardOk $a2)) { break }
             $b=VScreen; Grab $a1 $b.X $b.Y $b.Width $b.Height; "shot $a1 $($b.Width)x$($b.Height) fg=$(FgPid)" }
  "region" { if (-not (GuardOk $a6)) { break }
             Grab $a1 ([int]$a2) ([int]$a3) ([int]$a4) ([int]$a5); "region $a1 $a2,$a3 ${a4}x${a5} fg=$(FgPid)" }
  "click"  { [Win]::Click([int]$a1,[int]$a2); "click $a1 $a2" }
  "pick"   { # Hover, settle, then click. UI Toolkit panel controls -- buttons AND dropdown
             # items -- swallow a synthetic click that arrives without a preceding mouse-move:
             # the control never enters its hover state and the click does nothing, silently.
             # Use this for anything in the left panel; plain "click" is fine on the map.
             $pause = if ($a3) { [int]$a3 } else { 700 }
             [void][Win]::SetCursorPos([int]$a1,[int]$a2); Start-Sleep -Milliseconds $pause
             [Win]::Click([int]$a1,[int]$a2); "pick $a1 $a2 (hover ${pause}ms)" }
  "dbl"    { [Win]::Click([int]$a1,[int]$a2); Start-Sleep -Milliseconds 60; [Win]::Click([int]$a1,[int]$a2); "dbl $a1 $a2" }
  "move"   { [void][Win]::SetCursorPos([int]$a1,[int]$a2); "move $a1 $a2" }
  "drag"   { $steps = if ($a5) { [int]$a5 } else { 20 }
             [Win]::Drag([int]$a1,[int]$a2,[int]$a3,[int]$a4,$steps,25)
             "drag $a1,$a2 -> $a3,$a4 ($steps steps)" }
  "type"   { foreach($c in $a1.ToCharArray()){ [Win]::Uni($c); Start-Sleep -Milliseconds 8 }; "typed" }
  "key"    { [Win]::Vk([uint16](KeyVk $a1)); "key $a1" }
  "chord"  { # e.g. "ctrl+a", "ctrl+shift+end", "alt+enter" -- modifiers held across the last key
             $parts = ($a1 -split '\+') | ForEach-Object { $_.Trim() }
             $mods = @(); $last = $parts[-1]
             foreach ($m in $parts[0..($parts.Count-2)]) {
               switch -Regex ($m) {
                 "^(ctrl|control)$" { $mods += 0x11 }
                 "^shift$"          { $mods += 0x10 }
                 "^alt$"            { $mods += 0x12 }
                 "^(win|meta)$"     { $mods += 0x5B }
                 default { "unknown modifier: $m"; return }
               }
             }
             $vk = KeyVk $last
             foreach ($m in $mods) { [Win]::VkDown([uint16]$m) }
             [Win]::Vk([uint16]$vk)
             [array]::Reverse($mods); foreach ($m in $mods) { [Win]::VkUp([uint16]$m) }
             "chord $a1" }
  "close"  { Stop-Process -Id ([int]$a1) -Force; "closed $a1" }
  default  { "unknown cmd: $cmd" }
}
