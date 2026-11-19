# Serial console helper for the Loongson 1B (CH340 @ COM8, 115200 8-N-1).
# .NET's SerialPort cannot open this CH340, so the Win32 comm API is used directly.
#   . .\serial.ps1
#   Open-Board                       # open the port (default COM8)
#   Send-Board "help`r"              # write a string
#   Read-Board -Ms 2000              # read for N milliseconds, returns text
#   Close-Board

if (-not ('BoardSerial' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class BoardSerial {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sec,
                                         uint disp, uint flags, IntPtr tmpl);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetupComm(IntPtr h, int i, int o);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetCommState(IntPtr h, ref DCB d);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetCommState(IntPtr h, ref DCB d);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetCommTimeouts(IntPtr h, ref CT t);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool PurgeComm(IntPtr h, uint f);
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern bool ReadFile(IntPtr h, byte[] b, int n, ref int r, IntPtr o);
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern bool WriteFile(IntPtr h, byte[] b, int n, ref int w, IntPtr o);
  [StructLayout(LayoutKind.Sequential)] public struct DCB {
    public int DCBlength; public uint BaudRate; public uint Flags; public ushort wReserved;
    public ushort XonLim; public ushort XoffLim; public byte ByteSize; public byte Parity;
    public byte StopBits; public byte XonChar; public byte XoffChar; public byte ErrorChar;
    public byte EofChar; public byte EvtChar; public ushort wReserved1; }
  [StructLayout(LayoutKind.Sequential)] public struct CT { public int RIT, RTM, RTC, WTM, WTC; }

  public static IntPtr Handle = IntPtr.Zero;
  public static string Open(string port, uint baud) {
    Handle = CreateFile(@"\\.\" + port, 0xC0000000, 0, IntPtr.Zero, 3, 0, IntPtr.Zero);
    if (Handle.ToInt64() == -1) { Handle = IntPtr.Zero; return "CreateFile failed, win32 error " + Marshal.GetLastWin32Error(); }
    SetupComm(Handle, 16384, 16384);
    DCB d = new DCB(); d.DCBlength = Marshal.SizeOf(typeof(DCB));
    if (!GetCommState(Handle, ref d)) return "GetCommState failed, error " + Marshal.GetLastWin32Error();
    d.BaudRate = baud; d.ByteSize = 8; d.Parity = 0; d.StopBits = 0; d.Flags = 1;
    string note = "OK";
    if (!SetCommState(Handle, ref d)) note = "SetCommState failed, error " + Marshal.GetLastWin32Error() + " (port left at driver defaults)";
    CT t = new CT(); t.RIT = 30; t.RTM = 0; t.RTC = 80; t.WTM = 0; t.WTC = 1500;
    SetCommTimeouts(Handle, ref t);
    PurgeComm(Handle, 0x0004 | 0x0008);
    return note;
  }
  public static void Close() { if (Handle != IntPtr.Zero) { CloseHandle(Handle); Handle = IntPtr.Zero; } }
  public static int ReadByte(int timeoutMs) {
    byte[] b = new byte[1]; int n = 0;
    var sw = System.Diagnostics.Stopwatch.StartNew();
    while (sw.ElapsedMilliseconds < timeoutMs) {
      if (ReadFile(Handle, b, 1, ref n, IntPtr.Zero) && n == 1) return b[0];
      System.Threading.Thread.Sleep(1);
    }
    return -1;
  }
  public static string Read(int ms) {
    var sb = new System.Text.StringBuilder(); byte[] buf = new byte[16384];
    var sw = System.Diagnostics.Stopwatch.StartNew();
    while (sw.ElapsedMilliseconds < ms) {
      int n = 0;
      if (ReadFile(Handle, buf, buf.Length, ref n, IntPtr.Zero) && n > 0)
        sb.Append(System.Text.Encoding.ASCII.GetString(buf, 0, n));
      else System.Threading.Thread.Sleep(10);
    }
    return sb.ToString();
  }
  public static void WriteBytes(byte[] b) { int w = 0; WriteFile(Handle, b, b.Length, ref w, IntPtr.Zero); }
  public static void Write(string s) { WriteBytes(System.Text.Encoding.ASCII.GetBytes(s)); }
}
'@
}

function Open-Board {
    param([string]$Port = 'COM8', [int]$Baud = 115200)
    $r = [BoardSerial]::Open($Port, $Baud)
    if ($r -notlike 'OK*') { Write-Warning $r }
    return $r
}
function Close-Board { [BoardSerial]::Close() }
function Send-Board { param([string]$Text) [BoardSerial]::Write($Text) }
function Read-Board { param([int]$Ms = 1000) [BoardSerial]::Read($Ms) }
