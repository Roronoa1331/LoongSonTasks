# Capture a single window (by process name or HWND) to a PNG.
# Works even when the desktop is locked, unlike full-screen capture.
#
#   .\capture_window.ps1 -ProcessName putty -Out C:\temp\putty.png
#   .\capture_window.ps1 -WindowHandle 3474500 -Out C:\temp\ide.png
#   .\capture_window.ps1 -List                  # list capturable windows

[CmdletBinding(DefaultParameterSetName = 'Proc')]
param(
    [Parameter(ParameterSetName = 'Proc', Position = 0)][string]$ProcessName,
    [Parameter(ParameterSetName = 'Handle')][long]$WindowHandle,
    [Parameter(ParameterSetName = 'List')][switch]$List,
    [string]$Out,
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'

if (-not ('WindowCapture' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Text;
using System.Drawing;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class WindowCapture {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }

  public static List<string> List() {
    var l = new List<string>();
    EnumWindows((h,x) => {
      var t = new StringBuilder(512); GetWindowText(h,t,512);
      var c = new StringBuilder(256); GetClassName(h,c,256);
      uint pid; GetWindowThreadProcessId(h,out pid);
      RECT r; GetWindowRect(h,out r);
      int w = r.R-r.L, ht = r.B-r.T;
      if (w > 40 && ht > 20) l.Add(h.ToInt64()+"|pid="+pid+"|"+c+"|"+w+"x"+ht+"|"+t);
      return true;
    }, IntPtr.Zero);
    return l;
  }

  public static long FindByPid(uint pid, bool biggest) {
    long best = 0; int bestArea = 0;
    EnumWindows((h,x) => {
      uint p; GetWindowThreadProcessId(h,out p);
      if (p == pid) {
        RECT r; GetWindowRect(h,out r);
        int w = r.R-r.L, ht = r.B-r.T;
        if (w > 40 && ht > 20) {
          int area = w*ht;
          if (biggest ? area > bestArea : best == 0) { best = h.ToInt64(); bestArea = area; }
        }
      }
      return true;
    }, IntPtr.Zero);
    return best;
  }

  public static Bitmap Grab(long hh, bool restore) {
    var h = new IntPtr(hh);
    if (restore && !IsWindowVisible(h)) ShowWindow(h, 9);
    RECT r; if (!GetWindowRect(h, out r)) return null;
    int w = r.R-r.L, ht = r.B-r.T;
    if (w <= 0 || ht <= 0) return null;
    var bmp = new Bitmap(w, ht);
    using (var g = Graphics.FromImage(bmp)) {
      IntPtr hdc = g.GetHdc();
      bool ok = PrintWindow(h, hdc, 2);
      g.ReleaseHdc(hdc);
      if (!ok) { bmp.Dispose(); return null; }
    }
    return bmp;
  }

  public static double DarkRatio(Bitmap b) {
    int dark = 0, total = 0;
    for (int y = 0; y < b.Height; y += 9) for (int x = 0; x < b.Width; x += 9) {
      Color c = b.GetPixel(x, y); total++;
      if (c.R < 16 && c.G < 16 && c.B < 16) dark++;
    }
    return total == 0 ? 1.0 : (double)dark / total;
  }
}
'@
}

if ($List) {
    [WindowCapture]::List() | ForEach-Object { $_ }
    return
}

if ($PSCmdlet.ParameterSetName -eq 'Handle') { $hwnd = $WindowHandle }
else {
    if (-not $ProcessName) { throw "specify -ProcessName or -WindowHandle (or -List)" }
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) { throw "no process named '$ProcessName'" }
    $hwnd = [WindowCapture]::FindByPid([uint32]$proc.Id, $true)
    if (-not $hwnd) { throw "process '$ProcessName' has no capturable window" }
}
if (-not $Out) { throw "specify -Out <file.png>" }

$bmp = [WindowCapture]::Grab([long]$hwnd, [bool]$Restore)
if (-not $bmp) { throw "PrintWindow failed for hwnd $hwnd" }
try {
    $ratio = [WindowCapture]::DarkRatio($bmp)
    $dir = Split-Path -Parent $Out
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("captured hwnd {0} -> {1} ({2}x{3}, dark ratio {4:P0})" -f $hwnd, $Out, $bmp.Width, $bmp.Height, $ratio)
    if ($ratio -gt 0.98) { Write-Warning "the capture is almost entirely black - the window may not be rendering" }
}
finally { $bmp.Dispose() }
