# Final submission checklist

Status: **not yet submittable** — every row in section B needs the hardware run,
and section C depends on B. Rows marked `[x]` were verified on 2026-11-17.

## A. Software and build (verifiable without hardware)

- [x] `main.c` includes `bsp.h`/`rtthread.h`, so `BSP_USE_GMAC0` is defined and the
      lwIP/GMAC0 initialisation is compiled in (defect D2 fixed).
- [x] `lwIP-1.4.1/port/ls1x_ethernetif.c` compiles (`else`/`if` structure fixed, D1).
- [x] `tcp_server.c` `accept()` call uses `socklen_t addrlen` + `&addrlen` (D3).
- [x] Both UDP files initialise `fromlen` and use `sockaddr_in` (D4).
- [x] No compiler warning from `main.c`, `lwip_test.h`, `lwip_test.c`,
      `tcp_server.c`, `tcp_client.c`, `udp_server.c`, `udp_client.c`
      (checked in all four logs).
- [x] `udp_server.c` / `udp_client.c` no longer carry a leading space; the `.lxp`
      `FileName=` entries were updated and the unit list matches the disk.
- [x] Four mutually exclusive macro configurations exist and each was snapshotted:
      `builds/*/lwip_test.h.snapshot` shows exactly one `TEST_*` at `1`.
- [x] All four configurations build: A/B/C/D = `SUCCESS`
      (`results/logs/build_*.log`).
- [x] Each firmware contains only its own demo entry point
      (`nm`: `tcp_server_init` / `tcp_client_init` / `udp_server_init` /
      `udp_client_init`), and `main` calls `ls1x_initialize_lwip` first.
- [x] IP addresses are consistent everywhere: board `192.168.1.123`,
      PC `192.168.1.111`, mask `255.255.255.0`, gateway `192.168.1.1`
      (`main.c`, `lwip_test.c`, `rtconfig.h`, `ls1x_ethernetif.c`).
- [x] Ports are consistent everywhere: TCP 9060 (board) / 9061 (PC),
      UDP 9062 (board) / 9063 (PC) — `lwip_test.h` + each demo.
- [x] TCP and UDP are not confused in the documentation: the manual's "TCP Server"
      (8.2.14) and "TCP UDP" (8.2.15) typos are called out and UDP mode is used.

## B. Hardware experiments (needs board, cables, PuTTY, NetAssist)

**Attempted 2026-11-17 while the operator was unavailable** — details in
`results/logs/hardware_session_2026-11-17.md`. Verified during that attempt:

- [x] Board is powered and alive: it answers at its `PMON>` bootloader prompt on COM8.
- [x] Firmware can be transferred: 569 480 bytes loaded by XMODEM and verified in
      RAM (`d4 0x80200000` → `40806000` = first instruction of the image).
- [x] LoongIDE builds the project itself (`Build/…exe` 1 341 140 B, `.bin` 569 488 B)
      and `Debug → Run` starts `mips-sde-elf-gdb`.
- [ ] **UART5 console cable** — the firmware console is `devUART5`
      (`ns16550.h:241`), which is **not connected**; COM8 is the PMON/debug UART.
      Without it no board output can be captured.
- [ ] **PC address `192.168.1.111/24`** — cannot be set without elevation; the
      current APIPA address cannot reach `192.168.1.123`, and Clash/Wi-Fi answers
      that address synthetically (false positive).
- [ ] NetAssist V5.0.2 not installed.
- [ ] Board reset between experiments — no software reset path exists; each
      firmware needs a power cycle.
- [ ] PC adapter verified at `192.168.1.111/24` (screenshot
      `network_configuration.png`).
- [ ] Board boots, console shows `Clock_mask: …` and `GMAC0_IP is : 192.168.1.123`.
- [ ] `ping 192.168.1.123` succeeds, `arp -a` shows `72-74-00-83-de-12`.
- [ ] **A** TCP server: `succeed to listen!`, `client incoming succeed!`, echo seen
      in NetAssist; screenshots `tcp_server_putty.png`, `tcp_server_netassist.png`.
- [ ] **B** TCP client: five `SEND:`/`RECEIVE:` pairs, `tcp_client_thread stop!`;
      screenshots `tcp_client_putty.png`, `tcp_client_netassist.png`.
- [ ] **C** UDP server: `succeed to bind ip!`, `RECEIVE:`/`SEND:` for the datagram;
      screenshots `udp_server_putty.png`, `udp_server_netassist.png`.
- [ ] **D** UDP client: five `SEND:`/`RECEIVE:` pairs, `udp_client_thread stop!`;
      screenshots `udp_client_putty.png`, `udp_client_netassist.png`.

## C. Documentation consistency (after B)

- [ ] `results/logs/experiment_results.csv`: fill `Execution_Status`,
      `Communication_Status`, `Messages_Sent`, `Responses_Received`,
      `Successful_Exchanges`, `Screenshot_Files` from the real runs.
- [ ] The four `results/analysis/*_analysis.md`: replace "NOT TESTED" with the
      observed console text and the screenshot references.
- [ ] `results/analysis/tcp_vs_udp_comparison.md`: move the `[E]` items from
      "pending" to observed statements.
- [ ] `results/reports/…Laboratory_Report.md` §7–§10, §12, §16: insert the observed
      results and the screenshot appendix entries.
- [ ] `progress.md`: mark phases 5–10 as done.
- [ ] `evidence_inventory.md`: move the nine screenshots from "missing" to
      "present".
- [ ] No experiment is marked successful without a screenshot; no reference image
      is cited as a result; the eight reference figures (guide 8.5–8.12) stay in
      `reference_screenshots/` only.

## D. Packaging

- [ ] Open the report and skim all 16 sections for consistency with the CSV.
- [ ] Confirm the deliverables exist in the project directory:
      `README.md`, `progress.md`, `evidence_inventory.md`,
      `FINAL_SUBMISSION_CHECKLIST.md`, `results/reports/*.md`,
      `results/analysis/*.md`, `results/logs/*`, `results/screenshots/*`.
- [ ] Keep `builds/` (images + logs). Optionally delete `builds/*/obj` to shrink
      the submission — the `.exe`, `.bin`, `.map`, logs and snapshots are enough
      to prove the build.
- [ ] Report the board's serial port number and the Windows adapter name used, so
      the examiner can reproduce the setup.
