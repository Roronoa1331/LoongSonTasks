# Load a raw image into Loongson 1B RAM through PMON's XMODEM receiver and
# optionally start it. Board must sit at the "PMON>" prompt on COM8.
#
#   .\pmon_load.ps1 -Image ..\builds\tcp_server\tcp_server.bin -Run
#   .\pmon_load.ps1 -SelfTest                 # 512-byte pattern + dump verification
#
# NOTE: PMON parses numbers as decimal unless a 0x prefix is given.

[CmdletBinding()]
param(
    [string]$Port = 'COM8',
    [string]$Image,
    [string]$Base = '0x80200000',
    [switch]$Run,
    [switch]$SelfTest,
    [int]$BlockSize = 1024,
    [int]$CaptureSeconds = 0,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'serial.ps1')
. (Join-Path $PSScriptRoot 'pmon_lib.ps1')

$openMsg = Open-Board -Port $Port
Write-Host "port $Port : $openMsg"
try {
    if (-not (Wait-PmonPrompt -TimeoutMs 5000)) { throw "board is not at the PMON prompt" }
    Write-Host "board is at PMON> prompt"

    if ($SelfTest) {
        $payload = New-Object byte[] 512
        for ($i = 0; $i -lt 512; $i++) { $payload[$i] = [byte](($i * 7 + 3) -band 0xFF) }
        [BoardSerial]::Write("xmodem base=$Base`r")
        [void]([BoardSerial]::Read(400))
        Send-Xmodem -Payload $payload -Block $BlockSize
        [void](Read-PmonUntil -Pattern 'PMON>' -TimeoutMs 5000)
        [BoardSerial]::Write("d4 $Base`r")
        Read-PmonUntil -Pattern 'PMON>' -TimeoutMs 5000 | Write-Host
        return
    }

    if (-not $Image) { throw "specify -Image <file.bin> (or -SelfTest)" }
    $resolved = (Resolve-Path $Image).Path
    $payload = [System.IO.File]::ReadAllBytes($resolved)
    Write-Host ("image: {0} ({1:N0} bytes)" -f $resolved, $payload.Length)

    [BoardSerial]::Write("xmodem base=$Base`r")
    [void]([BoardSerial]::Read(400))
    Send-Xmodem -Payload $payload -Block $BlockSize
    $after = Read-PmonUntil -Pattern 'PMON>' -TimeoutMs 8000
    if ($after -match 'PMON>') { Write-Host "  image loaded, PMON returned to prompt" }

    [BoardSerial]::Write("flush`r")
    [void](Read-PmonUntil -Pattern 'PMON>' -TimeoutMs 5000)

    if ($Run) {
        Write-Host "starting program at $Base"
        [BoardSerial]::Write("g $Base`r")
    }

    if ($CaptureSeconds -gt 0) {
        $text = [BoardSerial]::Read($CaptureSeconds * 1000)
        Write-Host $text
        if ($LogPath) {
            $dir = Split-Path -Parent $LogPath
            if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            [System.IO.File]::WriteAllText($LogPath, $text, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "console log written: $LogPath"
        }
    }
}
finally {
    Close-Board
}
