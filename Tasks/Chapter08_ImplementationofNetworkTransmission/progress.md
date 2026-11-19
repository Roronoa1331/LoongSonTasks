# Progress tracker — Chapter 08 network transmission

Last update: 2026-11-17 12:55 (+08:00) — after the first hardware attempt
(see `results/logs/hardware_session_2026-11-17.md`)

Legend: **DONE** = finished and verified · **PENDING** = not started or waiting for
hardware · **BLOCKED** = waiting for something outside this machine.

## Phase status

| Phase | Content | State | Evidence / next action |
|---|---|---|---|
| 1 | Inspect project, sources, configuration, build system | **DONE** | 189 C/S units in `Chapter08…lxp` matched against the files on disk; `main.c`, `lwip_test.h`, four demo files, `bsp.h`, `rtconfig.h`, `lwipopts.h`, `ls1x_ethernetif.c`, `ld.script` reviewed |
| 2 | Fix verified defects, prepare the four configurations | **DONE** | six defects fixed (D1–D6), three documented without change (D7–D9) — `results/analysis/source_defects_and_fixes.md` |
| 3 | Build and verify all four configurations | **DONE** | 4/4 SUCCESS, per-experiment directories, SHA-256 recorded — `results/logs/build_*.log`, `builds/*/build_info.txt` |
| 4 | Prepare hardware and network test instructions | **DONE** | `results/reports/hardware_test_guide.md` (cabling → PuTTY → PC address → per-experiment NetAssist settings → troubleshooting) |
| 5 | Experiment A — TCP server on hardware | **BLOCKED** | board reached at its PMON prompt, but the RT-Thread console is on UART5, which is **not cabled**; PC address needs elevation. See `results/logs/hardware_session_2026-11-17.md` |
| 6 | Experiment B — TCP client on hardware | **BLOCKED** | same two blockers |
| 7 | Experiment C — UDP server on hardware | **BLOCKED** | same two blockers |
| 8 | Experiment D — UDP client on hardware | **BLOCKED** | same two blockers |
| 9 | Analysis documents, CSV, report | **DONE (structure)** / **PENDING (results)** | four analyses, comparison, report written with `NOT TESTED` where evidence is missing |
| 10 | Final submission checks | **PENDING** | `FINAL_SUBMISSION_CHECKLIST.md` — the evidence-dependent rows cannot be ticked yet |

## Task list

| # | Task | State |
|---|---|---|
| 1 | Read and understand the project (main, header, four demos, BSP config) | DONE |
| 2 | Confirm toolchain availability (`mips-sde-elf-gcc` 4.9.2, MSYS make) | DONE |
| 3 | Create reproducible build system (`builds/Makefile`, `builds/build.ps1`) | DONE |
| 4 | Fix D1 `ls1x_ethernetif.c` if/else syntax error | DONE |
| 5 | Fix D2 `main.c` missing `bsp.h` (network init compiled out) | DONE |
| 6 | Fix D3 `accept()` argument cast in `tcp_server.c` | DONE |
| 7 | Fix D4 uninitialised `fromlen` in both UDP files | DONE |
| 8 | Fix D5 missing standard headers in the four demos and `main.c` | DONE |
| 9 | Fix D6 leading-space file names + `.lxp` entries | DONE |
| 10 | Build A `tcp_server` | DONE (SUCCESS, 122 s) |
| 11 | Build B `tcp_client` | DONE (SUCCESS, 124 s) |
| 12 | Build C `udp_server` | DONE (SUCCESS, 130 s) |
| 13 | Build D `udp_client` | DONE (SUCCESS, 163 s) |
| 14 | Verify each image contains only its own demo entry point | DONE (`nm` per image) |
| 15 | Write hardware test guide | DONE |
| 16 | Write analysis documents + TCP/UDP comparison | DONE |
| 17 | Write laboratory report | DONE (hardware sections marked pending) |
| 18 | Write evidence inventory and submission checklist | DONE |
| 19 | Run experiment A on the board | PENDING — needs the student |
| 20 | Run experiment B on the board | PENDING — needs the student |
| 21 | Run experiment C on the board | PENDING — needs the student |
| 22 | Run experiment D on the board | PENDING — needs the student |
| 23 | Insert real screenshots and observed console text into analyses/report/CSV | PENDING — depends on 19–22 |

## Current state of the tree

* `lwip_test.h` is left set to `TEST_TCP_SERVER = 1` (experiment A) so that a
  LoongIDE build right now produces the TCP-server firmware.
* The four firmware images from the verification builds are kept in
  `builds/<experiment>/` together with their header snapshots and SHA-256.

## Next action

The 2026-11-17 hardware attempt established that the board is alive at its
`PMON>` prompt and that firmware can be loaded over XMODEM, but two environment
problems stop the experiments and can only be fixed by the operator:

1. **Plug the 9-pin serial cable into UART5** (the firmware console is on UART5,
   not on the CH340/COM8 port used by PMON). Without it the board prints nothing
   visible.
2. **Set the Ethernet adapter to `192.168.1.111/24`** (needs one elevation) and
   close/pause Clash, which currently answers `192.168.1.123` with a synthetic
   reply.
3. Install NetAssist V5.0.2 (or accept the PowerShell peers, labelled as such).

Full detail, including the serial/ch340 defect and the LoongIDE command IDs:
`results/logs/hardware_session_2026-11-17.md`.

## Session log summary (2026-11-17)

| Attempted | Outcome |
|---|---|
| Read board console on COM8 | works only with raw Win32 comm API (`tools/serial.ps1`); .NET and PuTTY fail with `SetCommState` error 31 |
| Load firmware via PMON XMODEM | **success** — image verified in RAM (`d4 0x80200000` → `40806000`) |
| Start firmware with PMON `g` | PMON immediately reports `client return: 0`; no visible output (console is on UART5) |
| Build/run through LoongIDE | **workable** — menu IDs found (Compile & Build 59, Run 64, Continue 71, Stop 72); build produced `Build/*.exe`/`.bin`; `Debug → Run` starts `mips-sde-elf-gdb` |
| Ping 192.168.1.123 | **false positive** (Wi-Fi/Clash route), not the board |
| Link-local workaround (169.254.158.200) | variant built in `builds/tcp_server_linklocal/`; board did not answer ARP, test inconclusive |
| Reset the board from the host | not possible (no DTR/RTS wiring, no watchdog access) → each firmware needs a power cycle |
