# Hardware test guide — sections 8.2.10 … 8.2.15

Follow this guide in order. Every step states exactly what to do and what you
must observe before continuing. Nothing in this guide has been executed yet;
the "expected" texts are derived from the source code, the boxes marked
**RECORD** are the places where real evidence is attached.

Tools: **PuTTY** (serial console), **NetAssist V5.0.2 / 网络调试助手** (TCP/UDP),
**LoongIDE** (compile & download). Do not substitute other programs — the report
cites these two by name.

---

## 0. What you need on the desk

| Item | Purpose |
|------|---------|
| Loongson 1B development board + power supply | device under test |
| Ethernet cable (Cat-5, direct PC↔board or through a switch) | network link, GMAC0 |
| USB-to-9-pin-serial cable connected to **UART5** | console output (115200) |
| Mini-USB cable | download/debug (LoongIDE `Debug → Run`) |
| Windows PC with LoongIDE 3.x, PuTTY, NetAssist V5.0.2 | host |

Addresses used everywhere:

| Device | IP | Mask | Gateway | Interface |
|--------|----|------|---------|-----------|
| Loongson 1B board | `192.168.1.123` | `255.255.255.0` | `192.168.1.1` | GMAC0 |
| Windows PC | `192.168.1.111` | `255.255.255.0` | `192.168.1.1` | Ethernet |

Ports: TCP server `9060`, TCP client `9061`, UDP server `9062`, UDP client `9063`.

---

## 1. Cabling (8.2.10 steps 1–3)

1. Plug the Ethernet cable into the board's RJ-45 socket (GMAC0) and into the PC.
2. Plug the 9-pin serial cable into the board connector marked **UART5**, USB end
   into the PC.
3. Plug the Mini-USB cable into the board and the PC (this is the download path).

**Do not power the board yet.**

---

## 2. Find the COM port

PowerShell:

```powershell
Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'COM\d+' } |
    Select-Object Name
```

Note the `COMx` that belongs to the USB-serial cable (commonly `COM3`–`COM8`).
**RECORD**: this number goes into the report.

---

## 3. PuTTY (console)

* *Session → Connection type*: **Serial**
* *Serial line*: the `COMx` from step 2
* *Speed*: **115200**
* *Connection → Serial*: data bits 8, stop bits 1, parity None, flow control
  **None**, then **Open**

A black window opens. Nothing is printed until the board runs.

---

## 4. Power on and read the boot log (8.2.10 step 4–5)

Switch the board on. Expect, in this order (`_` marks the line the guide's own
Figure 8.6/8.8 shows, i.e. the expected form — not a capture of this run):

```
Entry address is 80200000
Clock_mask: 8000, step=…
 \ | /
- RT -     Thread Operating System
 / | \     4.0.3 build …
 2006 - 2019 Copyright by rt-thread team

Welcome to RT-Thread.

GMAC0_IP is : 192.168.1.123
detect phy address == 17
msh />GMAC0: SPEED=100M, DUPLEX=FULL, LINK=UP. AN=YES.

GMAC0 controller initialized.
```

`Clock_mask: 8000, step=…` comes from `Clock_initialize()` and proves that the
timer interrupt chain is alive; `detect phy address == 17` and the
`GMAC0: SPEED=100M, DUPLEX=FULL, LINK=UP. AN=YES.` line prove that the PHY was
found and the cable is linked. `msh />` is the RT-Thread/finsh shell, which means
the serial chain and the download are working.

`GMAC0_IP is : 192.168.1.123` is printed by the repaired
`ls1x_initialize_lwip()` (defects D1/D2): if it is missing, the running image is
not built from the fixed source.

The exact wording of some later lines differs between editions of the BSP
(`succeed` / `success` / `succed`); this project prints `succeed …`.

**RECORD** the exact first lines (they contain the build timestamp).

---

## 5. PC network configuration (8.2.11)

Check first, change only if needed:

```powershell
Get-NetIPConfiguration
Get-NetAdapter
```

Look at the adapter that owns the cable ("Ethernet"). If it already carries
`192.168.1.111/24`, skip the change.

To set it (only with your confirmation — this is a system-wide change):

```powershell
# adapt the interface alias if it is not "Ethernet"
# The gateway 192.168.1.1 (as the manual specifies) is only needed if a router
# exists in that subnet; for a direct cable to the board it can be omitted.
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.1.111 -PrefixLength 24 `
    -DefaultGateway 192.168.1.1
```

or through the GUI: *Settings → Network & Internet → Ethernet → Change adapter
options → Ethernet → right-click → Properties → Internet Protocol Version 4
(TCP/IPv4) → Properties → "Use the following IP address"*:
IP `192.168.1.111`, mask `255.255.255.0`, gateway `192.168.1.1`.

The guide also asks you to disable other adapters (Wi-Fi, VPN) so that traffic is
forced onto the Ethernet link. Disabling Wi-Fi is optional here because
`192.168.1.0/24` is usually not routed over Wi-Fi, but do it if
`ping 192.168.1.123` resolves through another interface.

**RECORD**: screenshot `results/screenshots/network_configuration.png`.

---

## 6. Build and download the experiment

On the PC, for experiment A:

```powershell
cd C:\Users\testriad\Desktop\LoongSonExamples\Chapter08_ImplementationofNetworkTransmission\builds
.\build.ps1 -Experiment tcp_server
```

This sets `TEST_TCP_SERVER 1` (others 0), builds, and leaves
`builds/tcp_server/tcp_server.exe`.

Download with LoongIDE: *File → Open Project* →
`Chapter08_ImplementationofNetworkTransmission.lxp`, then
*Project → Compile & Build*, then *Debug → Run*. LoongIDE rebuilds with the
macros currently in `lwip_test.h` and starts the program on the board.

> Always confirm the macro block before building:
> ```powershell
> Select-String ..\lwip_test.h -Pattern '^#define\s+TEST_'
> ```

---

## 7. Experiment A — TCP server (8.2.12)

**Board**: TCP server `192.168.1.123:9060`. **PC**: TCP client.

1. After the download the PuTTY console must show (the boot banner, then):

   ```
   Welcome to RT-Thread.
   GMAC0_IP is : 192.168.1.123
   detect phy address == 17
   msh />GMAC0: SPEED=100M, DUPLEX=FULL, LINK=UP. AN=YES.

   GMAC0 controller initialized.
   succeed to create sock_fd!
   succeed to bind ip!
   succeed to listen!
   waiting for client access!
   ```

   `GMAC0_IP is : 192.168.1.123` is the message restored by defect fixes D1/D2;
   if it is missing, the firmware is not the fixed one. If
   `GMAC0: SPEED=… LINK=UP` is missing or reports a down link, check the cable.

2. Verify the link from the PC:

   ```powershell
   ping 192.168.1.123
   arp -a
   ```

   Expect four replies and an entry mapping `192.168.1.123` to the board MAC
   address `72-74-00-83-de-12` (hard-coded in `ls1x_ethernetif.c`).

3. NetAssist: **Protocol type = TCP Client**; *Remote host IP* `192.168.1.123`;
   *Remote port* `9060`; click **Connect**.

4. PuTTY must add: `client incoming succeed!`

5. In NetAssist's send box type `Hello LS1B` and click **Send**.

6. Expect on the board console:

   ```
   RECEIVE: Hello LS1B
       SEND: Hello LS1B
   ```

   and the same text arriving back in NetAssist's receive window (echo).

**RECORD**: `tcp_server_putty.png`, `tcp_server_netassist.png`.

Pass criteria: the echoed bytes in NetAssist are identical to the sent bytes, and
the board log shows both `RECEIVE:` and `SEND:` for the same text.

---

## 8. Experiment B — TCP client (8.2.13)

**Board**: TCP client → PC server `192.168.1.111:9061`.

1. Rebuild: `.\build.ps1 -Experiment tcp_client`, download again.
2. NetAssist **first**: *Protocol type = TCP Server*; *Local host IP*
   `192.168.1.111`; *Local port* `9061`; **Connect** (listen).
3. Then start the board (or press reset) — the board connects out:
   PuTTY shows

   ```
   succeed to create sock_fd!
   succeed to connect to server!
   SEND: client ticks = 1234.
     RECEIVE: <whatever NetAssist sends>
   ```

   The line is repeated five times, then `tcp_client_thread stop!`.
   `client ticks` is the 1 ms tick counter (`Clock_driver_ticks`), so the numbers
   are milliseconds since boot.
4. In NetAssist, answer each incoming message (type text, **Send**). The board
   prints it after `RECEIVE:`.

Without a reply the board stays in `recv()` forever — that is expected for a
blocking socket; it is not a failure of the experiment as long as the five
`SEND:` lines appear and at least one `RECEIVE:` is answered.

**RECORD**: `tcp_client_putty.png`, `tcp_client_netassist.png`.

---

## 9. Experiment C — UDP server (8.2.14) — note the manual's typo

The manual says "*Protocol type: TCP Server*" and gives the PC the port `9062`.
That is wrong: `udp_server.c` uses `SOCK_DGRAM` + `recvfrom()`/`sendto()` and
binds `192.168.1.123:9062` on the board. Use **UDP** mode.

1. Rebuild: `.\build.ps1 -Experiment udp_server`, download.
2. PuTTY shows `succeed to create sock_fd!`, `succeed to bind ip!` (no `listen`
   line — UDP has no connection).
3. NetAssist: **Protocol type = UDP**; *Local host port* `9062` (as in the
   guide's Figure 8.9; any free port also works); *Remote host IP*
   `192.168.1.123`; *Remote port* `9062`; **Connect**.
4. Send `UDP hello`.
5. PuTTY: `RECEIVE: UDP hello` / `    SEND: UDP hello`; NetAssist receives the
   same datagram back from `192.168.1.123:9062`.

**RECORD**: `udp_server_putty.png`, `udp_server_netassist.png`.

---

## 10. Experiment D — UDP client (8.2.15)

1. Rebuild: `.\build.ps1 -Experiment udp_client`, download.
2. NetAssist **first**: **Protocol type = UDP**; *Local host IP* `192.168.1.111`;
   *Local port* `9063`; **Connect**.
3. The board starts sending immediately after boot:

   ```
   succeed to create sock_fd!
   SEND: client ticks = 2345.
     RECEIVE: <your reply>
   ```

   five cycles, then `udp_client_thread stop!`.
4. Reply in NetAssist with any text and **Send** (to `192.168.1.123`, source
   port `9063`). The board prints it after `RECEIVE:`.

UDP is connectionless: nothing is "connected", the board simply sends a datagram
to `192.168.1.111:9063` and waits for a datagram back. If NetAssist is not
listening on `9063` yet, the datagrams are silently discarded — that is why
NetAssist must be started first.

**RECORD**: `udp_client_putty.png`, `udp_client_netassist.png`.

---

## 10b. If NetAssist is not installed — PowerShell peer

`tools/pc_peer.ps1` performs the PC side of every experiment, checks the
prerequisites, prints a PASS/FAIL verdict and writes a transcript that can be
attached as evidence (label it *"PC peer (PowerShell sockets)"*, not NetAssist).

```powershell
cd <project>\tools
.\pc_peer.ps1 -Experiment tcp_server                         # exp A: PC = TCP client
.\pc_peer.ps1 -Experiment tcp_client                         # exp B: PC = TCP server (start first!)
.\pc_peer.ps1 -Experiment udp_server                         # exp C: PC = UDP sender
.\pc_peer.ps1 -Experiment udp_client                         # exp D: PC = UDP receiver (start first!)

# optional: transcript + non-default addresses
.\pc_peer.ps1 -Experiment udp_client -LogPath ..\results\logs\udp_client_pc_peer.txt

# sanity check of the script itself, no board needed
.\pc_peer.ps1 -Experiment tcp_server -SelfTest
```

The self-test was verified on this machine: all four modes exchanged five
messages over loopback.

Preflight warnings it prints are meaningful:

* `PC address : NONE in 192.168.1.0/24` → set the adapter to `192.168.1.111`.
* `board ARP : no entry for 192.168.1.123` → the board is not reachable; a
  successful `ping` at that moment is a false positive (Clash/VPN).

## 11. Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Nothing in PuTTY | wrong COM port / cable in the wrong header / 115200 wrong | re-check step 2–3, use UART5 |
| `GMAC0_IP is : …` missing | firmware built from the un-fixed source or a stale image | rebuild with `build.ps1`, download again |
| `failed to bind ip!` | another demo already bound the port, or the macro set does not match the role | check the four `TEST_*` macros; reset the board |
| `ping 192.168.1.123` fails | PC not in `192.168.1.0/24`, cable/Wi-Fi choice, board not running | `Get-NetIPConfiguration`, disable other adapters |
| TCP `Connect` in NetAssist refused | board is not in TCP-server mode, or `waiting for client access!` absent | verify build/experiment, reset board |
| Board sends nothing (client demos) | NetAssist not listening on the right port before the board boots | start NetAssist first, then reset the board |
| Datagrams lost | UDP, no retransmission | normal; resend, or check the PC firewall |
| Board stuck after 5 cycles | demo thread has ended by design | reset to repeat |

---

## 12. Evidence checklist

For every experiment, two screenshots (NetAssist + PuTTY) and one entry in
`results/logs/experiment_results.csv`. Screenshots go to
`results/screenshots/` with the names listed in
`results/screenshots/README.md`. Nothing is marked as passed until the capture
exists.
