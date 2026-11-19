# Loongson 1B Network Transmission Laboratory Report

**Course:** Computer System Comprehensive Design Experiment
**Chapter 8:** Implementation of Network Transmission (sections 8.2.1 – 8.2.15)
**Board:** Loongson 1B (LS1B200) · RT-Thread 4.0.2 · lwIP 1.4.1
**Date of this report:** 2026-11-17
**Evidence cut-off:** build results are complete and verified; the hardware runs of
sections 8.2.12 – 8.2.15 are **pending** and are marked as such throughout.

---

## 1. Experiment title

Implementation of TCP and UDP network transmission on a Loongson 1B embedded
platform running RT-Thread with the lwIP protocol stack — TCP server, TCP client,
UDP server (echo) and UDP client.

## 2. Experiment objectives

1. Configure the Loongson 1B GMAC0 interface and start the lwIP stack from an
   RT-Thread application.
2. Implement a **TCP server** on the board (port 9060) that accepts one
   connection at a time and echoes the received bytes.
3. Implement a **TCP client** on the board that connects to a PC server
   (port 9061), performs five send/receive cycles and closes the connection.
4. Implement a **UDP echo endpoint** on the board (port 9062) driven by
   `recvfrom`/`sendto`.
5. Implement a **UDP sender** on the board that sends five datagrams to a PC
   receiver (port 9063) and processes the replies.
6. Compare the two transports and explain, from the observed behaviour, the
   difference between a connection-oriented byte stream and connectionless
   datagrams.
7. Produce reproducible build artefacts, a step-by-step hardware procedure and an
   evidence trail for every claim in this report.

## 3. Experimental environment

| Layer | Component |
|-------|-----------|
| Board | Loongson 1B development platform, LS1B200, MIPS32 little-endian, soft-float |
| CPU clock source | 24 MHz crystal (`CPU_XTAL_FREQUENCY` in `include/bsp.h`) |
| RTOS | RT-Thread 4.0.2, pre-emptive, `RT_TICK_PER_SECOND = 1000` (1 ms tick) |
| Network stack | lwIP 1.4.1, socket + netconn API, no DHCP (static IPv4) |
| Network driver | on-chip GMAC0, `lwIP-1.4.1/port/ls1x_ethernetif.c` + `ls1x-drv/gmac/ls1x_gmac.c` |
| Storage (unused by these tests) | NAND + yaffs2, still linked because `BSP_USE_NAND`/`USE_YAFFS2` are enabled |
| Toolchain | SDE Lite 4.9.2 for MIPS, `mips-sde-elf-gcc` 4.9.2 at `E:\LoongIDE\mips-2015.05\bin` |
| Build driver | GNU make 3.81 (MSYS) + `builds/build.ps1` (this work) |
| IDE / download | LoongIDE (open `.lxp`, *Compile & Build*, *Debug → Run*) |
| Serial console | PuTTY, serial, 115200 bit/s, 8 data bits, no parity, 1 stop bit, no flow control |
| Network tool | NetAssist V5.0.2 (网络调试助手), TCP and UDP modes |
| Host | Windows PC, Ethernet adapter set to `192.168.1.111/24` |

## 4. Hardware and software

### 4.1 Hardware

* Loongson 1B board with GMAC0 PHY and RJ-45 socket; board MAC address
  `72:74:00:83:DE:12` (hard-coded as `ls1x_gmac0_mac_addr` in
  `lwIP-1.4.1/port/ls1x_ethernetif.c`).
* UART5 (NS16550-compatible) used as the console at 115200 bit/s.
* Mini-USB port for the LoongIDE download/debug channel.
* Cat-5 Ethernet cable PC ↔ board (direct or through a switch).
* Power supply.

### 4.2 Software (source of truth: the project itself)

| File | Role |
|------|------|
| `main.c` | includes `bsp.h`/`rtthread.h`, calls `ls1x_initialize_lwip(gmac0_ip, NULL)` and then exactly one `*_init()` demo |
| `lwip_test.h` | `TEST_TCP_SERVER` / `TEST_TCP_CLIENT` / `TEST_UDP_SERVER` / `TEST_UDP_CLIENT`, ports 9060–9063, 256-byte buffers |
| `lwip_test.c` | `local_IP = "192.168.1.123"`, `remote_IP = "192.168.1.111"` |
| `tcp_server.c` | experiment A |
| `tcp_client.c` | experiment B |
| `udp_server.c` | experiment C |
| `udp_client.c` | experiment D |
| `include/bsp.h` | enables `BSP_USE_GMAC0`, `BSP_USE_NAND`, console UARTs; derives `USE_LWIP`, `USE_YAFFS2` |
| `include/rtconfig.h` | RT-Thread configuration, `RT_LWIP_*` settings, static address `192.168.1.123` |
| `lwIP-1.4.1/port/include/lwipopts.h` | `TCP_MSS = 1460`, `MEM_SIZE = 32 KiB`, `LWIP_SOCKET`/`LWIP_NETCONN` on, DHCP and DNS off, `ETH_PAD_SIZE = 2` |
| `ld.script` | image loaded at `0x80200000`, entry `start` |
| `builds/Makefile`, `builds/build.ps1` | added by this work: one output directory per experiment |

### 4.3 Version control of the build

All four experiments compile from the same 189 translation units; the choice is
made by the four macros alone. `builds/build.ps1` rewrites the macros, refuses
inconsistent combinations, snapshots the header next to the image and logs
everything, so the artefact and its configuration cannot drift apart.

## 5. Network topology

```
        +---------------------------+           Cat-5 / RJ-45            +---------------------+
        |   Loongson 1B (LS1B200)   |  GMAC0  <=====================>  |  Windows PC         |
        |  RT-Thread 4.0.2 + lwIP   |                                   |  NetAssist V5.0.2   |
        |  192.168.1.123 / 24       |                                   |  192.168.1.111 / 24 |
        +---------------------------+                                   +---------------------+
             |            |                                                      |
      UART5  |            | Mini-USB                                   PuTTY serial |
             v            v                                                      v
        +-----------------------------------------------------+      (115200 8-N-1)
        |  USB-serial adapter  |  LoongIDE download/debug     |
        +-----------------------------------------------------+
```

Logical endpoints used by the four experiments:

| Experiment | Board endpoint | PC endpoint | Transport |
|---|---|---|---|
| A | `192.168.1.123:9060` (listening) | `192.168.1.111:<ephemeral>` | TCP |
| B | `192.168.1.123:<ephemeral>` | `192.168.1.111:9061` (listening) | TCP |
| C | `192.168.1.123:9062` (bound) | `192.168.1.111:9062` (local port, as in Figure 8.9) | UDP |
| D | `192.168.1.123:<ephemeral>` | `192.168.1.111:9063` (bound) | UDP |

## 6. Network configuration

| Parameter | Board (GMAC0) | PC (Ethernet) |
|---|---|---|
| IPv4 address | `192.168.1.123` | `192.168.1.111` |
| Subnet mask | `255.255.255.0` | `255.255.255.0` |
| Default gateway | `192.168.1.1` | `192.168.1.1` |
| Setting source | `gmac0_ip[4] = {192, 168, 1, 123}` in `main.c`, passed to `ls1x_initialize_lwip()`; netmask and gateway are derived inside that function (`255.255.255.0`, `…1.1`) | Windows adapter properties / `New-NetIPAddress` |

Verification commands used on the PC (read-only ones may be run freely):

```powershell
ipconfig /all
Get-NetIPConfiguration
ping 192.168.1.123
arp -a
```

The board prints its own address at start-up, which is the fastest cross-check:

```
GMAC0_IP is : 192.168.1.123
```

## 7. TCP server (Experiment A)

**Implementation.** `tcp_server.c`, active only when `TEST_TCP_SERVER = 1`.
Socket `AF_INET, SOCK_STREAM, 6`; `bind` to `192.168.1.123:9060`;
`listen(…, 3)`; endless `accept()` loop; inner `recv()`/`send()` echo loop that
returns to `accept()` when the peer closes. Runs in its own thread
(4 KiB stack, priority 9).

**Configuration.**

```c
#define TEST_TCP_SERVER 1     /* TEST_TCP_CLIENT / TEST_UDP_SERVER / TEST_UDP_CLIENT = 0 */
```

**Build result — SUCCESS** (2026-11-17 10:44:54, 122 s, full log in
`results/logs/build_tcp_server.log`):

| Artefact | Size |
|---|---|
| `builds/tcp_server/tcp_server.exe` (ELF) | 1 341 456 B |
| `builds/tcp_server/tcp_server.bin` (raw) | 569 480 B |
| SHA-256 of `.bin` | `ECD270380F875E6F0CA1BCCAFDDD42BBA407CD3A03F114C40493969B6BD17DA3` |
| sections | text 563 676 / data 5 800 / bss 72 640 |

**Execution and communication — NOT TESTED.** The procedure, the expected console
text and the pass criteria are in `results/reports/hardware_test_guide.md` §7 and
`results/analysis/tcp_server_analysis.md`.

## 8. TCP client (Experiment B)

**Implementation.** `tcp_client.c`, active only when `TEST_TCP_CLIENT = 1`.
Socket `AF_INET, SOCK_STREAM, 0`; `connect()` to `192.168.1.111:9061`; five
cycles of `snprintf("client ticks = %i.\n")` → `send()` → `recv()` with 100 ms
pause; then `closesocket()` and `tcp_client_thread stop!`.

**Configuration.**

```c
#define TEST_TCP_CLIENT 1     /* the other three macros are 0 */
```

**Build result — SUCCESS** (10:46:58, 124 s, `results/logs/build_tcp_client.log`):

| Artefact | Size |
|---|---|
| `builds/tcp_client/tcp_client.exe` | 1 341 240 B |
| `builds/tcp_client/tcp_client.bin` | 569 288 B |
| SHA-256 of `.bin` | `245D5065325B089A808163CEC6277CAD4C3C484346B6F94FEC0060D724136C5A` |
| sections | text 563 484 / data 5 800 / bss 72 640 |

**Execution and communication — NOT TESTED** (guide §8,
`results/analysis/tcp_client_analysis.md`).

## 9. UDP server (Experiment C)

**Implementation.** `udp_server.c`, active only when `TEST_UDP_SERVER = 1`.
Socket `AF_INET, SOCK_DGRAM, 0`; `bind` to `192.168.1.123:9062`; endless
`recvfrom()`/`sendto()` echo in which the reply address is the sender address
carried by the datagram.

**Configuration.**

```c
#define TEST_UDP_SERVER 1     /* the other three macros are 0 */
```

**Documented discrepancy.** The laboratory guide (8.2.14) instructs
"*Protocol type: TCP Server*" with the PC at port 9062. A TCP client cannot reach
this firmware (datagram socket only). The guide's own Figure 8.9 shows the
correct configuration — protocol **UDP**, local `192.168.1.111:9062`, remote
`192.168.1.123:9062` — so the prose is the typo. The experiment is therefore run
in NetAssist's **UDP** mode. This is recorded as defect D7 in
`results/analysis/source_defects_and_fixes.md`; the figure itself is kept in
`reference_screenshots/manual_fig8.9_udp_server_netassist.png`.

**Build result — SUCCESS** (10:49:07, 130 s, `results/logs/build_udp_server.log`):

| Artefact | Size |
|---|---|
| `builds/udp_server/udp_server.exe` | 1 340 776 B |
| `builds/udp_server/udp_server.bin` | 568 848 B |
| SHA-256 of `.bin` | `CD91F3DF2981D5C0C1B584080403D29F8DED363679AFB68231074CA9261B9F42` |
| sections | text 563 300 / data 5 544 / bss 72 896 |

**Execution and communication — NOT TESTED** (guide §9,
`results/analysis/udp_server_analysis.md`).

## 10. UDP client (Experiment D)

**Implementation.** `udp_client.c`, active only when `TEST_UDP_CLIENT = 1`.
Socket `AF_INET, SOCK_DGRAM, 0`; destination `192.168.1.111:9063` assembled in
`remote_addr` but **no `connect()`**; five cycles of
`snprintf("client ticks = %i.")` → `sendto()` → 100 ms pause → `recvfrom()`;
then `closesocket()` and `udp_client_thread stop!`.

**Configuration.**

```c
#define TEST_UDP_CLIENT 1     /* the other three macros are 0 */
```

**Build result — SUCCESS** (10:51:51, 163 s, `results/logs/build_udp_client.log`):

| Artefact | Size |
|---|---|
| `builds/udp_client/udp_client.exe` | 1 341 164 B |
| `builds/udp_client/udp_client.bin` | 569 200 B |
| SHA-256 of `.bin` | `68E2C6ECD974306309525571627E174809F3B0C7334FFF2FC0BB80F2968A7BB4` |
| sections | text 563 396 / data 5 800 / bss 72 640 |

**Execution and communication — NOT TESTED** (guide §10,
`results/analysis/udp_client_analysis.md`).

## 11. TCP and UDP comparison

Full discussion in `results/analysis/tcp_vs_udp_comparison.md`; the essentials:

| Aspect | TCP (A, B) | UDP (C, D) |
|---|---|---|
| State | connection established by a handshake; kept until close | none |
| Socket API | `socket(SOCK_STREAM)` + `bind`/`listen`/`accept` (server), `connect` (client), `send`/`recv` | `socket(SOCK_DGRAM)` + `bind` (server), `sendto`/`recvfrom` with an address per call |
| Delivery | reliable, ordered byte stream | best effort, message boundaries kept, order not guaranteed |
| Peer readiness | a missing server makes `connect()` fail immediately | a missing receiver silently drops the datagram |
| Visible events on the board | `client incoming succeed!`, `client disconnected.` | only `RECEIVE:` when a datagram arrives |
| How the reply finds its way back | inherent to the connection | the sender address stored by `recvfrom` is reused by `sendto` |
| Test configuration | NetAssist *TCP Client* (A) or *TCP Server* (B) | NetAssist *UDP* mode in both C and D, different ports |

## 12. Experimental results

### 12.1 Build results (verified, complete)

| Experiment | Build | ELF | `.bin` | SHA-256 (first 8 hex) |
|---|---|---|---|---|
| A TCP server | SUCCESS | 1 341 456 B | 569 480 B | `ECD27038` |
| B TCP client | SUCCESS | 1 341 240 B | 569 288 B | `245D5065` |
| C UDP server | SUCCESS | 1 340 776 B | 568 848 B | `CD91F3DF` |
| D UDP client | SUCCESS | 1 341 164 B | 569 200 B | `68E2C6EC` |

Selection was verified at firmware level: each image contains exactly one demo
entry point (`tcp_server_init`, `tcp_client_init`, `udp_server_init` or
`udp_client_init`) plus the shared lwIP code, and `main` calls
`ls1x_initialize_lwip` before it.

### 12.2 Hardware results

| Experiment | Execution | Communication | Successful exchanges |
|---|---|---|---|
| A TCP server | NOT TESTED | NOT TESTED | 0 |
| B TCP client | NOT TESTED | NOT TESTED | 0 |
| C UDP server | NOT TESTED | NOT TESTED | 0 |
| D UDP client | NOT TESTED | NOT TESTED | 0 |

The machine-readable version is `results/logs/experiment_results.csv`; it carries
the same values and is updated only when real evidence exists.

## 13. Problems encountered and solutions

| # | Problem | Root cause | Solution | Verified by |
|---|---|---|---|---|
| D1 | Project did not compile: `'else' without a previous 'if'` | the two `printk` lines from guide §8.2.9 were inserted between an `if` block and its `else` | each message moved inside its own branch; the `NULL` dereference in the message was removed as well | gcc error disappears; `GMAC0_IP is : 192.168.1.123` is now the only reachable message |
| D2 | Network never initialised, no demo thread started | `main.c` tested `BSP_USE_GMAC0` before including `bsp.h`, so both `#ifdef` blocks compiled out | `#include <rtthread.h>` and `#include "bsp.h"` added at the top | preprocessed output and `objdump -d` show `jal ls1x_initialize_lwip` + `jal <demo>_init` |
| D3 | `accept()` received an integer instead of a pointer | `(socklen_t)&addrlen` cast; `addrlen` was `int` | `socklen_t addrlen` + `&addrlen` | no `lwip_accept` warning left |
| D4 | UDP echo could reply with an undefined length | uninitialised `socklen_t fromlen`, `struct sockaddr` used for an IPv4 peer | `struct sockaddr_in from` + `socklen_t fromlen = sizeof(from)` + casts | code review; both UDP builds clean |
| D5 | Implicit declarations of `memset`, `snprintf`, `strlen`, `rt_kprintf` | missing `<string.h>`, `<stdio.h>`, `<rtthread.h>` | headers added to the four demo files and `main.c` | no warning from project sources in any of the four logs |
| D6 | Two files named ` udp_server.c`, ` udp_client.c` (leading space) | archive artefact | renamed; the two `FileName=` entries in the `.lxp` updated | `.lxp` unit list (189) matches the files on disk |
| D7 | Guide instructs "TCP Server" for the UDP test (8.2.14) and "TCP UDP" in 8.2.15 | documentation error | UDP mode with the correct ports is used and documented here | source inspection of `udp_server.c`/`udp_client.c` |
| D8 | `install_3th_libraries()` never called (dead code with a second lwIP init) | template leftover | documented only; `main.c` is the single initialisation path | project-wide grep |
| D9 | `MSG_WAITALL` and `ERR_CLSD` comparisons are ineffective | lwIP 1.4.1 supports only `MSG_PEEK`/`MSG_DONTWAIT`; `recv()` returns counts or −1 | documented only — behaviour is correct without changes | `lwIP-1.4.1/api/sockets.c` |

Details, including the exact compiler output and the diffs, are in
`results/analysis/source_defects_and_fixes.md`.

## 14. Overall analysis

* The supplied project could not have produced a single successful experiment in
  its original state: one file did not compile (D1), and the only place that
  started the network stack was compiled out of the image (D2). Both were
  correctness defects, not style issues, and both were localised and repaired
  without changing the design the guide teaches.
* After the repairs the four configurations are structurally identical to the
  guide's design: one macro set per experiment, one demo thread, the same echo and
  five-cycle patterns, the same ports.
* The build evidence is strong where it exists — SHA-256 per image, per-experiment
  object trees, symbol-level proof of which demo is inside which image — and must
  not be confused with experimental evidence. A compiling firmware says nothing
  about cable, PHY link, ARP, or the PC's configuration, which is precisely what
  sections 8.2.10–8.2.15 must establish.
* The protocol-level conclusions that this laboratory can support are prepared in
  `tcp_vs_udp_comparison.md` and split into textbook statements, project facts and
  (still empty) observations, so that no claim is overstated while the hardware
  runs are outstanding.

## 15. Conclusion

The software side of the laboratory work is complete: the project builds in four
mutually exclusive configurations, each with its own reproducible output
directory, and five genuine defects — one of them fatal for compilation and one
fatal for the runtime behaviour — were found, fixed and verified. A complete
hardware procedure, including the exact PuTTY and NetAssist settings and the
expected console transcripts, is ready for execution.

The experimental part (sections 8.2.10–8.2.15: TCP server, TCP client, UDP server,
UDP client on the physical board) has **not** been performed. Consequently this
report does not assert any measured communication result; the four experiments are
recorded as *NOT TESTED* in the results table and in
`results/logs/experiment_results.csv`. Once the eight screenshots listed in
`results/screenshots/README.md` exist, the analyses, the CSV and sections 7–12 of
this report are to be filled in with the observed values.

## 16. Screenshot appendix

### 16.1 Real evidence (to be captured)

| File | Experiment | State |
|---|---|---|
| `results/screenshots/network_configuration.png` | all | **pending** |
| `results/screenshots/tcp_server_putty.png` | A | **pending** |
| `results/screenshots/tcp_server_netassist.png` | A | **pending** |
| `results/screenshots/tcp_client_putty.png` | B | **pending** |
| `results/screenshots/tcp_client_netassist.png` | B | **pending** |
| `results/screenshots/udp_server_putty.png` | C | **pending** |
| `results/screenshots/udp_server_netassist.png` | C | **pending** |
| `results/screenshots/udp_client_putty.png` | D | **pending** |
| `results/screenshots/udp_client_netassist.png` | D | **pending** |

### 16.2 Reference examples (not evidence)

The guide's Figures 8.5 – 8.12 have been extracted from the course document and
stored in `reference_screenshots/`, labelled as *expected appearance only*:

| File | Guide figure |
|---|---|
| `manual_fig8.5_tcp_server_netassist.png` | 8.5 — NetAssist TCP Client, `192.168.1.123:9060` |
| `manual_fig8.6_tcp_server_putty.png` | 8.6 — board console, TCP server |
| `manual_fig8.7_tcp_client_netassist.png` | 8.7 — NetAssist TCP Server, `192.168.1.111:9061` |
| `manual_fig8.8_tcp_client_putty.png` | 8.8 — board console, TCP client |
| `manual_fig8.9_udp_server_netassist.png` | 8.9 — NetAssist UDP, port 9062 |
| `manual_fig8.10_udp_server_putty.png` | 8.10 — board console, UDP server |
| `manual_fig8.11_udp_client_netassist.png` | 8.11 — NetAssist UDP, port 9063 |
| `manual_fig8.12_udp_client_putty.png` | 8.12 — board console, UDP client |

They were produced by the course author on a different machine (RT-Thread 4.0.3,
`COM8`, 2022-03-02). They are not proof of any experiment in this report and must
never be cited as such; they served only to pin down the expected window layout
and console transcript, and they exposed the §8.2.14 typo described in §9.

Three details taken from those figures and used in the analyses:

1. **Figure 8.9** shows the author's own NetAssist in **UDP** mode with local
   `192.168.1.111:9062` and remote `192.168.1.123:9062`, confirming that only the
   *prose* of §8.2.14 is wrong.
2. **Figures 8.6 / 8.10 / 8.12** show the boot sequence common to all four runs,
   including `detect phy address == 17`,
   `GMAC0: SPEED=100M, DUPLEX=FULL, LINK=UP. AN=YES.` and
   `GMAC0 controller initialized.` (all printed by `ls1x_gmac.c`, not by the
   experiment code) and the prompt `msh />`.
3. **Figures 8.7 / 8.8 / 8.11 / 8.12** show the board's ephemeral source port
   `49153`, and tick values that advance unevenly (`2308 → 5964 → …`), because
   each client cycle waits in `recv()`/`recvfrom()` for the human reply. The port
   will differ in every run and the irregular spacing is expected, not a fault.

The guide is not even self-consistent in its own spelling
(`succeed to …` in 8.6, `success to …` in 8.8, `succed to …` in 8.10); this
project's source prints `succeed to …`. The wording is cosmetic.
