# PC-side peer for the four Chapter 08 experiments.
#
# It does the job NetAssist does (TCP client / TCP server / UDP sender /
# UDP receiver) from PowerShell, prints a PASS/FAIL verdict and writes a
# transcript that can be attached as evidence.
#
#   .\pc_peer.ps1 -Experiment tcp_server      # PC = TCP client  -> board :9060
#   .\pc_peer.ps1 -Experiment tcp_client      # PC = TCP server  <- board :9061
#   .\pc_peer.ps1 -Experiment udp_server      # PC = UDP sender  -> board :9062
#   .\pc_peer.ps1 -Experiment udp_client      # PC = UDP receiver<- board :9063
#
#   .\pc_peer.ps1 -Experiment tcp_server -SelfTest   # prove the script itself works
#
# Notes
#  * Run it on the PC, not the board.
#  * Experiments B and D need the peer running *before* the board starts.
#  * The lab requires NetAssist for the screenshots; this script is a fallback
#    and its transcript must be labelled as "PC peer (PowerShell sockets)".

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('tcp_server', 'tcp_client', 'udp_server', 'udp_client')]
    [string]$Experiment,

    [string]$BoardIp = '192.168.1.123',
    [string]$PcIp = '192.168.1.111',
    [int]$Port = 0,
    [int]$Messages = 5,
    [int]$TimeoutSec = 25,
    [string]$LogPath,
    [switch]$SelfTest,
    [switch]$SkipPreflight
)

$ErrorActionPreference = 'Stop'

if ($Port -eq 0) {
    $Port = switch ($Experiment) {
        'tcp_server' { 9060 }
        'tcp_client' { 9061 }
        'udp_server' { 9062 }
        'udp_client' { 9063 }
    }
}

$BoardMac = '72-74-00-83-DE-12'
$script:lines = New-Object System.Collections.Generic.List[string]
function Say {
    param([string]$Text)
    Write-Host $Text
    $script:lines.Add($Text)
}

# ---------------------------------------------------------------- preflight ---
function Test-Preflight {
    Say "--- preflight ---"
    $ok = $true

    $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' }
    $inSubnet = $addrs | Where-Object { $_.IPAddress -like '192.168.1.*' -or $_.IPAddress -eq $PcIp }
    if ($inSubnet) {
        Say ("PC address     : {0} on '{1}'  OK" -f ($inSubnet.IPAddress -join ','), ($inSubnet.InterfaceAlias -join ','))
    }
    else {
        $ok = $false
        Say ("PC address     : NONE in 192.168.1.0/24  FAIL - set the adapter to {0}/255.255.255.0" -f $PcIp)
        Say ("                 present: {0}" -f (($addrs | ForEach-Object { "$($_.IPAddress) ($($_.InterfaceAlias))" }) -join '; '))
    }

    if ($Experiment -eq 'tcp_server' -or $Experiment -eq 'udp_server') {
        $neigh = Get-NetNeighbor -IPAddress $BoardIp -ErrorAction SilentlyContinue
        if ($neigh -and $neigh.LinkLayerAddress -and $neigh.LinkLayerAddress -ne '00-00-00-00-00-00') {
            if ($neigh.LinkLayerAddress -eq $BoardMac) {
                Say ("board ARP      : {0} -> {1}  OK (board MAC)" -f $BoardIp, $neigh.LinkLayerAddress)
            }
            else {
                Say ("board ARP      : {0} -> {1}  WARNING (expected {2})" -f $BoardIp, $neigh.LinkLayerAddress, $BoardMac)
            }
        }
        else {
            $ok = $false
            Say ("board ARP      : no entry for {0}  FAIL - board not reachable (a 'ping' reply may come from Clash/VPN!)" -f $BoardIp)
        }
    }
    Say ""
    return $ok
}

# --------------------------------------------------------------- TCP client ---
function Invoke-TcpClientPeer {
    param([string]$TargetIp, [int]$TargetPort)
    Say "mode           : PC = TCP client, board = TCP server ($TargetIp`:$TargetPort)"
    $client = New-Object System.Net.Sockets.TcpClient
    $connected = $false
    for ($attempt = 1; $attempt -le 3 -and -not $connected; $attempt++) {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($TargetIp, $TargetPort, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(5000)) {
            try { $client.EndConnect($iar); $connected = $true }
            catch { Say ("connect        : attempt {0} refused" -f $attempt) }
        }
        else { Say ("connect        : attempt {0} timeout" -f $attempt) }
        if (-not $connected) { Start-Sleep -Seconds 1 }
    }
    if (-not $connected) { throw "connect failed - is the board running the TCP server on $TargetPort?" }
    Say "connected      : $($client.Connected)"
    $stream = $client.GetStream()
    $stream.ReadTimeout = 8000

    $sent = 0; $echoed = 0
    $texts = @('hello LS1B', 'second message', 'TCP echo test 3', 'abc 123', 'last message')
    for ($i = 0; $i -lt $Messages; $i++) {
        $msg = $texts[$i % $texts.Count] + " #$($i + 1)"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($msg)
        $stream.Write($bytes, 0, $bytes.Length); $stream.Flush()
        $sent++
        Say ("SEND           : '{0}'" -f $msg)

        $buf = New-Object byte[] 512
        try { $n = $stream.Read($buf, 0, $buf.Length) } catch { $n = 0 }
        if ($n -gt 0) {
            $reply = [System.Text.Encoding]::ASCII.GetString($buf, 0, $n)
            Say ("RECV           : '{0}'" -f $reply)
            if ($reply.Trim() -eq $msg) { $echoed++; Say "                 -> echo matches (OK)" }
            else { Say "                 -> MISMATCH" }
        }
        else { Say "RECV           : <nothing> (timeout or closed)" }
        Start-Sleep -Milliseconds 150
    }
    $client.Close()
    return @{ Sent = $sent; Received = $echoed }
}

function Get-FreeTcpPort {
    $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $l.Start(); $p = $l.LocalEndpoint.Port; $l.Stop(); return $p
}
function Get-FreeUdpPort {
    $u = New-Object System.Net.Sockets.UdpClient(0)
    $p = $u.Client.LocalEndPoint.Port; $u.Close(); return $p
}

# --------------------------------------------------------------- TCP server ---
function Invoke-TcpServerPeer {
    param([string]$LocalIp, [int]$LocalPort, [int]$WaitSeconds = 0)
    if ($WaitSeconds -le 0) { $WaitSeconds = $TimeoutSec }
    Say "mode           : PC = TCP server on $LocalIp`:$LocalPort (start this BEFORE the board)"
    $bindAddr = if ($LocalIp -eq '127.0.0.1') { [System.Net.IPAddress]::Loopback } else { [System.Net.IPAddress]::Parse($LocalIp) }
    $listener = New-Object System.Net.Sockets.TcpListener($bindAddr, $LocalPort)
    $listener.Start()
    Say "listening      : yes"
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    $client = $null
    while (-not $client -and (Get-Date) -lt $deadline) {
        if ($listener.Pending()) { $client = $listener.AcceptTcpClient() }
        else { Start-Sleep -Milliseconds 200 }
    }
    if (-not $client) { $listener.Stop(); throw "no connection from the board within $TimeoutSec s" }
    $peer = $client.Client.RemoteEndPoint
    Say "accepted       : $peer"
    $stream = $client.GetStream()
    $stream.ReadTimeout = 8000

    $received = 0; $replied = 0
    $buffer = ''
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ($received -lt $Messages -and (Get-Date) -lt $deadline) {
        $buf = New-Object byte[] 512
        try { $n = $stream.Read($buf, 0, $buf.Length) } catch { $n = 0 }
        if ($n -le 0) { break }
        $chunk = [System.Text.Encoding]::ASCII.GetString($buf, 0, $n)
        $buffer += $chunk
        while ($buffer -match "([^\n]*\n)") {
            $line = $Matches[1]
            $buffer = $buffer.Substring($line.Length)
            $line = $line.Trim()
            if (-not $line) { continue }
            $received++
            Say ("RECV           : '{0}'" -f $line)
            $reply = [System.Text.Encoding]::ASCII.GetBytes("ack $received")
            $stream.Write($reply, 0, $reply.Length); $stream.Flush()
            $replied++
            Say ("SEND           : 'ack {0}'" -f $received)
        }
    }
    $client.Close(); $listener.Stop()
    if ($received -lt $Messages) { Say ("note           : only {0} of {1} messages arrived" -f $received, $Messages) }
    return @{ Sent = $replied; Received = $received }
}

# ---------------------------------------------------------------- UDP sender ---
function Invoke-UdpSenderPeer {
    param([string]$TargetIp, [int]$TargetPort)
    Say "mode           : PC = UDP sender, board = UDP echo endpoint ($TargetIp`:$TargetPort)"
    $udp = New-Object System.Net.Sockets.UdpClient(0)
    $udp.Client.ReceiveTimeout = 5000
    $endpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse($TargetIp), $TargetPort)
    $sent = 0; $echoed = 0
    for ($i = 0; $i -lt $Messages; $i++) {
        $msg = "udp hello #$($i + 1)"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($msg)
        [void]$udp.Send($bytes, $bytes.Length, $endpoint)
        $sent++
        Say ("SEND           : '{0}'" -f $msg)
        try {
            $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
            $reply = $udp.Receive([ref]$remote)
            $text = [System.Text.Encoding]::ASCII.GetString($reply)
            Say ("RECV           : '{0}' from {1}" -f $text, $remote)
            if ($text -eq $msg) { $echoed++ }
        }
        catch { Say "RECV           : <timeout>" }
        Start-Sleep -Milliseconds 150
    }
    $udp.Close()
    return @{ Sent = $sent; Received = $echoed }
}

# -------------------------------------------------------------- UDP receiver ---
function Invoke-UdpReceiverPeer {
    param([string]$LocalIp, [int]$LocalPort, [int]$WaitSeconds = 0)
    if ($WaitSeconds -le 0) { $WaitSeconds = $TimeoutSec }
    Say "mode           : PC = UDP receiver on $LocalIp`:$LocalPort (start this BEFORE the board)"
    $bindAddr = if ($LocalIp -eq '127.0.0.1') { [System.Net.IPAddress]::Loopback } else { [System.Net.IPAddress]::Parse($LocalIp) }
    $udp = New-Object System.Net.Sockets.UdpClient((New-Object System.Net.IPEndPoint($bindAddr, $LocalPort)))
    $udp.Client.ReceiveTimeout = 6000
    Say "bound          : yes"
    $received = 0; $replied = 0
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ($received -lt $Messages -and (Get-Date) -lt $deadline) {
        try {
            $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
            $data = $udp.Receive([ref]$remote)
            $text = [System.Text.Encoding]::ASCII.GetString($data)
            $received++
            Say ("RECV           : '{0}' from {1}" -f $text, $remote)
            $ack = [System.Text.Encoding]::ASCII.GetBytes("udp ack $received")
            [void]$udp.Send($ack, $ack.Length, $remote)
            $replied++
            Say ("SEND           : 'udp ack {0}' -> {1}" -f $received, $remote)
        }
        catch {
            if ((Get-Date) -lt $deadline) { Say "RECV           : <timeout>" }
            break
        }
    }
    $udp.Close()
    if ($received -lt $Messages) { Say ("note           : only {0} of {1} datagrams arrived" -f $received, $Messages) }
    return @{ Sent = $replied; Received = $received }
}

# ------------------------------------------------------------------ self test ---
function Invoke-SelfTest {
    Say "--- SELF TEST (loopback: proves this script's logic, not the board) ---"
    $results = @()
    $selfTimeout = 10

    # 1. TCP client logic against a loopback echo server
    $echoPort = Get-FreeTcpPort
    $job = Start-Job -ScriptBlock {
        param($port)
        $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
        try {
            $l.Start()
            $c = $l.AcceptTcpClient(); $s = $c.GetStream()
            $buf = New-Object byte[] 512
            while (($n = $s.Read($buf, 0, $buf.Length)) -gt 0) {
                $s.Write($buf, 0, $n); $s.Flush()
            }
            $c.Close()
        } finally { $l.Stop() }
    } -ArgumentList $echoPort
    Start-Sleep -Milliseconds 900
    $results += Invoke-TcpClientPeer -TargetIp '127.0.0.1' -TargetPort $echoPort
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    # 2. TCP server logic against a loopback client that sends N lines
    $srvPort = Get-FreeTcpPort
    $srvJob = Start-Job -ScriptBlock {
        param($port, $n)
        $c = New-Object System.Net.Sockets.TcpClient
        for ($try = 0; $try -lt 30; $try++) {
            try { $c.Connect('127.0.0.1', $port); break } catch { Start-Sleep -Milliseconds 200 }
        }
        $s = $c.GetStream()
        for ($i = 1; $i -le $n; $i++) {
            $b = [System.Text.Encoding]::ASCII.GetBytes("client ticks = $i.`n")
            $s.Write($b, 0, $b.Length); $s.Flush()
            $buf = New-Object byte[] 64
            [void]$s.Read($buf, 0, $buf.Length)
            Start-Sleep -Milliseconds 100
        }
        $c.Close()
    } -ArgumentList $srvPort, $Messages
    Start-Sleep -Milliseconds 300
    $results += Invoke-TcpServerPeer -LocalIp '127.0.0.1' -LocalPort $srvPort -WaitSeconds $selfTimeout
    Remove-Job $srvJob -Force -ErrorAction SilentlyContinue

    # 3. UDP sender logic against a loopback echo endpoint
    $udpEchoPort = Get-FreeUdpPort
    $udpJob = Start-Job -ScriptBlock {
        param($port)
        $u = $null
        for ($try = 0; $try -lt 30 -and -not $u; $try++) {
            try { $u = New-Object System.Net.Sockets.UdpClient($port) } catch { Start-Sleep -Milliseconds 200 }
        }
        if (-not $u) { return }
        $u.Client.ReceiveTimeout = 8000
        try {
            for ($i = 0; $i -lt 15; $i++) {
                $r = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                $d = $u.Receive([ref]$r)
                [void]$u.Send($d, $d.Length, $r)
            }
        } finally { $u.Close() }
    } -ArgumentList $udpEchoPort
    Start-Sleep -Milliseconds 900
    $results += Invoke-UdpSenderPeer -TargetIp '127.0.0.1' -TargetPort $udpEchoPort
    Remove-Job $udpJob -Force -ErrorAction SilentlyContinue

    # 4. UDP receiver logic against a loopback sender
    $udpRcvPort = Get-FreeUdpPort
    $udpSnd = Start-Job -ScriptBlock {
        param($port)
        $u = New-Object System.Net.Sockets.UdpClient(0)
        for ($i = 1; $i -le 25; $i++) {
            $b = [System.Text.Encoding]::ASCII.GetBytes("client ticks = $i.")
            try { [void]$u.Send($b, $b.Length, (New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Loopback, $port))) } catch { }
            Start-Sleep -Milliseconds 120
        }
        $u.Close()
    } -ArgumentList $udpRcvPort
    Start-Sleep -Milliseconds 900
    $results += Invoke-UdpReceiverPeer -LocalIp '127.0.0.1' -LocalPort $udpRcvPort -WaitSeconds $selfTimeout
    Remove-Job $udpSnd -Force -ErrorAction SilentlyContinue

    Say ""
    $i = 0
    $names = @('tcp client (exp A logic)', 'tcp server (exp B logic)', 'udp sender (exp C logic)', 'udp receiver (exp D logic)')
    foreach ($r in $results) {
        $ok = ($r.Received -ge 5 -and $r.Sent -ge 5)
        Say ("self-test {0} {1}: sent={2} received={3} -> {4}" -f $i, $names[$i], $r.Sent, $r.Received, $(if ($ok) { 'PASS' } else { 'FAIL' }))
        $i++
    }
}

# --------------------------------------------------------------------- main ---
if ($LogPath) {
    $dir = Split-Path -Parent $LogPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

Say "=== Chapter 08 PC peer: $Experiment ==="
Say ("time           : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

try {
    if ($SelfTest) {
        Invoke-SelfTest
    }
    else {
        $pre = if ($SkipPreflight) { $true } else { Test-Preflight }
        $stats = switch ($Experiment) {
            'tcp_server' { Invoke-TcpClientPeer -TargetIp $BoardIp -TargetPort $Port }
            'tcp_client' { Invoke-TcpServerPeer -LocalIp $PcIp -LocalPort $Port }
            'udp_server' { Invoke-UdpSenderPeer -TargetIp $BoardIp -TargetPort $Port }
            'udp_client' { Invoke-UdpReceiverPeer -LocalIp $PcIp -LocalPort $Port }
        }
        Say ""
        Say "--- verdict ---"
        Say ("sent           : {0}" -f $stats.Sent)
        Say ("received       : {0}" -f $stats.Received)
        $pass = ($stats.Received -ge $Messages -and $stats.Sent -ge $Messages)
        Say ("result         : {0}" -f $(if ($pass) { 'PASS - communication demonstrated' } else { 'FAIL - no complete exchange' }))
        if (-not $pre) { Say "note           : preflight reported problems, see above" }
    }
}
catch {
    Say ""
    Say ("ERROR          : {0}" -f $_.Exception.Message)
    Say "result         : FAIL - no communication"
}
finally {
    if ($LogPath) {
        [System.IO.File]::WriteAllLines($LogPath, $script:lines, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "transcript     : $LogPath"
    }
}
