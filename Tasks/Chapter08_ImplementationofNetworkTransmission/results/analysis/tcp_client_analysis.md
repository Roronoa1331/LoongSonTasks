# Experiment B — TCP client on the Loongson 1B (PC server on port 9061)

> **Evidence status: the hardware test has NOT been executed yet.**
> Build result: verified. Execution and communication: *not tested*.
> The "expected" texts below come from the source code, not from a board run.

## 1. Objective

Run the Loongson 1B as a **TCP client** that connects *out* to a PC acting as
TCP server (`192.168.1.111:9061`), transmits a short message five times, receives
the server's reply each time and then closes the socket. This demonstrates the
client half of a TCP connection: `connect()` performed by the board, and a
request/response exchange over the same byte stream.

## 2. Environment

Same platform as experiment A: Loongson 1B / GMAC0, RT-Thread 4.0.2, lwIP 1.4.1,
SDE Lite 4.9.2, PuTTY + NetAssist V5.0.2 on Windows.

## 3. Addresses and ports

| Role | IP | Port |
|------|----|------|
| Board (client) | `192.168.1.123` | ephemeral (assigned by lwIP) |
| PC (server) | `192.168.1.111` | `9061` (`TCP_REMOTE_PORT`) |

## 4. Macro configuration

```c
#define TEST_TCP_SERVER         0
#define TEST_TCP_CLIENT         1
#define TEST_UDP_SERVER         0
#define TEST_UDP_CLIENT         0
```

Snapshot: `builds/tcp_client/lwip_test.h.snapshot`.

## 5. Implementation summary (`tcp_client.c`)

* `socket(AF_INET, SOCK_STREAM, 0)` then `connect()` to
  `inet_addr(remote_IP)` : `htons(9061)`. The connect is blocking.
* Loop, at most five iterations (`count` reaches 5 → `break`):
  1. `snprintf(data_buf, 99, "client ticks = %i.\n", get_clock_ticks())`
     — `get_clock_ticks()` returns `Clock_driver_ticks`, incremented by the 1 ms
     timer interrupt, so the value is "milliseconds since boot".
  2. `send()` the string; `SEND: …` is printed on success.
  3. `recv()` up to 256 bytes; `  RECEIVE: …` is printed when bytes arrive.
  4. `delay_ms(100)`, then `count` is checked.
* After five cycles: `closesocket()`, `tcp_client_thread stop!`. The thread then
  returns; the demo deliberately runs only five rounds so the log is short and
  easy to grade.
* If `send()` fails the loop waits 1 s and retries without counting; if no reply
  arrives, `recv()` blocks (blocking socket) — this is by design, the PC server
  is expected to answer.

## 6. Procedure

1. Cabling/PuTTY/PC address as in experiment A.
2. `.\build.ps1 -Experiment tcp_client`, download with LoongIDE.
3. **Start NetAssist first**: *TCP Server*, local `192.168.1.111:9061`, Connect.
4. Reset the board (or download again). The board connects out on its own.
5. Watch five `SEND:`/`RECEIVE:` pairs; answer each message from NetAssist.

## 7. Actual build result (verified)

```
result           : SUCCESS      (2026-11-17T10:46:58, 124 s)
elf              : builds/tcp_client/tcp_client.exe   1 341 240 bytes
binary           : builds/tcp_client/tcp_client.bin     569 288 bytes
bin sha256       : 245D5065325B089A808163CEC6277CAD4C3C484346B6F94FEC0060D724136C5A
sections         : text 563 484   data 5 800   bss 72 640
```

Symbol check: the image contains `tcp_client_init` and none of the other three
demo entry points. Log: `results/logs/build_tcp_client.log`.

## 8. Actual execution result

**NOT TESTED.**

## 9. Actual communication result

**NOT TESTED.**

## 10. Expected behaviour (to be confirmed, not observed)

```
succeed to create sock_fd!
succeed to connect to server!
SEND: client ticks = 1234.
  RECEIVE: hello board
SEND: client ticks = 1335.
  RECEIVE: hello board
…  (five pairs in total)
tcp_client_thread stop!
```

In NetAssist the board appears as an incoming connection from
`192.168.1.123:<ephemeral>`, five lines `client ticks = N.` arrive, and whatever
the PC sends back is echoed in the board console after `RECEIVE:`.

Two details confirmed by the course guide's reference figures 8.7 / 8.8, useful
for interpreting the real run:

* NetAssist announces the connection as
  `Client 192.168.1.123:49153 gets online.` — `49153` is lwIP's ephemeral source
  port on the board, so **the port number will differ** between runs;
* the tick values advance by seconds, not by the 100 ms pause in the loop
  (`2308 → 5964 → 7394 → 7969 → 8408` in the figure). That is expected: the
  loop's `recv()` blocks until the PC answers, so each cycle lasts as long as the
  human takes to reply. A cycle is therefore *message-driven*, not timer-driven.

Note: the TCP connection is what makes this demo possible at all — the client
cannot send anything until the three-way handshake has completed, which is why
NetAssist must already be listening.

## 11. Screenshots

| File | State |
|------|-------|
| `results/screenshots/tcp_client_putty.png` | **missing — must be captured** |
| `results/screenshots/tcp_client_netassist.png` | **missing — must be captured** |

## 12. Problems encountered

| Problem | Cause | Status |
|---|---|---|
| `snprintf`/`strlen`/`memset` implicitly declared | missing `<stdio.h>`/`<string.h>` (D5) | fixed |
| Network never initialised | defect D2 in `main.c` | fixed |
| Hardware run | not attempted | **pending** |

## 13. Conclusion

The TCP-client configuration is prepared and verified at build level, with the
five-cycle conversation implemented exactly as the guide describes. Whether the
board actually initiates the connection and completes five full request/response
cycles has yet to be observed on the hardware; until then this experiment is
reported as *not tested*, not as passed.
