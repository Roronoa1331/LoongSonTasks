# Experiment D — UDP client on the LoongSon 1B (PC receiver on port 9063)

> **Evidence status: the hardware test has NOT been executed yet.**
> Build result: verified. Execution and communication: *not tested*.

## 1. Objective

Run the Loongson 1B as a **UDP sender**: it transmits a datagram with a tick
stamp to `192.168.1.111:9063`, waits for a reply, repeats this five times and then
stops. The experiment shows that UDP needs no connection, that a reply is only
possible because the sender's address travels inside the datagram, and that
nothing is retransmitted if the peer is not ready.

## 2. Environment

Same platform as experiment A (Loongson 1B / GMAC0, RT-Thread 4.0.2, lwIP 1.4.1,
SDE Lite 4.9.2, PuTTY + NetAssist V5.0.2).

## 3. Addresses and ports

| Role | IP | Port |
|------|----|------|
| Board (UDP client / sender) | `192.168.1.123` | ephemeral |
| PC (UDP receiver) | `192.168.1.111` | `9063` (`UDP_REMOTE_PORT`) |

## 4. Macro configuration

```c
#define TEST_TCP_SERVER         0
#define TEST_TCP_CLIENT         0
#define TEST_UDP_SERVER         0
#define TEST_UDP_CLIENT         1
```

Snapshot: `builds/udp_client/lwip_test.h.snapshot`.

## 5. Implementation summary (`udp_client.c`)

* `socket(AF_INET, SOCK_DGRAM, 0)`; the destination `remote_addr` is filled with
  `inet_addr(remote_IP)` : `htons(9063)` — but **no `connect()` is called**, which
  is the essential difference from experiment B.
* Loop, five iterations:
  1. `snprintf(data_buf, UDP_CLIENT_BUFSIZE-1, "client ticks = %i.", get_clock_ticks())`
  2. `sendto(…, &remote_addr, sizeof(remote_addr))`; on failure wait 1 s and retry
     (the attempt is not counted).
  3. `delay_ms(100)`, then `recvfrom(…, MSG_WAITALL, &from, &fromlen)`; a positive
     result prints `  RECEIVE: …`.
  4. `count` is incremented and the loop ends at five.
* Then `closesocket()` and `udp_client_thread stop!`.
* `MSG_WAITALL` is accepted but ignored by lwIP 1.4.1 (only `MSG_PEEK` and
  `MSG_DONTWAIT` are interpreted), so the blocking socket simply waits for the
  reply — the intended behaviour (see defect D9).

## 6. Procedure

1. Cabling/PuTTY/PC address as in experiment A.
2. `.\build.ps1 -Experiment udp_client`, download with LoongIDE.
3. **Start NetAssist first**: *Protocol type = UDP*, local `192.168.1.111:9063`,
   Connect. If it is not listening, the first datagrams are silently lost.
4. Reset/download the board and watch five `SEND:`/`RECEIVE:` pairs.
5. Reply to the board from NetAssist (destination `192.168.1.123`, source 9063).

> **Manual discrepancy.** Section 8.2.15 prints "*Protocol type: TCP UDP*",
> which is not a NetAssist option. The only correct choice is **UDP**.

## 7. Actual build result (verified)

```
result           : SUCCESS      (2026-11-17T10:51:51, 163 s)
elf              : builds/udp_client/udp_client.exe   1 341 164 bytes
binary           : builds/udp_client/udp_client.bin     569 200 bytes
bin sha256       : 68E2C6ECD974306309525571627E174809F3B0C7334FFF2FC0BB80F2968A7BB4
sections         : text 563 396   data 5 800   bss 72 640
```

Symbol check: `udp_client_init` present, the other demo entries absent.
Log: `results/logs/build_udp_client.log`.

## 8. Actual execution result

**NOT TESTED.**

## 9. Actual communication result

**NOT TESTED.**

## 10. Expected behaviour (to be confirmed, not observed)

```
succeed to create sock_fd!
SEND: client ticks = 2345.
  RECEIVE: reply from PC
SEND: client ticks = 2446.
  RECEIVE: reply from PC
…  (five pairs)
udp_client_thread stop!
```

In NetAssist, five datagrams arrive from `192.168.1.123:<ephemeral>`; because the
board is the sender, the reply has to be sent back to that address (NetAssist does
this automatically when you answer the received datagram).

The course guide's reference figures 8.11 / 8.12 confirm the shape of the run:
NetAssist receives `client ticks = 1908.` from `192.168.1.123:49153` and replies
`receive1`, the board prints `    RECEIVE: receive1`, and after the fifth exchange
`udp_client_thread stop!` appears. The tick numbers are *not* evenly spaced
(`1908 → 8088 → 10403 → 12568 → 14684`), because each cycle waits in `recvfrom()`
for the human reply; the ephemeral port `49153` will differ in every run.

## 11. Screenshots

| File | State |
|------|-------|
| `results/screenshots/udp_client_putty.png` | **missing — must be captured** |
| `results/screenshots/udp_client_netassist.png` | **missing — must be captured** |

## 12. Problems encountered

| Problem | Cause | Status |
|---|---|---|
| Reply length could be garbage | uninitialised `fromlen` (D4) | fixed |
| `snprintf`/`strlen`/`memset` implicitly declared | missing headers (D5) | fixed |
| Source file name started with a space | archive artefact (D6) | fixed |
| Manual says "TCP UDP" | documentation error (D7) | documented, UDP used |
| Hardware run | not attempted | **pending** |

## 13. Conclusion

The UDP-client configuration is ready and builds cleanly; the five-cycle
send/receive logic is in place. The behaviour that distinguishes it from the TCP
client — no handshake, replies only if the peer is already listening — is exactly
what the hardware run has to show, and that run is still pending.
