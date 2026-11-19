# PMON helpers for the Loongson 1B: wait for the boot prompt, XMODEM transfer,
# load a raw image to RAM, optionally start it.
# Requires tools/serial.ps1 (dot-source it first).

$script:ACK = 0x06; $script:NAK = 0x15; $script:CAN = 0x18; $script:EOT = 0x04
$script:SOH = 0x01; $script:SUB = 0x1A

$script:crcTable = New-Object int[] 256
for ($i = 0; $i -lt 256; $i++) {
    $c = $i -shl 8
    for ($j = 0; $j -lt 8; $j++) {
        if ($c -band 0x8000) { $c = (($c -shl 1) -bxor 0x1021) -band 0xFFFF } else { $c = ($c -shl 1) -band 0xFFFF }
    }
    $script:crcTable[$i] = $c -band 0xFFFF
}

function Get-Crc16 {
    param([byte[]]$Data, [int]$Offset, [int]$Count)
    $crc = 0
    for ($i = $Offset; $i -lt ($Offset + $Count); $i++) {
        $crc = (($crc -shl 8) -bxor $script:crcTable[(($crc -shr 8) -bxor $Data[$i]) -band 0xFF]) -band 0xFFFF
    }
    return $crc
}

function Read-PmonUntil {
    param([string]$Pattern, [int]$TimeoutMs = 8000)
    $sb = New-Object System.Text.StringBuilder
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        $chunk = [BoardSerial]::Read(120)
        if ($chunk) {
            [void]$sb.Append($chunk)
            if ($sb.ToString() -match $Pattern) { return $sb.ToString() }
        }
    }
    return $sb.ToString()
}

function Wait-PmonPrompt {
    param([int]$TimeoutMs = 8000)
    [void]([BoardSerial]::Read(300))
    [BoardSerial]::Write("`r")
    $text = Read-PmonUntil -Pattern 'PMON>' -TimeoutMs $TimeoutMs
    return ($text -match 'PMON>')
}

function Send-Xmodem {
    param([byte[]]$Payload, [int]$Block = 1024)

    $mode = ''
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt 20000) {
        $b = [BoardSerial]::ReadByte(500)
        if ($b -eq 0x43) { $mode = 'crc'; break }
        if ($b -eq $script:NAK) { $mode = 'sum'; break }
    }
    if (-not $mode) { throw "receiver did not request a transfer (no 'C'/NAK)" }
    Write-Host "  xmodem handshake: $mode mode, block size $Block"

    $total = [math]::Ceiling($Payload.Length / $Block)
    $swRun = [System.Diagnostics.Stopwatch]::StartNew()
    for ($n = 1; $n -le $total; $n++) {
        $off = ($n - 1) * $Block
        $chunk = New-Object byte[] $Block
        $len = [math]::Min($Block, $Payload.Length - $off)
        [Array]::Copy($Payload, $off, $chunk, 0, $len)
        for ($k = $len; $k -lt $Block; $k++) { $chunk[$k] = $script:SUB }

        $frame = New-Object System.Collections.Generic.List[byte]
        $frame.Add($(if ($Block -eq 128) { $script:SOH } else { 0x02 }))
        $frame.Add([byte]($n -band 0xFF))
        $frame.Add([byte]((255 - ($n -band 0xFF)) -band 0xFF))
        foreach ($x in $chunk) { $frame.Add($x) }
        if ($mode -eq 'crc') {
            $crc = Get-Crc16 $chunk 0 $Block
            $frame.Add([byte](($crc -shr 8) -band 0xFF))
            $frame.Add([byte]($crc -band 0xFF))
        } else {
            $sum = 0; foreach ($x in $chunk) { $sum += $x }
            $frame.Add([byte]($sum -band 0xFF))
        }

        $attempt = 0
        while ($true) {
            [BoardSerial]::WriteBytes($frame.ToArray())
            $resp = [BoardSerial]::ReadByte(15000)
            if ($resp -eq $script:ACK) { break }
            if ($resp -eq $script:CAN) { throw "receiver cancelled at block $n" }
            $attempt++
            if ($attempt -ge 10) { throw "no ACK for block $n after 10 attempts (got $resp)" }
            Write-Host "  retransmit block $n"
        }
        if (($n % 100) -eq 0 -or $n -eq $total) {
            Write-Host ("  block {0}/{1}  ({2:P0})" -f $n, $total, ($n / $total))
        }
    }

    for ($i = 0; $i -lt 10; $i++) {
        [BoardSerial]::WriteBytes([byte[]]@($script:EOT))
        $resp = [BoardSerial]::ReadByte(5000)
        if ($resp -eq $script:ACK) { break }
        if ($i -eq 9) { throw "no ACK for EOT (last response $resp)" }
    }
    Write-Host ("  transfer complete: {0} bytes in {1:N0} s" -f $Payload.Length, $swRun.Elapsed.TotalSeconds)
}
