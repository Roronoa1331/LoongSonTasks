# Source and configuration defects found and fixed

Every entry below is a defect that was *observed*, not suspected. The evidence
column names the tool output that proves it. Defects are listed in the order of
severity: D1–D2 made the laboratory work impossible (nothing could be built /
nothing would run), D3–D6 are real but smaller defects, D7–D9 are documented
observations that were deliberately **not** changed.

Toolchain used for all checks: `E:\LoongIDE\mips-2015.05\bin\mips-sde-elf-gcc.exe`
(SDE Lite 4.9.2 for MIPS), GNU make 3.81, target flags
`-mips32 -G0 -EL -msoft-float -DLS1B -DOS_RTTHREAD`.

---

## D1 — `lwIP-1.4.1/port/ls1x_ethernetif.c`: `else` without a previous `if`

**Symptom / evidence**

```
lwIP-1.4.1/port/ls1x_ethernetif.c:510:5: error: 'else' without a previous 'if'
     else
     ^
```

The file did not compile at all, therefore *none* of the four experiments could
be built.

**Cause.** Section 8.2.9 of the laboratory guide asks the student to add two
`printk()` statements to `ls1x_initialize_lwip()`. They were inserted in the
wrong place — the first one between the closing brace of the `if (ip0 != NULL)`
block and its `else`, which terminates the statement and leaves the `else`
orphaned:

```c
    if (ip0 != NULL)
    {
        IP4_ADDR(&ipaddr,  ip0[0], ip0[1], ip0[2], ip0[3]);
        IP4_ADDR(&netmask, 255, 255, 255, 0);
        IP4_ADDR(&gateway, ip0[0], ip0[1], ip0[2], 1);
    }printk("GMAC0_IP is : %d.%d.%d.%d \n",ip0[0],ip0[1],ip0[2],ip0[3]);
    else
    ...
    printk("GMAC0_IP is default : 192.168.1.123 \n");
```

Two further problems hid in the same three lines: the first `printk` would have
dereferenced `ip0` even when it is `NULL`, and the *default* message was printed
unconditionally, not only in the default branch.

**Fix.** Each message now lives inside its own branch:

```c
    if (ip0 != NULL)
    {
        IP4_ADDR(&ipaddr,  ip0[0], ip0[1], ip0[2], ip0[3]);
        IP4_ADDR(&netmask, 255, 255, 255, 0);
        IP4_ADDR(&gateway, ip0[0], ip0[1], ip0[2], 1);
        printk("GMAC0_IP is : %d.%d.%d.%d \n", ip0[0], ip0[1], ip0[2], ip0[3]);
    }
    else
    {
        IP4_ADDR(&ipaddr,  192, 168,   1, 123);
        IP4_ADDR(&netmask, 255, 255, 255,   0);
        IP4_ADDR(&gateway, 192, 168,   1,   1);
        printk("GMAC0_IP is default : 192.168.1.123 \n");
    }
```

**Verification.** The file compiles without diagnostics; the message is exactly
the one the guide expects on the PuTTY console (`GMAC0_IP is : 192.168.1.123`).

---

## D2 — `main.c`: the whole network start-up was compiled out

**Symptom / evidence.** `main.c` tested `BSP_USE_GMAC0` but never included the
header that defines it. Preprocessing with the project's own flags produced:

```
$ mips-sde-elf-gcc … -E main.c | grep -E "ls1x_initialize_lwip|tcp_server_init"
extern void tcp_server_init(void);            <- from lwip_test.h
rt_kprintf("\r\nWelcome to RT-Thread.\r\n\r\n");   <- welcome text only
```

There is **no** call to `ls1x_initialize_lwip()` and **no** call to any
`*_init()` demo function. On the board the program would print the welcome line
and then return — no lwIP, no GMAC0, no socket, no experiment.

**Cause.** `BSP_USE_GMAC0` is defined in `include/bsp.h` (line 92), not on the
compiler command line (`DefinedSymbols=LS1B;OS_RTTHREAD` in the `.lxp`). The
file's first statement was `#ifdef BSP_USE_GMAC0`, evaluated before any header
had been included, so the condition was false — twice.

**Fix.** The two headers used by the file are now included first:

```c
/* bsp.h defines BSP_USE_GMAC0 (GMAC0 enabled) and declares rt_kprintf/printk. */
#include <rtthread.h>
#include "bsp.h"
```

This also cures the `implicit declaration of function 'rt_kprintf'` warning.

**Verification.** After the fix the disassembly of `main` contains both calls:

```
80252794:  jal  80225390 <rt_kprintf>
802527a8:  jal  802517bc <ls1x_initialize_lwip>
802527b0:  jal  80252b0c <tcp_server_init>          (tcp_server build)
```

and the preprocessed file now contains `ls1x_initialize_lwip(gmac0_ip, NULL)`.
Note that GMAC0 is initialised exactly once: `ls1x_initialize_lwip()` returns
early if `is_lwip_initialized` is set (see D8).

---

## D3 — `tcp_server.c`: invalid third argument of `accept()`

**Symptom / evidence**

```
../tcp_server.c:51:1: warning: passing argument 3 of 'lwip_accept' makes pointer
from integer without a cast
```

**Cause.** `(socklen_t)&addrlen` converts the *address of* `addrlen` to an
integer and passes it where `accept()` expects a `socklen_t *`.

**Fix.**

```c
socklen_t addrlen = sizeof(client_addr);
client_fd = accept(sock_fd, (struct sockaddr *)&client_addr, &addrlen);
```

`addrlen` is now also of the correct type (`int` → `socklen_t`).

**Verification.** No `accept` diagnostic remains in
`results/logs/build_tcp_server.log`.

---

## D4 — `udp_server.c` / `udp_client.c`: uninitialised peer-address length

**Symptom.** Both UDP demos passed an uninitialised `socklen_t fromlen` to
`recvfrom()` together with a `struct sockaddr` that is too small to describe an
IPv4 peer:

```c
struct sockaddr from;
socklen_t fromlen;                       /* never initialised */
err = recvfrom(sock_fd, data_buf, …, &from, &fromlen);
sendto(sock_fd, data_buf, err, 0, &from, fromlen);   /* echo to a garbage length */
```

**Fix.** The peer is described with a `sockaddr_in` (16 bytes, the real type of
the address returned by lwIP) and the length is initialised:

```c
struct sockaddr_in from;
socklen_t fromlen = sizeof(from);
err = recvfrom(sock_fd, data_buf, UDP_SERVER_BUFSIZE, 0,
               (struct sockaddr *)&from, &fromlen);
...
sendto(sock_fd, data_buf, err, 0, (struct sockaddr *)&from, fromlen);
```

`udp_client.c` receives the reply with the same initialisation and the same cast.

**Verification.** The UDP echo path now has a well-defined address length; both
UDP configurations compile without diagnostics.

---

## D5 — Missing standard headers in the four demo files

**Symptom / evidence**

```
../tcp_server.c:19:1: warning: implicit declaration of function 'memset'
../main.c:11:1: warning: implicit declaration of function 'rt_kprintf'
```

**Fix.** Added `#include <string.h>` (and `#include <stdio.h>` where `snprintf`
is used) to `tcp_server.c`, `tcp_client.c`, `udp_server.c`, `udp_client.c`, and
`#include <rtthread.h>` to `main.c`. An implicit declaration assumes
`int f()`; that is undefined behaviour for `memset()` and hides prototype errors.

---

## D6 — Two source files had a leading space in their name

**Symptom.** The project root contained ` udp_server.c` and ` udp_client.c`
(note the space). The `.lxp` recorded the same names, so LoongIDE tolerated it,
but any make-based build, archive or copy breaks or silently loses them — the
files cannot be addressed without quoting, and a make prerequisite with an
internal leading space is fragile.

**Fix.** Renamed to `udp_server.c` and `udp_client.c`; the two `FileName=` lines
in `Chapter08_ImplementationofNetworkTransmission.lxp` were updated accordingly,
so the LoongIDE project still resolves every unit. The file set of the `.lxp`
(189 C/assembly units) now matches the files on disk exactly.

---

## D7 — Documentation discrepancy: UDP server test says "TCP Server" in its prose

Section 8.2.14 of the guide ("UDP Server Test") instructs the reader to select
*Protocol type: **TCP Server*** in NetAssist and gives the PC the address and
port `192.168.1.111:9062`. That contradicts the experiment itself:

* `udp_server.c` creates its socket with `socket(AF_INET, SOCK_DGRAM, 0)` and
  uses `recvfrom()` / `sendto()`, i.e. it only speaks **UDP**;
* a TCP client would never reach it, because no TCP socket is bound to port 9062
  on the board;
* the PC's *local* port has no reason to be 9062 — that is the board's port.

The guide's own screenshot, **Figure 8.9**, shows the correct configuration:
protocol **UDP**, local `192.168.1.111:9062`, remote `192.168.1.123:9062`, with
`SEND ASCII TO 192.168.1.123:9062` / `RECV ASCII FROM 192.168.1.123:9062`
exchanges. So the *prose* of 8.2.14 is a typo while the figure is right.

**Resolution used in this laboratory work:** NetAssist is configured as
**UDP** with remote host `192.168.1.123`, remote port `9062`, and local port
`9062` (as in Figure 8.9; any free local port works). Section 8.2.15 has the
same kind of typo ("*Protocol type: TCP UDP*"); the only correct choice there is
**UDP** as well — its Figure 8.11 shows UDP mode on local port `9063`. Both are
recorded in the laboratory report.

The reference figures are stored, clearly labelled as examples, in
`reference_screenshots/`.

---

## D8 — `install_3th_libraries()` is defined but never called

`src/install_3th_libraries.c` contains a second, unused `ls1x_initialize_lwip(NULL, NULL)`
call, and is not referenced by any other file (grep over the whole project finds
only its declaration in `bsp.h` and its definition). It is dead code in this
design; `main.c` is the only place that initialises the stack. No change was
made — removing it would deviate from the course template without any benefit —
but it is worth knowing when reading the map file or the disassembly (two
`jal ls1x_initialize_lwip` sites exist, only one of them executes).

---

## D9 — Two harmless observations, intentionally left unchanged

* `tcp_server.c` compares the result of `recv()` with `ERR_CLSD` (an lwIP
  *err_t* value). `recv()` returns either a byte count or `-1`, so that branch is
  unreachable; the following `else if (err <= 0)` handles the disconnect anyway.
  Behaviour is correct, so the code was left as the guide prints it.
* `udp_client.c` receives with the flag `MSG_WAITALL`. lwIP 1.4.1 honours only
  `MSG_PEEK` and `MSG_DONTWAIT` (`lwIP-1.4.1/api/sockets.c`, `lwip_recvfrom()`);
  the flag is ignored and the blocking socket waits for the reply anyway, which
  is exactly the intended behaviour. The comment in the guide that claims
  "MSG_WAITALL blocks every data" is inaccurate, but no fix is required.

---

## Summary of build verification after the fixes

| Configuration | Result | ELF | Raw image | SHA-256 of raw image |
|---|---|---|---|---|
| `tcp_server` | SUCCESS | `builds/tcp_server/tcp_server.exe` (1 341 456 B) | 569 480 B | `ECD270380F875E6F0CA1BCCAFDDD42BBA407CD3A03F114C40493969B6BD17DA3` |
| `tcp_client` | SUCCESS | `builds/tcp_client/tcp_client.exe` (1 341 240 B) | 569 288 B | `245D5065325B089A808163CEC6277CAD4C3C484346B6F94FEC0060D724136C5A` |
| `udp_server` | SUCCESS | `builds/udp_server/udp_server.exe` (1 340 776 B) | 568 848 B | `CD91F3DF2981D5C0C1B584080403D29F8DED363679AFB68231074CA9261B9F42` |
| `udp_client` | SUCCESS | `builds/udp_client/udp_client.exe` (1 341 164 B) | 569 200 B | `68E2C6ECD974306309525571627E174809F3B0C7334FFF2FC0BB80F2968A7BB4` |

No compiler warning and no error remains in `main.c`, `lwip_test.h`,
`lwip_test.c`, `tcp_server.c`, `tcp_client.c`, `udp_server.c` or `udp_client.c`
(see the four logs in `results/logs/`). Warnings from third-party code
(yaffs2, lwIP, RT-Thread, ls1x-drv) were left untouched.

**A successful build is not a successful experiment**: the compilations only prove
that the code and the configuration are consistent. They say nothing about the
network behaviour on the board, which is what sections 8.2.10–8.2.15 of the guide
must establish on the real hardware.
