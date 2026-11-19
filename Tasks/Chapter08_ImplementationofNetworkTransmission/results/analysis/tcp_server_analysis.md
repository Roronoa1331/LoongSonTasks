# Experiment A — TCP server on the Loongson 1B (port 9060)

> **Evidence status: the hardware test has NOT been executed yet.**
> Build result: verified. Execution and communication: *not tested*.
> Everything in the sections "Expected behaviour" is derived from the source
> code and the laboratory guide; nothing in this document claims to be an
> observed measurement.

## 1. Objective

Run the Loongson 1B board as a **TCP server** on `192.168.1.123:9060`, let a PC
act as the TCP client, and show that every byte the client sends is received by
the board and echoed back unchanged — i.e. that a connection-oriented,
bi-directional byte stream works over lwIP/GMAC0.

## 2. Environment

| Item | Value |
|------|-------|
| Board | Loongson 1B (LS1B200), MIPS32 little-endian, soft-float |
| SoC interface | GMAC0 (10/100 Mbit), MAC `72:74:00:83:DE:12` (`ls1x_ethernetif.c`) |
| RTOS | RT-Thread 4.0.2, `RT_TICK_PER_SECOND = 1000` |
| Stack | lwIP 1.4.1 (socket + netconn API), `TCP_MSS = 1460`, `MEM_SIZE = 32 KiB` |
| Toolchain | SDE Lite 4.9.2 for MIPS (`mips-sde-elf-gcc`), `-mips32 -G0 -EL -msoft-float -O0` |
| Host | Windows PC, PuTTY (serial 115200 8-N-1), NetAssist V5.0.2 |

## 3. Addresses and ports

| Role | IP | Port |
|------|----|------|
| Board (server) | `192.168.1.123` | `9060` (`TCP_LOCAL_PORT`) |
| PC (client) | `192.168.1.111` | ephemeral, chosen by the PC |

## 4. Macro configuration

```c
#define TEST_TCP_SERVER         1
#define TEST_TCP_CLIENT         0
#define TEST_UDP_SERVER         0
#define TEST_UDP_CLIENT         0
```

The exact header used for this image is stored as
`builds/tcp_server/lwip_test.h.snapshot`. Only the `tcp_server.c` translation
unit then contains code; the other three demos preprocess to nothing.

## 5. Implementation summary (`tcp_server.c`)

* `socket(AF_INET, SOCK_STREAM, 6)` — protocol 6 is TCP.
* `bind()` to `inet_addr(local_IP)` : `htons(9060)`.
* `listen(sock_fd, 3)` — backlog of three queued connections.
* Outer loop: `accept()`, then an inner loop that receives up to
  `TCP_SERVER_BUFSIZE = 256` bytes with `recv()` and immediately `send()`s the
  same `err` bytes back, printing `RECEIVE:` and `    SEND:` for each block.
* `err <= 0` (peer closed / error) closes the client socket and returns to
  `accept()`; the listener stays open, so a second connection can be served.
* The whole thing runs in its own thread (`sys_thread_new("tcp_server", …)`,
  4 KiB stack, priority `DEFAULT_THREAD_PRIO + 1 = 9`), started from `main()`
  after `ls1x_initialize_lwip()`.

## 6. Procedure

1. Cabling, PuTTY and PC address per `results/reports/hardware_test_guide.md`
   steps 1–5.
2. `.\build.ps1 -Experiment tcp_server`; download with LoongIDE (*Debug → Run*).
3. `ping 192.168.1.123`, `arp -a` on the PC.
4. NetAssist: **TCP Client**, remote `192.168.1.123:9060`, **Connect**.
5. Send `Hello LS1B`; observe the console and the echo.

## 7. Actual build result (verified)

```
$ .\build.ps1 -Experiment tcp_server
result           : SUCCESS      (2026-11-17T10:44:54, 122 s)
elf              : builds/tcp_server/tcp_server.exe   1 341 456 bytes
binary           : builds/tcp_server/tcp_server.bin     569 480 bytes
bin sha256       : ECD270380F875E6F0CA1BCCAFDDD42BBA407CD3A03F114C40493969B6BD17DA3
sections         : text 563 676   data 5 800   bss 72 640
```

`mips-sde-elf-nm` on the image lists `tcp_server_init` (and not
`tcp_client_init` / `udp_server_init` / `udp_client_init`), and the disassembly
of `main` shows `jal ls1x_initialize_lwip` followed by `jal tcp_server_init`.
No compiler warning and no error is attributed to `main.c`, `lwip_test.h`,
`lwip_test.c` or `tcp_server.c`. Full log: `results/logs/build_tcp_server.log`.

## 8. Actual execution result

**NOT TESTED.** No board run has been performed for this experiment yet.

## 9. Actual communication result

**NOT TESTED.** No datagram/segment has been exchanged with the board yet.

## 10. Expected behaviour (to be confirmed, not observed)

Console after the download (the boot part matches the course guide's Figure 8.6;
our project links RT-Thread **4.0.2**, the figure shows 4.0.3, so only the version
string differs):

```
Entry address is 80200000
Clock_mask: 8000, step=100000
 | /
- RT -     Thread Operating System
/ | \     4.0.2 build …
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

After NetAssist connects: `client incoming succeed!`.
After sending `Hello LS1B`:

```
RECEIVE: Hello LS1B
    SEND: Hello LS1B
```

and NetAssist shows `Hello LS1B` in its receive pane.

Two behaviours worth recognising when the run is graded (both visible in the
reference figures 8.6 / 8.7):

* the listener survives a client disconnect — the console prints
  `disconnect client succeed!`, then `waiting for client access!` again, and a
  second NetAssist connection is accepted without restarting the firmware;
* NetAssist logs each echo as `SEND ASCII TO …` followed by `RECV ASCII FROM …`
  with identical payloads.

## 11. Screenshots

| File | State |
|------|-------|
| `results/screenshots/tcp_server_putty.png` | **missing — must be captured** |
| `results/screenshots/tcp_server_netassist.png` | **missing — must be captured** |
| `results/screenshots/network_configuration.png` | **missing — must be captured** (once, shared by all four experiments) |

Reference examples (not results) may be placed in `reference_screenshots/`.

## 12. Problems encountered

| Problem | Cause | Status |
|---|---|---|
| Project did not compile | `else` without `if` in `ls1x_ethernetif.c` (defect D1) | fixed, see `source_defects_and_fixes.md` |
| Network never initialised on the board | `main.c` used `BSP_USE_GMAC0` without including `bsp.h` (D2) | fixed |
| `accept()` third argument invalid | `(socklen_t)&addrlen` cast (D3) | fixed |
| `memset` implicitly declared | missing `<string.h>` (D5) | fixed |
| Hardware run | not attempted | **pending** |

## 13. Conclusion

The TCP-server firmware is complete, reproducible and builds cleanly in its own
output directory, with the compile-blocking defects of the supplied project
repaired. The experiment itself — client connects, data is echoed — remains to be
demonstrated on the hardware; until the two screenshots exist this experiment is
reported as *not tested*, never as passed.
