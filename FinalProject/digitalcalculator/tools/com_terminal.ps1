# Raw Win32 serial terminal for the CH340 when PuTTY/.NET cannot configure it.
#
#   .\com_terminal.ps1 -Port COM9 -Baud 115200          interactive terminal
#   .\com_terminal.ps1 -Port COM9 -CaptureSeconds 5     read for 5 s and exit
#
# The port is opened with CreateFile/ReadFile/WriteFile, which works even when
# SetCommState returns error 31.  If SetCommState fails, the port is used at
# whatever baud it currently reports (normally 115200).

param(
    [string]$Port = 'COM9',
    [int]$Baud = 115200,
    [int]$CaptureSeconds = 0
)

$ErrorActionPreference = 'Stop'

if (-not ('RawSerial' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class RawSerial {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sec,
                                         uint disp, uint flags, IntPtr tmpl);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetCommState(IntPtr h, ref DCB d);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetCommState(IntPtr h, ref DCB d);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetCommTimeouts(IntPtr h, ref CT t);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadFile(IntPtr h, byte[] b, int n, ref int r, IntPtr o);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool WriteFile(IntPtr h, byte[] b, int n, ref int w, IntPtr o);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool PurgeComm(IntPtr h, uint f);
  [StructLayout(LayoutKind.Sequential)] public struct DCB {
    public int DCBlength; public uint BaudRate; public uint Flags; public ushort wReserved;
    public ushort XonLim; public ushort XoffLim; public byte ByteSize; public byte Parity;
    public byte StopBits; public byte XonChar; public byte XoffChar; public byte ErrorChar;
    public byte EofChar; public byte EvtChar; public ushort wReserved1; }
  [StructLayout(LayoutKind.Sequential)] public struct CT { public int RIT, RTM, RTC, WTM, WTC; }

  public static IntPtr Handle = IntPtr.Zero;
  public static int CurrentBaud = 0;
  public static string Open(string port, int baud) {
    Handle = CreateFile(@"\\.\" + port, 0xC0000000, 0, IntPtr.Zero, 3, 0, IntPtr.Zero);
    if (Handle.ToInt64() == -1) { Handle = IntPtr.Zero; return "CreateFile failed, error " + Marshal.GetLastWin32Error(); }
    DCB d = new DCB(); d.DCBlength = Marshal.SizeOf(typeof(DCB));
    GetCommState(Handle, ref d); CurrentBaud = (int)d.BaudRate;
    d.BaudRate = (uint)baud; d.ByteSize = 8; d.Parity = 0; d.StopBits = 0; d.Flags = 1;
    bool set = SetCommState(Handle, ref d);
    int err = Marshal.GetLastWin32Error();
    CT t = new CT(); t.RIT = 20; t.RTM = 0; t.RTC = 100; t.WTM = 0; t.WTC = 500;
    SetCommTimeouts(Handle, ref t);
    PurgeComm(Handle, 0x0004 | 0x0008);
    return "opened " + port + ", current baud " + CurrentBaud +
           (set ? ", SetCommState OK" : ", SetCommState failed (error " + err + ") - using current baud");
  }
  public static void Close() { if (Handle != IntPtr.Zero) { CloseHandle(Handle); Handle = IntPtr.Zero; } }
  public static int Read(byte[] buf) { int n = 0; if (Handle == IntPtr.Zero) return 0; ReadFile(Handle, buf, buf.Length, ref n, IntPtr.Zero); return n; }
  public static void Write(byte[] buf) { int w = 0; if (Handle != IntPtr.Zero) WriteFile(Handle, buf, buf.Length, ref w, IntPtr.Zero); }
}
'@
}

$msg = [RawSerial]::Open($Port, $Baud)
Write-Host $msg

try {
    if ($CaptureSeconds -gt 0) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $buf = New-Object byte[] 4096
        $all = New-Object System.Text.StringBuilder
        while ($sw.Elapsed.TotalSeconds -lt $CaptureSeconds) {
            $n = [RawSerial]::Read($buf)
            if ($n -gt 0) { [void]$all.Append([System.Text.Encoding]::ASCII.GetString($buf, 0, $n)) }
            else { Start-Sleep -Milliseconds 20 }
        }
        Write-Host "--- captured $($all.Length) chars ---"
        Write-Host ($all.ToString() -replace "`r", '<CR>' -replace "`n", '<LF>')
        return
    }

    Write-Host "Interactive terminal. Type to send; Ctrl+C to exit."
    Write-Host "--------------------------------------------------------"
    $buf = New-Object byte[] 4096
    while ($true) {
        $n = [RawSerial]::Read($buf)
        if ($n -gt 0) {
            [Console]::Write([System.Text.Encoding]::ASCII.GetString($buf, 0, $n))
        }
        while ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            if ($k.Key -eq 'Escape') { return }
            $s = if ($k.Key -eq 'Enter') { "`r`n" } else { [string]$k.KeyChar }
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($s)
            [RawSerial]::Write($bytes)
            [Console]::Write($s)   # local echo, since the calculator does not echo
        }
        Start-Sleep -Milliseconds 10
    }
}
finally {
    [RawSerial]::Close()
}
