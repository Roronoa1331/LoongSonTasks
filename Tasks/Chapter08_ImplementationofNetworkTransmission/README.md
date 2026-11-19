# Chapter 08 — Implementation of Network Transmission (Loongson 1B)

Laboratory work of *Computer System Comprehensive Design Experiment*, built on a
Loongson 1B (LS1B200) board running RT-Thread 4.0.2 with the lwIP 1.4.1 stack.
Four firmware variants exercise TCP and UDP in both roles (server / client):

| # | Experiment | Board role | Board address | PC role | PC address |
|---|------------|-----------|---------------|---------|------------|
| A | TCP server | TCP server | `192.168.1.123:9060` | TCP client | `192.168.1.111` |
| B | TCP client | TCP client | `192.168.1.123` | TCP server | `192.168.1.111:9061` |
| C | UDP server | UDP echo endpoint | `192.168.1.123:9062` | UDP sender | `192.168.1.111` |
| D | UDP client | UDP sender | `192.168.1.123` | UDP receiver | `192.168.1.111:9063` |

Subnet mask on both sides: `255.255.255.0`, gateway `192.168.1.1`, interface
GMAC0.

## Directory layout

```
Chapter08_ImplementationofNetworkTransmission/
├── main.c                    entry point: lwIP + GMAC0 init, then start one demo
├── lwip_test.h               IPs, ports, buffer sizes, the four TEST_* switches
├── lwip_test.c               local_IP / remote_IP strings
├── tcp_server.c              demo A (guarded by TEST_TCP_SERVER)
├── tcp_client.c              demo B (guarded by TEST_TCP_CLIENT)
├── udp_server.c              demo C (guarded by TEST_UDP_SERVER)
├── udp_client.c              demo D (guarded by TEST_UDP_CLIENT)
├── ld.script                 linker script (image loaded at 0x80200000)
├── include/                  bsp.h (BSP_USE_GMAC0 …), rtconfig.h, board headers
├── RTT4/                     RT-Thread 4.0.2 kernel + Loongson 1B BSP + port
├── lwIP-1.4.1/               lwIP stack + Loongson 1B port (ls1x_ethernetif.c)
├── ls1x-drv/                 SoC drivers (GMAC, UART, NAND, …)
├── yaffs2/                   NAND file system
├── builds/                   ← added: reproducible multi-configuration build
│   ├── Makefile              generic GNU make file (EXP=<experiment>)
│   ├── build.ps1             sets the macros, builds, logs, keeps every image
│   └── tcp_server/ … udp_client/   per-experiment obj/, .exe, .bin, snapshots
├── results/                  evidence: logs, analyses, report, CSV
└── reference_screenshots/    reference examples only – never experiment evidence
```

## Building

Prerequisites (already present on the lab machine):

* LoongIDE MIPS toolchain `E:\LoongIDE\mips-2015.05\bin` (`mips-sde-elf-gcc`)
* GNU make from MSYS `C:\msys\1.0\bin`

From PowerShell in this directory:

```powershell
cd builds
.\build.ps1 -Experiment tcp_server     # experiment A
.\build.ps1 -Experiment tcp_client     # experiment B
.\build.ps1 -Experiment udp_server     # experiment C
.\build.ps1 -Experiment udp_client     # experiment D
.\build.ps1 -Experiment all -Clean     # all four, from scratch
```

The script

1. rewrites the four `TEST_*` macros in `lwip_test.h` (exactly one is `1`) and
   refuses to build an inconsistent state,
2. stores the header that was used as `builds/<experiment>/lwip_test.h.snapshot`,
3. compiles every project source into `builds/<experiment>/obj`,
4. links with `ld.script` and produces `builds/<experiment>/<experiment>.exe`
   (ELF, the file LoongIDE downloads) and `<experiment>.bin` (raw image),
5. writes `results/logs/build_<experiment>.log` and
   `builds/<experiment>/build_info.txt` (result, sizes, SHA-256).

Because every experiment has its own directory, no image can be confused with
another experiment's image. The lwIP stack, RT-Thread and the drivers are
compiled in every configuration — only the `#if (TEST_xxx)` blocks inside the
four demo files are active.

LoongIDE remains usable: open
`Chapter08_ImplementationofNetworkTransmission.lxp`, *Project → Compile & Build*
and *Debug → Run*. The macros in `lwip_test.h` are what selects the experiment,
so run `build.ps1` (or edit the header) before building inside LoongIDE.

## Running an experiment

The complete, click-by-click procedure is in
[results/reports/hardware_test_guide.md](results/reports/hardware_test_guide.md).
Short version:

1. Connect board ↔ PC with an Ethernet cable, connect the board's UART5 to the
   PC with the USB-serial cable, connect the Mini-USB download cable, power on.
2. PuTTY → Serial, the board's COM port, **115200 8-N-1**, open.
3. Set the PC Ethernet adapter to `192.168.1.111 / 255.255.255.0`.
4. Build the wanted experiment (`build.ps1 -Experiment …`), download it with
   LoongIDE (*Debug → Run*).
5. Configure NetAssist as described for that experiment and exchange data.

## Evidence and reports

| Path | Content |
|------|---------|
| `results/logs/build_*.log` | compiler output of all four configurations |
| `results/logs/experiment_results.csv` | per-experiment tracking (hardware rows start as `NOT TESTED`) |
| `results/screenshots/` | genuine captures (see the README in that folder for the required names) |
| `results/analysis/*.md` | one analysis per experiment + TCP/UDP comparison + defect log |
| `results/reports/` | laboratory report, hardware test guide |
| `reference_screenshots/` | reference examples supplied by the course — **not** results |

**Status:** the code, the four configurations and all four firmware images are
built and verified. A hardware attempt on 2026-11-17 reached the board's PMON
bootloader, verified XMODEM loading and a LoongIDE build, but could not run the
experiments: the firmware console (UART5) is not cabled, the PC address
`192.168.1.111` needs one elevation, and NetAssist is not installed. See
[results/logs/hardware_session_2026-11-17.md](results/logs/hardware_session_2026-11-17.md).
Every document marks the hardware results as pending instead of inventing them.

## `tools/` — board access from the command line

| Script | Purpose |
|---|---|
| `serial.ps1` | raw Win32 serial access to COM8 (`Open-Board`/`Send-Board`/`Read-Board`); .NET `SerialPort` and PuTTY cannot configure this CH340 (`SetCommState` error 31) |
| `pmon_lib.ps1` | PMON helpers: wait for the prompt, CRC-XMODEM sender |
| `pmon_load.ps1` | `-SelfTest`, or load `-Image x.bin` to `0x80200000` and `-Run` it |
| `capture_window.ps1` | capture one window to PNG with `PrintWindow` (works even with the desktop locked) |
| `pc_peer.ps1` | PC-side peer for all four experiments (TCP client/server, UDP send/receive) with preflight checks, PASS/FAIL verdict and a transcript — use it if NetAssist is unavailable, or as a second opinion. Self-test: `.\pc_peer.ps1 -Experiment tcp_server -SelfTest` |
