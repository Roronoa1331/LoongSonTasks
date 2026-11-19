<#
    capture_session.ps1 - record genuine interactive calculator sessions

    This is not a simulation of the program.  For every scenario the script
    starts the real calculator in a real Windows console window, injects
    real keyboard events into that console (so Windows echoes the typed
    characters exactly as it does for a human), and then reads the real
    console screen buffer back with ReadConsoleOutputCharacter().

    The resulting screenshots\*.txt files therefore contain the console
    content itself, not a hand-written transcript.

    Why text instead of .png?
    The machine used for this project had no interactive desktop available
    for a real screen grab (CopyFromScreen returned an all-black image), so
    the console content is stored as text instead of inventing pictures.
    See screenshots\README.md for the two-minute procedure that turns each
    .txt file into a real .png screenshot.

    Usage:  powershell -ExecutionPolicy Bypass -File screenshots\capture_session.ps1
#>
param(
    [string] $Exe = "$PSScriptRoot\..\build\calculator.exe"
)

$ErrorActionPreference = "Stop"
$Exe = [System.IO.Path]::GetFullPath($Exe)
if (-not (Test-Path $Exe)) { throw "Calculator not found: $Exe (run 'make' first)" }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class ConsoleIo
{
    [StructLayout(LayoutKind.Sequential)]
    public struct COORD { public short X; public short Y; public COORD(short x, short y) { X = x; Y = y; } }

    [StructLayout(LayoutKind.Sequential)]
    public struct SMALL_RECT { public short Left; public short Top; public short Right; public short Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct CONSOLE_SCREEN_BUFFER_INFO
    {
        public COORD dwSize;
        public COORD dwCursorPosition;
        public ushort wAttributes;
        public SMALL_RECT srWindow;
        public COORD dwMaximumWindowSize;
    }

    [StructLayout(LayoutKind.Explicit, Size = 20)]
    public struct INPUT_RECORD
    {
        [FieldOffset(0)]  public ushort EventType;
        [FieldOffset(4)]  public int    bKeyDown;
        [FieldOffset(8)]  public ushort wRepeatCount;
        [FieldOffset(10)] public ushort wVirtualKeyCode;
        [FieldOffset(12)] public ushort wVirtualScanCode;
        [FieldOffset(14)] public char   UnicodeChar;
        [FieldOffset(16)] public uint   dwControlKeyState;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FreeConsole();

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AttachConsole(uint dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr CreateFileW(string name, uint access, uint share,
        IntPtr security, uint disposition, uint flags, IntPtr template);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool WriteConsoleInputW(IntPtr h, INPUT_RECORD[] records, uint length, out uint written);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleScreenBufferInfo(IntPtr h, out CONSOLE_SCREEN_BUFFER_INFO info);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool ReadConsoleOutputCharacterW(IntPtr h, StringBuilder buffer,
        uint length, COORD coord, out uint read);
}
'@

function Open-ConsoleHandle([string] $name, [uint32] $access)
{
    # GENERIC_READ 0x80000000 / GENERIC_WRITE 0x40000000, share R+W, OPEN_EXISTING
    $h = [ConsoleIo]::CreateFileW($name, $access, 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
    if ($h -eq [IntPtr]::Zero -or $h -eq [IntPtr]::new(-1)) { throw "Cannot open $name" }
    return $h
}

function Send-Key([IntPtr] $handle, [char] $ch)
{
    $vk = 0
    if ($ch -eq "`n") { $vk = 0x0D; $ch = "`r" }
    elseif ($ch -eq '.') { $vk = 0xBE }
    elseif ($ch -eq '-') { $vk = 0xBD }
    elseif ([char]::IsLetter($ch)) { $vk = [int][char]::ToUpperInvariant($ch) }
    else { $vk = [int]$ch }

    $records = New-Object 'ConsoleIo+INPUT_RECORD[]' 2
    foreach ($i in 0, 1) {
        $rec = New-Object 'ConsoleIo+INPUT_RECORD'
        $rec.EventType         = 1
        $rec.bKeyDown          = if ($i -eq 0) { 1 } else { 0 }
        $rec.wRepeatCount      = 1
        $rec.wVirtualKeyCode   = [uint16]$vk
        $rec.wVirtualScanCode  = 0
        $rec.UnicodeChar       = $ch
        $rec.dwControlKeyState = 0
        $records[$i] = $rec
    }
    $written = 0
    if (-not [ConsoleIo]::WriteConsoleInputW($handle, $records, 2, [ref]$written) -or $written -ne 2) {
        throw ("WriteConsoleInput failed, err=" + [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    Start-Sleep -Milliseconds 30
}

function Send-Line([IntPtr] $handle, [string] $text)
{
    foreach ($c in $text.ToCharArray()) { Send-Key $handle $c }
    Send-Key $handle "`n"
    Start-Sleep -Milliseconds 300
}

# Reads the visible part of the real console screen buffer.
function Read-Screen([IntPtr] $conout)
{
    $info = New-Object 'ConsoleIo+CONSOLE_SCREEN_BUFFER_INFO'
    if (-not [ConsoleIo]::GetConsoleScreenBufferInfo($conout, [ref]$info)) {
        throw "GetConsoleScreenBufferInfo failed"
    }

    $width  = $info.dwSize.X
    $top    = $info.srWindow.Top
    $bottom = $info.srWindow.Bottom

    $lines = @()
    for ($row = $top; $row -le $bottom; $row++) {
        $sb = New-Object System.Text.StringBuilder ($width + 1)
        $read = 0
        $coord = New-Object 'ConsoleIo+COORD' 0, ([int16]$row)
        [void][ConsoleIo]::ReadConsoleOutputCharacterW($conout, $sb, [uint32]$width, $coord, [ref]$read)
        $text = if ($read -gt 0) { $sb.ToString().Substring(0, $read) } else { "" }
        $lines += (($text -replace '[^\u0020-\u007E]', ' ').TrimEnd())
    }

    while ($lines.Count -gt 0 -and $lines[-1].Trim() -eq "") {
        $lines = @($lines | Select-Object -First ($lines.Count - 1))
    }
    while ($lines.Count -gt 0 -and $lines[0].Trim() -eq "") {
        $lines = @($lines | Select-Object -Skip 1)
    }
    return ,$lines
}

# ---------------------------------------------------------------------------
# One fresh console per scenario - exactly what separate screenshots show.
# ---------------------------------------------------------------------------
$scenarios = @(
    [pscustomobject]@{ File = "01_main_menu.txt";            Title = "main menu";              Keys = @() },
    [pscustomobject]@{ File = "02_addition.txt";             Title = "10 + 5";                 Keys = @("1", "10", "5") },
    [pscustomobject]@{ File = "03_subtraction.txt";          Title = "10 - 5";                 Keys = @("2", "10", "5") },
    [pscustomobject]@{ File = "04_multiplication.txt";       Title = "10 * 5";                 Keys = @("3", "10", "5") },
    [pscustomobject]@{ File = "05_division.txt";             Title = "10 / 5";                 Keys = @("4", "10", "5") },
    [pscustomobject]@{ File = "06_division_by_zero.txt";     Title = "10 / 0";                 Keys = @("4", "10", "0") },
    [pscustomobject]@{ File = "07_invalid_menu_option.txt";  Title = "invalid menu option 9";  Keys = @("9") },
    [pscustomobject]@{ File = "08_invalid_numeric_input.txt"; Title = "invalid number abc";    Keys = @("1", "abc") },
    [pscustomobject]@{ File = "09_decimal_calculation.txt";  Title = "2.5 + 1.5";              Keys = @("1", "2.5", "1.5") },
    [pscustomobject]@{ File = "10_exit.txt";                 Title = "exit with option 5";     Keys = @("5") }
)

$log = New-Object System.Collections.Generic.List[string]
$log.Add("Console screen-buffer capture - " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$log.Add("Program: $Exe")
$log.Add("Host   : $env:COMPUTERNAME, Windows console (conhost), $((Get-Culture).Name)")
$log.Add("")

foreach ($scenario in $scenarios) {
    [void][ConsoleIo]::FreeConsole()

    $proc = Start-Process -FilePath $env:ComSpec -ArgumentList "/k", "`"$Exe`"" -PassThru
    Start-Sleep -Milliseconds 1200

    [void][ConsoleIo]::FreeConsole()
    $attached = $false
    for ($attempt = 1; $attempt -le 10 -and -not $attached; $attempt++) {
        $attached = [ConsoleIo]::AttachConsole([uint32]$proc.Id)
        if (-not $attached) { Start-Sleep -Milliseconds 400 }
    }
    if (-not $attached) {
        throw ("AttachConsole failed for scenario " + $scenario.File)
    }
    $conin  = Open-ConsoleHandle "CONIN$"  ([uint32]3221225472)
    $conout = Open-ConsoleHandle "CONOUT$" ([uint32]2147483648)

    try {
        foreach ($line in $scenario.Keys) { Send-Line $conin $line }
        Start-Sleep -Milliseconds 600

        $screen = Read-Screen $conout
        $path = Join-Path $PSScriptRoot $scenario.File
        [System.IO.File]::WriteAllLines($path, $screen)
        Write-Host ("saved {0,-32} ({1,2} lines) - {2}" -f $scenario.File, $screen.Count, $scenario.Title)
        $log.Add(("{0,-32} {1,2} lines  {2}" -f $scenario.File, $screen.Count, $scenario.Title))
    }
    finally {
        [void][ConsoleIo]::FreeConsole()
        # /T also stops the calculator started by cmd /k
        Start-Process -FilePath "taskkill.exe" -ArgumentList "/PID", $proc.Id, "/T", "/F" -Wait -WindowStyle Hidden | Out-Null
        Start-Sleep -Milliseconds 250
    }
}

$logPath = Join-Path $PSScriptRoot "capture_log.txt"
[System.IO.File]::WriteAllLines($logPath, $log)
Write-Host ""
Write-Host "Capture complete. Files written to $PSScriptRoot"
