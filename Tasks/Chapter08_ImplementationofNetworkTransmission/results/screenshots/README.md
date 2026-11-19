# Required screenshots (real evidence only)

Every file placed here must be a genuine capture taken while running the
experiment on the Loongson 1B board. Reference/example images belong in
`../../reference_screenshots/`, never here.

## Required files

| File name                     | What it must show                                                                 |
|-------------------------------|-----------------------------------------------------------------------------------|
| `network_configuration.png`   | Windows `Ethernet` adapter IPv4 settings (`192.168.1.111`, mask `255.255.255.0`)  |
| `tcp_server_netassist.png`    | NetAssist in **TCP Client** mode connected to `192.168.1.123:9060`, sent text and received echo |
| `tcp_server_putty.png`        | PuTTY console of the board showing the TCP-server log (`succeed to bind ip!`, `RECEIVE:`/`SEND:`) |
| `tcp_client_netassist.png`    | NetAssist in **TCP Server** mode listening on `192.168.1.111:9061` with the board's messages and the reply |
| `tcp_client_putty.png`        | PuTTY console showing the five `SEND:` / `RECEIVE:` cycles and `tcp_client_thread stop!` |
| `udp_server_netassist.png`    | NetAssist in **UDP** mode, remote `192.168.1.123:9062`, datagram sent and echo received |
| `udp_server_putty.png`        | PuTTY console showing `succeed to bind ip!` plus `RECEIVE:`/`SEND:` for the UDP server |
| `udp_client_netassist.png`    | NetAssist in **UDP** mode, local port `9063`, showing the board's datagrams and the reply sent |
| `udp_client_putty.png`        | PuTTY console showing the five `SEND:`/`RECEIVE:` cycles of the UDP client |

## Rules

1. One screenshot per row above; keep the given file names exactly.
2. Do not crop away the window title, the NetAssist protocol selector or the
   PuTTY window title: they are what proves which tool and which mode was used.
3. Never edit, retouch or re-create an image. If a capture is missing, the
   corresponding line in `../logs/experiment_results.csv` stays `NOT TESTED`
   and the report marks the experiment as pending.
4. Additional captures (for example `arp -a` output or a failed attempt being
   troubleshot) are welcome; name them with a suffix, e.g.
   `tcp_server_arp.png`, `tcp_client_putty_attempt2.png`.
