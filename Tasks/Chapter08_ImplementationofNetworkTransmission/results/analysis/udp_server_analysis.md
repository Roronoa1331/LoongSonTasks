# Experiment C — UDP server (echo endpoint) on the LoongSon 1B (port 9062)

> **Evidence status: the hardware test has NOT been executed yet.**
> Build result: verified. Execution and communication: *not tested*.

## 1. Objective

Run the Loongson 1B as a **UDP endpoint** bound to `192.168.1.123:9062`. The PC
sends a datagram to that port; the board prints it and returns the same payload
to the sender's address. Because UDP is connectionless there is no `listen()` and
no `accept()`: the board simply waits for datagrams.

## 2. Environment

Same platform as experiment A (Loongson 1B / GMAC0, RT-Thread 4.0.2, lwIP 1.4.1,
SDE Lite 4.9.2, PuTTY + NetAssist V5.0.2).

## 3. Addresses and ports

| Role | IP | Port |
|------|----|------|
| Board (UDP server / echo endpoint) | `192.168.1.123` | `9062` (`UDP_LOCAL_PORT`) |
| PC (UDP sender) | `192.168.1.111` | `9062` local port, as in guide Figure 8.9 (any free port works) |

## 4. Macro configuration

```c
#define TEST_TCP_SERVER         0
#define TEST_TCP_CLIENT         0
#define TEST_UDP_SERVER         1
#define TEST_UDP_CLIENT         0
```

Snapshot: `builds/udp_server/lwip_test.h.snapshot`.

## 5. Implementation summary (`udp_server.c`)

* `socket(AF_INET, SOCK_DGRAM, 0)` — datagram socket, no protocol number needed.
* `bind()` to `inet_addr(local_IP)` : `htons(9062)`.
* Endless loop: `recvfrom(…, &from, &fromlen)` into a 256-byte buffer; on a
  positive result it prints `RECEIVE: …`, sends the same `err` bytes back with
  `sendto(…, &from, fromlen)` and prints `    SEND: …`.
  Negative results wait 100 ms and retry, so a lost datagram does not kill the
  thread.
* The reply address is the *source address carried inside the received datagram*;
  the board therefore answers whoever actually sent data, regardless of the
  sender's port. That is the UDP equivalent of an echo service.

## 6. Procedure

1. Cabling/PuTTY/PC address as in experiment A.
2. `.\build.ps1 -Experiment udp_server`, download with LoongIDE.
   3. NetAssist: **Protocol type = UDP**; local port `9062` (what guide Figure 8.9
      uses; any free port also works, e.g. `9064`);
      remote `192.168.1.123:9062`; **Connect**.
4. Send `UDP hello`; observe the console and the returned datagram.

> **Manual discrepancy.** Section 8.2.14 of the laboratory guide tells the reader
> to choose *Protocol type: TCP Server* and to give the PC the port `9062`.
> The prose is wrong: the firmware uses `SOCK_DGRAM` only (a TCP client could
> never reach it), and the correct mode is UDP — which is exactly what the
> guide's own **Figure 8.9** shows (protocol UDP, local `192.168.1.111:9062`,
> remote `192.168.1.123:9062`). See `source_defects_and_fixes.md`, defect D7.

## 7. Actual build result (verified)

```
result           : SUCCESS      (2026-11-17T10:49:07, 130 s)
elf              : builds/udp_server/udp_server.exe   1 340 776 bytes
binary           : builds/udp_server/udp_server.bin     568 848 bytes
bin sha256       : CD91F3DF2981D5C0C1B584080403D29F8DED363679AFB68231074CA9261B9F42
sections         : text 563 300   data 5 544   bss 72 896
```

Symbol check: `udp_server_init` present, the other three demo entries absent.
Log: `results/logs/build_udp_server.log`.

## 8. Actual execution result

**NOT TESTED.**

## 9. Actual communication result

**NOT TESTED.**

## 10. Expected behaviour (to be confirmed, not observed)

```
succeed to create sock_fd!
succeed to bind ip!
RECEIVE: UDP hello
    SEND: UDP hello
```

Note the absence of `waiting for client access!` / `client incoming succeed!`
compared with experiment A: with UDP nothing arrives until a datagram is sent, and
there is no connection event to report.

NetAssist shows the same text arriving from `192.168.1.123:9062`.

The course guide's reference Figure 8.10 shows the echo in exactly this shape for
five consecutive datagrams (`RECEIVE: send1` … `RECEIVE: send5`, each followed by
the indented `SEND:` line), and Figure 8.9 shows the matching NetAssist log
(`SEND ASCII TO 192.168.1.123:9062` / `RECV ASCII FROM 192.168.1.123:9062`). Note
that Figure 8.10 prints `succed to ...` (one "e"); this project's source prints
`succeed to ...`. The wording is cosmetic and does not affect the experiment.

## 11. Screenshots

| File | State |
|------|-------|
| `results/screenshots/udp_server_putty.png` | **missing — must be captured** |
| `results/screenshots/udp_server_netassist.png` | **missing — must be captured** |

The NetAssist capture must show the protocol selector on **UDP**, otherwise the
run contradicts the manual and cannot be graded.

## 12. Problems encountered

| Problem | Cause | Status |
|---|---|---|
| Echo reply could be sent to a garbage length | uninitialised `fromlen`, `struct sockaddr` too small (D4) | fixed |
| `memset` implicitly declared | missing `<string.h>` (D5) | fixed |
| Source file name started with a space | archive artefact, file renamed (D6) | fixed |
| Manual says "TCP Server" for this test | documentation error (D7) | documented, UDP used |
| Hardware run | not attempted | **pending** |

## 13. Conclusion

The UDP server configuration is prepared, builds cleanly and its protocol
handling matches the guide's intent once the manual's TCP/UDP typo is corrected.
The echo behaviour itself (datagram in → identical datagram back) still has to be
demonstrated on the board.
