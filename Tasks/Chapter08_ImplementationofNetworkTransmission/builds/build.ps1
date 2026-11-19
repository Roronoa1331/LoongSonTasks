<#
.SYNOPSIS
    Builds the Chapter 08 (Loongson 1B network transmission) firmware for one
    experiment, or for all four experiments.

.DESCRIPTION
    The four experiments (TCP server, TCP client, UDP server, UDP client) all
    compile from the same source tree.  Only the four TEST_* macros in
    ..\lwip_test.h select which demo is active, so this script

        1. rewrites the four macros in lwip_test.h,
        2. saves a snapshot of the resulting header next to the firmware,
        3. compiles every project source into builds\<experiment>\obj,
        4. links with ..\ld.script and produces <experiment>.exe / .bin,
        5. writes the compiler output to results\logs\build_<experiment>.log.

    Outputs stay separated per experiment, so all four firmwares can coexist
    and no experiment can accidentally reuse another experiment's image.

.EXAMPLE
    .\build.ps1 -Experiment tcp_server

.EXAMPLE
    .\build.ps1 -Experiment all -Clean
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('tcp_server', 'tcp_client', 'udp_server', 'udp_client', 'all')]
    [string]$Experiment,

    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

$BuildsDir  = $PSScriptRoot
$ProjectDir = Split-Path -Parent $BuildsDir
$HeaderPath = Join-Path $ProjectDir 'lwip_test.h'
$LogDir     = Join-Path $ProjectDir 'results\logs'
$MsysBin    = 'C:\msys\1.0\bin'
$MakeExe    = Join-Path $MsysBin 'make.exe'
$Toolchain  = 'E:\LoongIDE\mips-2015.05\bin'

$MacroSets = @{
    'tcp_server' = [ordered]@{ TEST_TCP_SERVER = 1; TEST_TCP_CLIENT = 0; TEST_UDP_SERVER = 0; TEST_UDP_CLIENT = 0 }
    'tcp_client' = [ordered]@{ TEST_TCP_SERVER = 0; TEST_TCP_CLIENT = 1; TEST_UDP_SERVER = 0; TEST_UDP_CLIENT = 0 }
    'udp_server' = [ordered]@{ TEST_TCP_SERVER = 0; TEST_TCP_CLIENT = 0; TEST_UDP_SERVER = 1; TEST_UDP_CLIENT = 0 }
    'udp_client' = [ordered]@{ TEST_TCP_SERVER = 0; TEST_TCP_CLIENT = 0; TEST_UDP_SERVER = 0; TEST_UDP_CLIENT = 1 }
}

$ExperimentMacro = @{
    'tcp_server' = 'TEST_TCP_SERVER'
    'tcp_client' = 'TEST_TCP_CLIENT'
    'udp_server' = 'TEST_UDP_SERVER'
    'udp_client' = 'TEST_UDP_CLIENT'
}

foreach ($tool in @($MakeExe, (Join-Path $Toolchain 'mips-sde-elf-gcc.exe'))) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Required build tool not found: $tool"
    }
}

$env:Path = "$MsysBin;$Toolchain;" + $env:Path

function Set-TestMacros {
    param(
        [string]$Path,
        [System.Collections.Specialized.OrderedDictionary]$Values
    )

    $text = [System.IO.File]::ReadAllText($Path)

    foreach ($name in $Values.Keys) {
        $pattern = '(?m)^#define\s+' + $name + '\s+\d+'
        $found = [regex]::Matches($text, $pattern)
        if ($found.Count -ne 1) {
            throw "Expected exactly one '#define $name <n>' line in $Path, found $($found.Count)."
        }
        $replacement = '#define ' + $name.PadRight(24) + $Values[$name]
        $text = [regex]::Replace($text, $pattern, $replacement)
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $text, $utf8NoBom)

    # Guard: exactly one experiment may be enabled at a time.
    $enabled = @()
    foreach ($name in $Values.Keys) {
        $m = [regex]::Match($text, '(?m)^#define\s+' + $name + '\s+(\d+)')
        if ($m.Groups[1].Value -eq '1') { $enabled += $name }
    }
    if ($enabled.Count -ne 1) {
        throw "Macro state is invalid: $($enabled.Count) experiments enabled ($($enabled -join ', '))."
    }
    return $enabled[0]
}

function Get-ProjectSources {
    $dirs = @()
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -File -Include *.c, *.S |
        Where-Object { $_.FullName -notmatch '[\\/](builds|results|docs|reference_screenshots)[\\/]' } |
        ForEach-Object { $dirs += (Split-Path -Parent $_.FullName).Substring($ProjectDir.Length).TrimStart('\', '/') }
    return ($dirs | Sort-Object -Unique)
}

function Invoke-ExperimentBuild {
    param([string]$Exp)

    Write-Host ''
    Write-Host "=== $Exp ===" -ForegroundColor Cyan

    $active = Set-TestMacros -Path $HeaderPath -Values $MacroSets[$Exp]
    if ($active -ne $ExperimentMacro[$Exp]) {
        throw "Macro guard failed: '$active' is enabled but '$Exp' was requested."
    }
    Write-Host "lwip_test.h : $($MacroSets[$Exp].Keys -join ', ') -> only $active = 1"

    $outDir = Join-Path $BuildsDir $Exp
    if (-not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }

    # Copy of the exact header that produced this image (build evidence).
    Copy-Item -LiteralPath $HeaderPath -Destination (Join-Path $outDir 'lwip_test.h.snapshot') -Force

    if (-not (Test-Path -LiteralPath $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    $logPath = Join-Path $LogDir ("build_$Exp.log")

    $startTime = Get-Date
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    # The gcc warnings arrive on stderr, which PowerShell 5.1 would turn into
    # terminating errors while $ErrorActionPreference is "Stop".
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    if ($Clean) {
        & $MakeExe '-C' $BuildsDir "EXP=$Exp" 'clean' 2>&1 | Out-Null
    }

    # The makefile does not create directories (make runs under cmd.exe);
    # create the mirrored object tree up front, after the clean.
    $objRoot = Join-Path $outDir 'obj'
    if (-not (Test-Path -LiteralPath $objRoot)) {
        New-Item -ItemType Directory -Path $objRoot | Out-Null
    }
    foreach ($rel in Get-ProjectSources) {
        $target = if ($rel) { Join-Path $objRoot $rel } else { $objRoot }
        if (-not (Test-Path -LiteralPath $target)) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }
    }

    $header = New-Object System.Collections.Generic.List[string]
    $header.Add("=== Chapter 08 build: $Exp ===")
    $header.Add("started          : $($startTime.ToString('s'))")
    $header.Add("experiment macro : $($ExperimentMacro[$Exp]) = 1")
    $header.Add("--- lwip_test.h macro state ---")
    (Select-String -LiteralPath $HeaderPath -Pattern '^#define\s+TEST_') | ForEach-Object { $header.Add($_.Line) }
    $header.Add("--- compiler output ---")
    [System.IO.File]::WriteAllLines($logPath, $header, $utf8NoBom)

    $makeLines = New-Object System.Collections.Generic.List[string]
    & $MakeExe '-C' $BuildsDir "EXP=$Exp" 'all' 2>&1 | ForEach-Object {
        $line = $_.ToString()
        $makeLines.Add($line)
        Write-Host $line
    }
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference

    [System.IO.File]::AppendAllLines($logPath, $makeLines, $utf8NoBom)

    $exe = Join-Path $outDir "$Exp.exe"
    $bin = Join-Path $outDir "$Exp.bin"
    $ok = ($exitCode -eq 0) -and (Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $bin)

    $summary = New-Object System.Text.StringBuilder
    [void]$summary.AppendLine("experiment       : $Exp")
    [void]$summary.AppendLine("built at         : $((Get-Date).ToString('s'))")
    [void]$summary.AppendLine("duration         : $([int]((Get-Date) - $startTime).TotalSeconds) s")
    [void]$summary.AppendLine("toolchain        : $Toolchain (mips-sde-elf-gcc)")
    if ($ok) {
        [void]$summary.AppendLine("result           : SUCCESS")
        [void]$summary.AppendLine("elf              : $exe ($((Get-Item -LiteralPath $exe).Length) bytes)")
        [void]$summary.AppendLine("binary           : $bin ($((Get-Item -LiteralPath $bin).Length) bytes)")
        [void]$summary.AppendLine("bin sha256       : $((Get-FileHash -LiteralPath $bin -Algorithm SHA256).Hash)")
    }
    else {
        [void]$summary.AppendLine("result           : FAILED (make exit code $exitCode)")
    }
    [void]$summary.AppendLine("build log        : $logPath")
    $summaryText = $summary.ToString()
    [System.IO.File]::WriteAllText((Join-Path $outDir 'build_info.txt'), $summaryText, $utf8NoBom)
    $tail = New-Object System.Collections.Generic.List[string]
    $tail.Add("--- summary ---")
    $tail.Add($summaryText)
    [System.IO.File]::AppendAllLines($logPath, $tail, $utf8NoBom)

    Write-Host $summaryText
    if (-not $ok) {
        throw "Build failed for '$Exp' (see $logPath)."
    }
}

$targets = if ($Experiment -eq 'all') { @('tcp_server', 'tcp_client', 'udp_server', 'udp_client') } else { @($Experiment) }

foreach ($target in $targets) {
    Invoke-ExperimentBuild -Exp $target
}

Write-Host ''
Write-Host "Built: $($targets -join ', ')" -ForegroundColor Green
Write-Host "lwip_test.h currently selects: $(@(Select-String -LiteralPath $HeaderPath -Pattern '^#define\s+TEST_\w+\s+1') | ForEach-Object { ($_.Line -split '\s+')[1] })"
