# Hardware session log — 2026-11-17 (attempted, not completed)

This is a factual record of the first attempt to run the experiments on the
physical board, made while the user was unavailable. It documents what was
achieved, what blocked the experiments, and the exact state in which the
equipment was left. **No experimental result was obtained, and none is claimed.**

## 1. Equipment state found

| Item | Observation | How it was verified |
|---|---|---|
| Board | powered, alive, sitting at the **`PMON>`** bootloader prompt | serial transcript on COM8 |
| Serial adapter | `USB-SERIAL CH340 (COM8)`, device status OK | `Get-PnpDevice`, `Get-CimInstance Win32_PnPEntity` |
| PC adapter "Ethernet" (Realtek) | link **Up, 100 Mbps**, address `169.254.158.156/16` (APIPA, DHCP enabled but no server) | `Get-NetAdapter`, `Get-NetIPAddress`, `netsh interface ipv4 show addresses` |
| PC address `192.168.1.111` | **not configured** | `Get-NetIPAddress` |
| `ping 192.168.1.123` | replies, but **not from the board**: the route goes through Wi-Fi/Clash (`128.0.0.0/1 → 198.18.0.2`), `arp -a` has no entry for it | `Find-NetRoute`, `arp -a` |
| LoongIDE | running, project `Chapter08…lxp` open, menu reachable (File/Edit/Project/Debug/Tools/Window/Help) | `GetMenu`/`GetMenuString` enumeration |
| PuTTY | present at `C:\Users\testriad\Desktop\putty_V0.63.0.0.43510830.exe` | process path |
| NetAssist V5.0.2 | **not installed** anywhere on the machine | registry uninstall keys, `where.exe`, recursive search |
| Desktop | **locked** (`LogonUI` running) → full-screen capture is black; per-window `PrintWindow` still works | screen capture test |

## 2. Serial-port findings (important)

1. `System.IO.Ports.SerialPort` (and therefore PuTTY, which configures the port
   with `SetCommState`) **cannot open this CH340**:
   * .NET → *"A device attached to the system is not functioning."*
   * PuTTY → *"Unable to open connection / COM8 / Unable to configure serial port"* (screenshot captured)
   * direct `SetCommState()` → Win32 error **31** (`ERROR_GEN_FAILURE`), reproducible
2. `CreateFile("\\.\COM8")` **succeeds**, and the port is already at
   115200 8-N-1, so raw `ReadFile`/`WriteFile` work. All console interaction in
   this session therefore used `tools/serial.ps1` (raw Win32 comm API).
3. **The RT-Thread console is not on COM8.** `ls1x-drv/include/ns16550.h:241`
   defines `ConsolePort = devUART5`, while the CH340/COM8 is the PMON/debug UART.
   The physical **UART5 9-pin connector is not connected** to the PC (no second
   CH340/PL2303 port appears in `Get-PnpDevice`). Consequently the firmware's own
   console output (`Welcome to RT-Thread.`, `GMAC0_IP is : …`,
   `succeed to bind ip!`, …) can **not** be observed until that cable is plugged
   in. This is the single most important blocker: the laboratory's PuTTY
   screenshots require it.

## 3. Firmware download paths investigated

| Path | Result |
|---|---|
| LoongIDE **Debug → Run** (GUI) | works: the IDE is drivable via `WM_COMMAND` (menu IDs: Project→Compile & Build = 59, Debug→Run = 64, Debug→Continue = 71, Debug→Stop = 72). A build produced `Build\Chapter08….exe` (1 341 140 B) and `.bin` (569 488 B) at 12:22 and again at 12:33. `Debug → Run` started `mips-sde-elf-gdb.exe --annotate=2` and the title showed `[Debugging]`. |
| LoongIDE EJTAG proxy as a gdb server | **not usable externally**: port 50000 listens, but any gdb packet (`qSupported`, `?`) causes the proxy to drop the connection |
| PMON **XMODEM** over COM8 | **works**: `xmodem base=0x80200000` plus a CRC-mode sender implemented in `tools/pmon_load.ps1` loaded the 569 480-byte image; `d4 0x80200000` returned `40806000`, i.e. the exact first instruction of the image (`00 60 80 40` little-endian) |
| PMON `g 0x80200000` | loads and starts, but PMON reports **`client return: 0`** immediately and no firmware output appears (see §4) |
| Serial DTR/RTS toggle as a reset | does not reset the board (no reboot banner) |

> Note: PMON parses numeric arguments as **decimal**; `base=80200000` loads to
> `0x04C7C140`. Always use the `0x` prefix.

## 4. Observations that remain unexplained

1. After `g 0x80200000`, PMON prints a register dump and `client return: 0`
   (transcript: `results/logs/pmon_xmodem_run_raw.txt`). `rtthread_startup()`
   only returns if the scheduler start returns, so either the kernel aborted
   very early or PMON's `g` is not equivalent to LoongIDE's launch sequence
   (LoongIDE prints `Entry address is 80200000` and starts via EJTAG).
2. With the firmware nominally started, the PC saw **no ARP reply** for
   `169.254.158.200` (`Get-NetNeighbor` state `Incomplete`/`Unreachable`) and a
   TCP connect to port 9060 timed out.
3. Because the OS console (UART5) is not connected, neither point 1 nor 2 can
   be diagnosed from the board side in the current setup.

## 5. Network blocker

* Setting the Realtek adapter to `192.168.1.111/24` requires elevation:
  `netsh interface ipv4 add address …` → *"The requested operation requires
  elevation (Run as administrator)"*; the process runs at medium integrity with
  `BUILTIN\Administrators` marked *deny only*.
* Without that address no traffic can reach `192.168.1.123`; the only route that
  matches is the Wi-Fi/Clash default route, which answers pings with a synthetic
  reply (a false positive that must not be mistaken for the board).
* Link-local addressing was evaluated as a workaround: `169.254.158.200` is
  routed **directly over the Ethernet adapter** (`169.254.0.0/16` on-link), so a
  link-local build could be tested without elevation. A variant
  (`builds/tcp_server_linklocal/`) was built for that purpose, but the run in §4
  never produced a responding board, so the test was inconclusive.

## 6. Evidence produced in this session

| File | Content |
|---|---|
| `results/logs/pmon_xmodem_run_raw.txt` | raw COM8 transcript: `flush`, `g 0x80200000`, register dump, `client return: 0` |
| `builds/tcp_server_linklocal/` | link-local variant: `.exe`, `.bin`, `.map`, the exact `main.c`/`lwip_test.c`/`lwip_test.h` used (`.linklocal`/`.snapshot`) |
| `Build/Chapter08….exe/.bin` | the image LoongIDE built itself from the current sources (12:33) |
| `tools/serial.ps1`, `tools/pmon_lib.ps1`, `tools/pmon_load.ps1` | raw-serial console access + verified XMODEM loader |
| `tools/capture_window.ps1` *(see §7)* | window capture that works on a locked desktop |

## 7. Tooling left in `tools/`

* `serial.ps1` — Win32 comm API wrapper (`Open-Board`, `Send-Board`, `Read-Board`,
  `Close-Board`), needed because .NET/PuTTY cannot configure this CH340.
* `pmon_lib.ps1` — PMON helpers: wait for prompt, CRC XMODEM sender.
* `pmon_load.ps1` — CLI: `-SelfTest`, `-Image <bin> -Run`, `-CaptureSeconds`,
  `-LogPath`.
* `capture_window.ps1` — captures a window by process name/handle with
  `PrintWindow` (works while the desktop is locked, unlike full-screen capture).

## 8. Exact state at the end of the session

* Sources restored to the official configuration (`gmac0_ip = 192.168.1.123`,
  `local_IP = 192.168.1.123`, `remote_IP = 192.168.1.111`), verified identical to
  the saved copies (0 differing lines).
* `lwip_test.h` set to `TEST_TCP_SERVER = 1` (experiment A).
* LoongIDE: no active debug session (`mips-sde-elf-gdb` not running).
* Board: **after the IDE's `Debug → Run` the board no longer answers at the
  `PMON>` prompt** (0 bytes returned to a CR), whereas it did before. That means
  PMON handed control over and the image is executing — i.e. the IDE download
  path does start the firmware, unlike PMON's `g 0x80200000`, which returns
  immediately with `client return: 0`.
  The image the IDE started was built from its own editor buffers, not from the
  link-local edits, so the running firmware is the **official** configuration
  (`192.168.1.123`) — which is exactly why no ARP reply for `169.254.158.200`
  was observed. The board is therefore most likely waiting in `accept()` on
  `192.168.1.123:9060` right now, unreachable only because the PC has no address
  in that subnet.
* PC network settings: **unchanged** (no elevation available).
* No screenshots of results exist; nothing was fabricated.

Restoring the bootloader: power-cycle the board (nothing in this session left it
in a damaged state; the load target is RAM only, the NAND/flash was never
written).

## 8b. Conclusion drawn from the session

| Question | Answer |
|---|---|
| Do the four configurations build and produce valid images? | yes (section A evidence) |
| Does the board accept a firmware image? | yes — XMODEM load verified byte-for-byte in RAM; LoongIDE's EJTAG download also works |
| Does the firmware start? | yes when started by LoongIDE (`Debug → Run`); **no** when started by PMON `g` |
| Can the four experiments be observed? | **not yet** — needs the UART5 console cable and the PC's `192.168.1.111` address |
| Is there any experimental result to report? | **no** — the CSV/report keep `NOT TESTED` |

## 9. What the next session needs

1. Connect the **9-pin serial cable to UART5**; note the new COM port. (Without
   it no console evidence is possible.)
2. Elevate once to set `192.168.1.111/255.255.255.0` on the Ethernet adapter (or
   set it manually), and close/pause Clash so it cannot answer for
   `192.168.1.123`.
3. Install NetAssist V5.0.2 (or decide to use the PowerShell peers and label the
   captures accordingly).
4. Power-cycle the board, then run each experiment with
   `tools/pmon_load.ps1`/LoongIDE, capture the console with
   `tools/capture_window.ps1`, and fill the CSV/analyses with the observations.
