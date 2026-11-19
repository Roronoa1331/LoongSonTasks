# Evidence inventory

Everything listed under "Present" exists in this repository and was produced by
this work. Everything under "Missing" must still be captured during the hardware
session; nothing may be substituted with a reference image or a re-creation.

## 1. Build evidence (present)

| File | Purpose |
|---|---|
| `results/logs/build_tcp_server.log` | full compiler/linker output of experiment A, with the macro state used |
| `results/logs/build_tcp_client.log` | same for experiment B |
| `results/logs/build_udp_server.log` | same for experiment C |
| `results/logs/build_udp_client.log` | same for experiment D |
| `builds/tcp_server/build_info.txt` | result, ELF/binary sizes, SHA-256, durations for A |
| `builds/tcp_client/build_info.txt` | same for B |
| `builds/udp_server/build_info.txt` | same for C |
| `builds/udp_client/build_info.txt` | same for D |
| `builds/tcp_server/lwip_test.h.snapshot` | exact header that produced image A |
| `builds/tcp_client/lwip_test.h.snapshot` | … image B |
| `builds/udp_server/lwip_test.h.snapshot` | … image C |
| `builds/udp_client/lwip_test.h.snapshot` | … image D |
| `builds/<experiment>/<experiment>.exe` | ELF image, the file LoongIDE downloads |
| `builds/<experiment>/<experiment>.bin` | raw binary image |
| `builds/<experiment>/<experiment>.map` | linker map (symbol → address), useful for `addr2line` |
| `builds/<experiment>/obj/` | per-experiment object files, proof that the four builds never share state |
| `builds/Makefile`, `builds/build.ps1` | the build definition itself (reproducibility) |
| `builds/tcp_server_linklocal/` | link-local variant (IP `169.254.158.200`) built for the 2026-11-17 network workaround attempt, with the exact sources used (`.linklocal`, `.snapshot`) |
| `Build/` | the image LoongIDE generated itself when driven through its own menu commands (2026-11-17) |

Build facts (2026-11-17): A 10:44:54 / 122 s, B 10:46:58 / 124 s,
C 10:49:07 / 130 s, D 10:51:51 / 163 s — all `SUCCESS`.

## 1b. Hardware-session evidence (present, no results)

| File | Content |
|---|---|
| `results/logs/hardware_session_2026-11-17.md` | full factual log of the first hardware attempt, blockers and exact end state |
| `results/logs/pmon_xmodem_run_raw.txt` | raw COM8 transcript of `flush` / `g 0x80200000` / register dump / `client return: 0` |
| `tools/serial.ps1` | raw Win32 serial access (needed: .NET and PuTTY cannot configure this CH340) |
| `tools/pmon_lib.ps1`, `tools/pmon_load.ps1` | PMON prompt handling + verified CRC-XMODEM loader |
| `tools/capture_window.ps1` | per-window capture with `PrintWindow` (works on a locked desktop) |
| `tools/pc_peer.ps1` | PC-side peer for all four experiments with preflight checks, verdict and transcript; loopback self-test verified (`-SelfTest`: 4/4 PASS) |

## 2. Configuration evidence (present)

| File | Purpose |
|---|---|
| `lwip_test.h` | current macro state (experiment A) |
| `builds/*/lwip_test.h.snapshot` | per-experiment macro state |
| `main.c`, `tcp_server.c`, `tcp_client.c`, `udp_server.c`, `udp_client.c` | the four implementations with the repaired defects |
| `results/analysis/source_defects_and_fixes.md` | defect list with the compiler output that proves each one |

## 3. Screenshots — missing (must be captured on the hardware)

| File | Experiment | Shown |
|---|---|---|
| `results/screenshots/network_configuration.png` | all | PC adapter with `192.168.1.111 / 255.255.255.0` |
| `results/screenshots/tcp_server_putty.png` | A | board console: `GMAC0_IP is : 192.168.1.123`, `succeed to listen!`, `client incoming succeed!`, `RECEIVE:`/`SEND:` |
| `results/screenshots/tcp_server_netassist.png` | A | NetAssist **TCP Client** → `192.168.1.123:9060`, sent text and echo |
| `results/screenshots/tcp_client_putty.png` | B | board console: `succeed to connect to server!`, five `SEND:`/`RECEIVE:` pairs, `tcp_client_thread stop!` |
| `results/screenshots/tcp_client_netassist.png` | B | NetAssist **TCP Server** on `192.168.1.111:9061` with the board's connection |
| `results/screenshots/udp_server_putty.png` | C | board console: `succeed to bind ip!`, `RECEIVE:`/`SEND:` |
| `results/screenshots/udp_server_netassist.png` | C | NetAssist **UDP**, remote `192.168.1.123:9062`, datagram + echo |
| `results/screenshots/udp_client_putty.png` | D | board console: five `SEND:`/`RECEIVE:` pairs, `udp_client_thread stop!` |
| `results/screenshots/udp_client_netassist.png` | D | NetAssist **UDP**, local port `9063`, received datagrams and the replies |

Optional but useful: `arp -a` output showing `192.168.1.123` ↔
`72-74-00-83-de-12`, and any failed attempt that was troubleshot (with a suffix,
e.g. `tcp_server_putty_attempt2.png`).

## 4. Reference material (present, never evidence)

| File | Purpose |
|---|---|
| `reference_screenshots/README.md` | provenance of the reference figures and what each one shows |
| `reference_screenshots/manual_fig8.5_tcp_server_netassist.png` | guide Figure 8.5 — NetAssist TCP Client for experiment A |
| `reference_screenshots/manual_fig8.6_tcp_server_putty.png` | guide Figure 8.6 — PuTTY console for experiment A |
| `reference_screenshots/manual_fig8.7_tcp_client_netassist.png` | guide Figure 8.7 — NetAssist TCP Server for experiment B |
| `reference_screenshots/manual_fig8.8_tcp_client_putty.png` | guide Figure 8.8 — PuTTY console for experiment B |
| `reference_screenshots/manual_fig8.9_udp_server_netassist.png` | guide Figure 8.9 — NetAssist UDP mode for experiment C |
| `reference_screenshots/manual_fig8.10_udp_server_putty.png` | guide Figure 8.10 — PuTTY console for experiment C |
| `reference_screenshots/manual_fig8.11_udp_client_netassist.png` | guide Figure 8.11 — NetAssist UDP mode for experiment D |
| `reference_screenshots/manual_fig8.12_udp_client_putty.png` | guide Figure 8.12 — PuTTY console for experiment D |

Provenance: extracted from `word/media/image71.png … image78.png` of
`Computer_System_Comprehensive_Design_Experiment_Guide_EN （图）.docx`; the caption
→ image mapping was verified by walking the document body. The four TCP figures
(8.5–8.8) are the "four TCP reference screenshots" of the assignment. They were
taken by the course author (RT-Thread 4.0.3, `COM8`, 2022-03-02) and must never
be presented as this project's results.

## 5. Documents (present)

| File | Content |
|---|---|
| `README.md` | project overview, layout, build and run instructions |
| `progress.md` | phase/task status |
| `FINAL_SUBMISSION_CHECKLIST.md` | submission verification list |
| `results/reports/Loongson_1B_Network_Transmission_Laboratory_Report.md` | the laboratory report (16 sections) |
| `results/reports/hardware_test_guide.md` | click-by-click hardware procedure |
| `results/analysis/tcp_server_analysis.md` … `udp_client_analysis.md` | one analysis per experiment |
| `results/analysis/tcp_vs_udp_comparison.md` | protocol comparison, textbook vs project facts vs observations |
| `results/analysis/source_defects_and_fixes.md` | every defect with its evidence |
| `results/logs/experiment_results.csv` | results tracking; hardware rows are `NOT TESTED` |
| `results/screenshots/README.md` | naming rules for the genuine captures |

## 6. Traceability rules applied

1. Every claim in the report that is not verifiable in the repository is marked
   `NOT TESTED` or `expected`.
2. The CSV, the four analyses and section 12 of the report always carry the same
   values; they are updated together.
3. A screenshot is only filed when it was produced during a real run; missing
   captures are listed as missing, never simulated.
