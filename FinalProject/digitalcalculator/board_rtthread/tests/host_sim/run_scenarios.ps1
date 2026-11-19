<#
    run_scenarios.ps1
    ------------------------------------------------------------------------
    Builds Chapter 7's main.c against the host RT-Thread simulator for a set
    of scenarios, runs every scenario, and verifies the sleeping-barber
    invariants from the produced trace.

    Usage (from this folder):
        powershell -ExecutionPolicy Bypass -File .\run_scenarios.ps1
#>

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$gcc = 'gcc'
$out = Join-Path $PSScriptRoot 'out'
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

$scenarios = @(
    @{ Name = 'S1_zero_customers';      Customers = 0;  Chairs = 3;  Note = 'no customer at all: the barber sleeps forever' },
    @{ Name = 'S2_one_customer';        Customers = 1;  Chairs = 3;  Note = 'a single customer wakes the sleeping barber' },
@{ Name = 'S3_one_customer_one_chair'; Customers = 1; Chairs = 1; Note = 'single chair shop, single customer' },
@{ Name = 'S4_three_customers';     Customers = 3;  Chairs = 3;  Note = 'arrivals fit exactly into the waiting room' },
@{ Name = 'S5_five_three_chairs';   Customers = 5;  Chairs = 3;  Note = 'guide default: waiting room overflows (Figure 7.14)' },
@{ Name = 'S6_five_five_chairs';    Customers = 5;  Chairs = 5;  Note = 'enough chairs: nobody is turned away' },
@{ Name = 'S7_twenty_one_chair';    Customers = 20; Chairs = 1;  Note = 'long run with a full waiting room (single chair)' },
@{ Name = 'S8_twenty_ten_chairs';   Customers = 20; Chairs = 10; Note = 'long run, half of the customers are seated' },
@{ Name = 'S9_twenty_twenty_chairs';Customers = 20; Chairs = 20; Note = 'long run, a chair for everybody' }
)

function Invoke-Scenario($scenario)
{
    $exe = Join-Path $out ($scenario.Name + '.exe')
    $appobj = Join-Path $out ($scenario.Name + '.app.o')
    $hostobj = Join-Path $out ($scenario.Name + '.host.o')
    $simobj = Join-Path $out 'rtthread_sim.o'
    $defs = @("-Dcustomer_num=$($scenario.Customers)", "-DWAITING_CHAIRS=$($scenario.Chairs)")

    & $gcc -O1 -Wall -I. $defs -Dmain=app_main -c '..\..\main.c' -o $appobj
    if ($LASTEXITCODE -ne 0) { throw "compile of main.c failed for $($scenario.Name)" }

    & $gcc -O1 -Wall -I. $defs -c main_host.c -o $hostobj
    if ($LASTEXITCODE -ne 0) { throw "compile of the harness failed for $($scenario.Name)" }

    if (-not (Test-Path $simobj)) {
        & $gcc -O1 -Wall -I. -c rtthread_sim.c
        if ($LASTEXITCODE -ne 0) { throw 'compile of the simulator failed' }
        Move-Item -Force 'rtthread_sim.o' $simobj
    }

    & $gcc $simobj $hostobj $appobj -o $exe
    if ($LASTEXITCODE -ne 0) { throw "link failed for $($scenario.Name)" }

    $traceFile = Join-Path $out ($scenario.Name + '.log')
    $trace = & $exe 2>&1 | Out-String
    $trace | Set-Content -Path $traceFile -Encoding utf8
    $exit = $LASTEXITCODE

    $served   = ([regex]::Matches($trace, 'barber finish cut hair\.')).Count
    $seated   = ([regex]::Matches($trace, 'is waitting to cut hair\.')).Count
    $left     = ([regex]::Matches($trace, 'customers \d+ leave\.')).Count
    $found    = ([regex]::Matches($trace, 'barber find customer')).Count
    $busy     = ([regex]::Matches($trace, 'barber begin to cut hair\.')).Count
    $chairVals = [regex]::Matches($trace, 'freeseats=(\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
    $seatedIds = [regex]::Matches($trace, 'customers (\d+) is waitting') | ForEach-Object { $_.Groups[1].Value }
    $leftIds   = [regex]::Matches($trace, 'customers (\d+) leave\.')     | ForEach-Object { $_.Groups[1].Value }
    $allIds    = @($seatedIds) + @($leftIds)

    $problems = @()

    if ($exit -ne 0)                                  { $problems += "simulator exit code $exit" }
    if ($trace -notmatch 'VERDICT: PASS')             { $problems += 'harness verdict was not PASS' }
    if ($served -ne $seated)                          { $problems += "haircuts ($served) != seated customers ($seated)" }
    if ($found -ne $seated)                           { $problems += "barber accepted $found but $seated customers sat down" }
    if ($busy -ne $served)                            { $problems += "begin haircut ($busy) != finish haircut ($served)" }
    if (($seated + $left) -ne $scenario.Customers)    { $problems += "seated ($seated) + turned away ($left) != $($scenario.Customers) customers" }
    if ($scenario.Customers -gt 0 -and $seated -eq 0) { $problems += 'no customer was ever served' }
    if ($scenario.Customers -eq 0 -and $seated -ne 0) { $problems += 'a customer was served although none was created' }
    if ($scenario.Chairs -ge $scenario.Customers -and $left -ne 0) {
        $problems += "$left customer(s) turned away although $($scenario.Chairs) chairs were available"
    }

    # customer numbers must be unique: nobody may be both seated and turned away
    $dup = @($allIds | Group-Object | Where-Object { $_.Count -gt 1 })
    if ($dup.Count -gt 0)                             { $problems += "customer number(s) handled twice: $($dup.Name -join ',')" }

    # no arrival may ever push the waiting room over its capacity
    foreach ($v in $chairVals) {
        if ($v -lt 0 -or $v -gt ($scenario.Chairs - 1)) { $problems += "invalid freeseats value $v (capacity $($scenario.Chairs))" }
    }
    if ($trace -notmatch 'threads still blocked      : 1') { $problems += 'not exactly one thread blocked at the end' }

    [pscustomobject]@{
        Scenario   = $scenario.Name
        Customers  = $scenario.Customers
        Chairs     = $scenario.Chairs
        Seated     = $seated
        TurnedAway = $left
        Haircuts   = $served
        Switches   = if ($trace -match 'context switches           : (\d+)') { $Matches[1] } else { '?' }
        SimMs      = if ($trace -match 'simulated time             : (\d+)') { $Matches[1] } else { '?' }
        Result     = if ($problems.Count -eq 0) { 'PASS' } else { 'FAIL' }
        Detail     = if ($problems.Count -eq 0) { $scenario.Note } else { ($problems -join '; ') }
    }
}

$results = foreach ($s in $scenarios) { Invoke-Scenario $s }

# ---- repeatability: the same build must produce the identical trace every time
$repExe = Join-Path $out 'S5_five_three_chairs.exe'
$reference = & $repExe 2>&1 | Out-String
$identical = $true
for ($i = 0; $i -lt 9; $i++) {
    $again = & $repExe 2>&1 | Out-String
    if ($again -ne $reference) { $identical = $false }
}
$results += [pscustomobject]@{
    Scenario   = 'S5_repeated_10_times'
    Customers  = 5
    Chairs     = 3
    Seated     = 3
    TurnedAway = 2
    Haircuts   = 3
    Switches   = if ($reference -match 'context switches           : (\d+)') { $Matches[1] } else { '?' }
    SimMs      = if ($reference -match 'simulated time             : (\d+)') { $Matches[1] } else { '?' }
    Result     = if ($identical) { 'PASS' } else { 'FAIL' }
    Detail     = if ($identical) { 'ten consecutive runs produced identical traces' } else { 'traces differ between runs' }
}

$results | Format-Table -AutoSize | Out-String -Width 220 | Write-Host

$failed = @($results | Where-Object { $_.Result -ne 'PASS' })
Write-Host ("{0} of {1} scenarios passed." -f ($results.Count - $failed.Count), $results.Count)

if ($failed.Count -gt 0) {
    exit 1
}
exit 0
