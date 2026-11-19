<#
    run_tests.ps1 - automated test suite for the Digital Calculator

    Runs the calculator once per test case with a fixed standard-input
    script, then checks the captured standard output for the expected
    text.  Every case is recorded (input, actual output, PASS/FAIL) in
    tests/results/ so the evidence is reproducible.

    Usage (native Windows build):
        .\run_tests.ps1
        .\run_tests.ps1 -Exe ..\build\calculator.exe

    Usage (MIPS32 build executed in the MIPS SDE simulator):
        .\run_tests.ps1 -Exe E:\LoongIDE\mips-2011.03\bin\mips-sde-elf-run.exe `
                        -ExeArgs ..\build_mips\calculator.elf
#>
param(
    [string]   $Exe            = "..\build\calculator.exe",
    [string[]] $ExeArgs        = @(),
    [string]   $ResultsSubdir  = "results",
    [switch]   $NoReport
)

$ErrorActionPreference = "Stop"

$testsDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $testsDir
$casesDir   = Join-Path $testsDir "cases"
$resultsDir = Join-Path $testsDir $ResultsSubdir

if (-not [System.IO.Path]::IsPathRooted($Exe)) {
    $Exe = Join-Path $testsDir $Exe
}
$ExeArgs = $ExeArgs | ForEach-Object {
    if ($_ -and -not [System.IO.Path]::IsPathRooted($_) -and $_.EndsWith(".elf")) {
        Join-Path $testsDir $_
    } else { $_ }
}

if (-not (Test-Path $Exe)) {
    Write-Host "Executable not found: $Exe" -ForegroundColor Red
    Write-Host "Build it first:  make   (or  make mips  for the MIPS32 build)"
    exit 2
}

New-Item -ItemType Directory -Force -Path $casesDir   | Out-Null
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

# ---------------------------------------------------------------------------
# Test cases: ID, description, input script, expected fragments.
# A test passes when the program exits with code 0 and every expected
# fragment appears in its standard output.
# ---------------------------------------------------------------------------
$cases = @(
    @{ Id = "T01"; Name = "Addition 10 + 5";             Input = "1`n10`n5`n5`n";            Expect = @("Result: 15") }
    @{ Id = "T02"; Name = "Subtraction 10 - 5";          Input = "2`n10`n5`n5`n";            Expect = @("Result: 5") }
    @{ Id = "T03"; Name = "Multiplication 10 * 5";       Input = "3`n10`n5`n5`n";            Expect = @("Result: 50") }
    @{ Id = "T04"; Name = "Division 10 / 5";             Input = "4`n10`n5`n5`n";            Expect = @("Result: 2") }
    @{ Id = "T05"; Name = "Decimal addition 2.5 + 1.5";  Input = "1`n2.5`n1.5`n5`n";         Expect = @("Result: 4") }
    @{ Id = "T06"; Name = "Negative numbers -10 + 5";    Input = "1`n-10`n5`n5`n";           Expect = @("Result: -5") }
    @{ Id = "T07"; Name = "Division by zero 10 / 0";     Input = "4`n10`n0`n5`n";            Expect = @("Error: division by zero is not allowed.") }
    @{ Id = "T08"; Name = "Invalid menu option 9";       Input = "9`n5`n";                   Expect = @("Invalid selection: please enter a number from 1 to 5.") }
    @{ Id = "T09"; Name = "Invalid numeric input abc";   Input = "1`nabc`n5`n";              Expect = @("Error: invalid numeric input.") }
    @{ Id = "T10"; Name = "Exit with option 5";          Input = "5`n";                      Expect = @("Goodbye.") }
    @{ Id = "T11"; Name = "Decimal division 1 / 4";      Input = "4`n1`n4`n5`n";             Expect = @("Result: 0.25") }
    @{ Id = "T12"; Name = "Negative multiplication";     Input = "3`n-3.5`n2`n5`n";          Expect = @("Result: -7") }
    @{ Id = "T13"; Name = "Four calculations, one run";  Input = "1`n10`n5`n2`n10`n5`n3`n10`n5`n4`n10`n5`n5`n";
                                                         Expect = @("Result: 15", "Result: 5", "Result: 50", "Result: 2") }
    @{ Id = "T14"; Name = "Menu option 0";               Input = "0`n5`n";                   Expect = @("Invalid selection: please enter a number from 1 to 5.") }
    @{ Id = "T15"; Name = "Trailing garbage 12abc";      Input = "1`n12abc`n5`n";            Expect = @("Error: invalid numeric input.") }
    @{ Id = "T16"; Name = "Repeating decimal 10 / 3";    Input = "4`n10`n3`n5`n";            Expect = @("Result: 3.333333333") }
    @{ Id = "T17"; Name = "Empty menu input";            Input = "`n5`n";                    Expect = @("Invalid selection: please enter a number from 1 to 5.") }
    @{ Id = "T18"; Name = "End of input (no option 5)";  Input = "1`n10`n5`n";               Expect = @("Result: 15", "End of input reached.") }
    @{ Id = "T19"; Name = "Negative zero: 0 * -3";       Input = "3`n0`n-3`n5`n";            Expect = @("Result: 0") }
    @{ Id = "T20"; Name = "Overlong numeric input";      Input = "1`n" + ("1" * 140) + "`n5`n"; Expect = @("Error: invalid numeric input.") }
)

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
$results = @()
$sequence = 0

foreach ($case in $cases) {
    $sequence++
    $leaf = "$($case.Id)_$($case.Name -replace '[^A-Za-z0-9]+', '_')"
    $inFile  = Join-Path $casesDir   "$leaf.in"
    $outFile = Join-Path $resultsDir "$leaf.out"

    [System.IO.File]::WriteAllText($inFile, $case.Input)

    $output = Get-Content -Raw -Path $inFile | & $Exe @ExeArgs 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    [System.IO.File]::WriteAllText($outFile, $output)

    # Collect the real output line that carries each expected fragment.
    $outputLines = $output -split "`r?`n"
    $missing  = @()
    $observed = @()
    foreach ($fragment in $case.Expect) {
        $hit = $outputLines | Where-Object { $_.Contains($fragment) } | Select-Object -First 1
        if ($null -eq $hit) {
            $missing += $fragment
        } else {
            $text = $hit.Trim()
            # Strip the input prompts that run together only because piped
            # input is not echoed by the console.
            $prompts = @("Enter your choice: ", "Enter first number : ", "Enter second number: ")
            $stripped = $true
            while ($stripped) {
                $stripped = $false
                foreach ($p in $prompts) {
                    if ($text.StartsWith($p)) {
                        $text = $text.Substring($p.Length).Trim()
                        $stripped = $true
                    }
                }
            }
            if ($text.Length -gt 90) { $text = $text.Substring(0, 87) + "..." }
            $observed += $text
        }
    }

    $passed = ($exitCode -eq 0) -and ($missing.Count -eq 0)

    $actualLine = if ($passed) {
        ($observed -join " | ")
    } else {
        "MISSING: " + ($missing -join " / ")
    }

    $results += [pscustomobject]@{
        Id       = $case.Id
        Name     = $case.Name
        Input    = ($case.Input.TrimEnd("`n") -replace "`n", " , ")
        Expected = ($case.Expect -join " / ")
        Actual   = $actualLine
        ExitCode = $exitCode
        Passed   = $passed
        File     = $outFile
    }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Digital Calculator - automated test run"
Write-Host ("Executable : {0} {1}" -f $Exe, ($ExeArgs -join " "))
Write-Host ("Date       : {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Write-Host ""

$results | Format-Table -AutoSize Id, Name, ExitCode, Passed |
    Out-String -Width 200 | Write-Host

$failed = @($results | Where-Object { -not $_.Passed })
$passedCount = $results.Count - $failed.Count

foreach ($r in $results) {
    $flag = if ($r.Passed) { "PASS" } else { "FAIL" }
    Write-Host ("{0}  {1}" -f $r.Id, $flag)
    Write-Host ("      input    : {0}" -f $r.Input)
    Write-Host ("      expected : {0}" -f $r.Expected)
    Write-Host ("      actual   : {0}" -f $r.Actual)
}

if (-not $NoReport) {
    $reportPath = Join-Path $resultsDir "test_results.txt"
    $lines = @()
    $lines += "Digital Calculator - automated test results"
    $lines += ("Executable : {0} {1}" -f $Exe, ($ExeArgs -join " "))
    $lines += ("Date       : {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
    $lines += ("Result     : {0} passed, {1} failed, {2} total" -f $passedCount, $failed.Count, $results.Count)
    $lines += ""
    $lines += ("{0,-5} {1,-30} {2,-8} {3}" -f "ID", "Description", "Result", "Input / Expected / Actual")
    $lines += ("-" * 110)
    foreach ($r in $results) {
        $lines += ("{0,-5} {1,-30} {2,-8} {3}" -f $r.Id, $r.Name, $(if ($r.Passed) { "PASS" } else { "FAIL" }), $r.Input)
        $lines += ("{0,-5} {1,-30} {2,-8} {3}" -f "", "", "", "expected: " + $r.Expected)
        $lines += ("{0,-5} {1,-30} {2,-8} {3}" -f "", "", "", "actual  : " + $r.Actual)
    }
    [System.IO.File]::WriteAllLines($reportPath, $lines)
    Write-Host ""
    Write-Host "Detailed output files: $resultsDir"
}

Write-Host ""
Write-Host ("SUMMARY: {0} passed, {1} failed, {2} total" -f $passedCount, $failed.Count, $results.Count)

if ($failed.Count -gt 0) { exit 1 }
exit 0
