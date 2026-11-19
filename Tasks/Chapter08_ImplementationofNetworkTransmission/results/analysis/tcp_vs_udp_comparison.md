# TCP versus UDP, as demonstrated by the four experiments

Two kinds of statements appear in this document and they are kept apart on
purpose:

* **[T]** = general protocol knowledge, valid independently of this project.
* **[P]** = a fact about *this* project, verifiable in the source code, the build
  logs or the firmware images (with the file that proves it).
* **[E]** = experimental evidence from the board. **There is none yet** — the
  hardware runs of sections 8.2.12–8.2.15 have not been performed, so no
  behavioural claim below is presented as measured.

---

## 1. Connection-oriented versus connectionless

**[T]** TCP is connection-oriented: before any byte of user data can flow, both
ends agree on a connection through a three-way handshake (SYN, SYN-ACK, ACK);
sequence numbers are negotiated and every segment is acknowledged. The
"connection" is state kept by both operating systems, not a physical circuit.

**[T]** UDP is connectionless: each datagram is an independent, self-contained
message carrying its own destination (and, on arrival, its source) address. No
state is established, nothing is acknowledged, nothing is retransmitted.

**[P]** The difference is visible in the socket calls of this project:

| | TCP (`tcp_server.c`, `tcp_client.c`) | UDP (`udp_server.c`, `udp_client.c`) |
|---|---|---|
| Socket type | `SOCK_STREAM`, protocol `6` (server) | `SOCK_DGRAM`, protocol `0` |
| Setup | `bind` + `listen` + `accept` (server), `connect` (client) | `bind` only (server); `sendto` with an address (client) |
| Data calls | `recv` / `send` (no address argument) | `recvfrom` / `sendto` (address argument on every call) |
| Events | `client incoming succeed!` on connect, `client disconnected.` on close | none — only `RECEIVE:` when a datagram arrives |

**[P]** Nothing in the UDP files can report a "connection": `udp_server.c` has no
`listen()`/`accept()`, and `udp_client.c` never calls `connect()` even though it
knows the destination address (`remote_addr` assembled from `remote_IP` and
`UDP_REMOTE_PORT` = 9063).

## 2. TCP connection establishment and release

**[T]** In the log of experiment A the client's `connect()` and the server's
`accept()` complete only after the handshake; from then on the pair of sockets is
identified by the 4-tuple (source IP, source port, destination IP, destination
port). Closing is a separate handshake (FIN/ACK in both directions), which is why
a server can see "connection closed" as an event.

**[P]** `tcp_server.c` is written exactly around those events: the outer loop
blocks in `accept()`, the inner loop blocks in `recv()` until either data
(`err > 0` → echo) or the peer's close (`err <= 0` → `disconnect client succeed!`
and back to `accept()`), so one client after another can be served without
restarting the firmware.

**[P]** `tcp_client.c` performs `connect()` once and then runs five
send/receive cycles on the same socket — the connection persists across all five
messages, which is what a connection-oriented protocol makes possible.

**[E]** Still to be observed: the actual handshake on the wire, the actual
`client incoming succeed!` line, and the actual disconnect behaviour.

## 3. Reliable, ordered byte stream versus independent datagrams

**[T]** TCP presents a *byte stream*: the receiver may get the bytes split or
merged differently from the sender's writes, but the order and completeness are
guaranteed; lost segments are retransmitted. UDP preserves *message boundaries*
(one `sendto` = at most one `recvfrom`) but guarantees nothing about delivery,
order or duplication.

**[P]** Both demos rely on this difference in a way the code makes visible:

* TCP server echoes with `send(client_fd, data_buf, err, 0)` where `err` is the
  number of bytes `recv()` returned — the count is the only thing that matters,
  boundaries are irrelevant.
* UDP server echoes the same way, but the *address* must be carried over from the
  `recvfrom()` to the `sendto()` call, because UDP has no connection to remember
  who the peer is.
* The 256-byte buffers (`TCP_SERVER_BUFSIZE`, `UDP_SERVER_BUFSIZE`, …) are large
  enough for the short test strings, so the lab never exercises segmentation or
  fragmentation. This is a deliberate simplification of the experiment, not a
  protocol limitation.

**[E]** Not yet observed: retransmission behaviour, ordering, or datagram loss.

## 4. Server and client roles in each protocol

**[T]** In TCP the roles are inherent: the server owns a *listening* socket on a
well-known port and creates a new socket per accepted connection; the client owns
an *ephemeral* port and initiates the handshake. In UDP there is no such
asymmetry — every socket can send and receive, so "server" and "client" are
conventions: the side that waits on a fixed port is called the server, the side
that sends first is called the client.

**[P]** The laboratory follows that convention:

| Experiment | Board | PC | Fixed port on |
|---|---|---|---|
| A | TCP server (listens) | TCP client (connects) | board, 9060 |
| B | TCP client (connects) | TCP server (listens) | PC, 9061 |
| C | UDP "server" (binds, waits) | UDP sender | board, 9062 |
| D | UDP "client" (sends first) | UDP receiver | PC, 9063 |

**[P]** The guide itself admits the asymmetry in its note to section 8.2.15:
"essentially, UDP does not distinguish between the server and the client … the
side that actively sends the information is the client."

## 5. How the board and the PC exchange messages in each experiment

**[P]** The exact bytes are fixed by the source:

| Exp. | Board sends | PC sends | Board API calls |
|---|---|---|---|
| A | echo of what it received | whatever is typed in NetAssist | `accept` → `recv` → `send` loop |
| B | `client ticks = <N>.\n` (N = ms since boot, five times) | any reply text | `connect` → `send` → `recv` ×5 → `close` |
| C | echo of the received datagram | `UDP hello` (any text) | `recvfrom` → `sendto` loop |
| D | `client ticks = <N>.` (no newline, five times) | any reply text | `sendto` → `recvfrom` ×5 → `close` |

**[P]** A subtle but practical consequence of UDP: in experiments C and D the
PC's program must already be *listening* on its port when the first datagram is
sent. Nothing in UDP ensures the peer exists, so `udp_client.c` waits in
`recvfrom()` for a reply that will never come if NetAssist was opened after the
board booted. In the TCP experiments the handshake itself acts as this
synchronisation: `connect()` on the board cannot succeed before the PC server
listens, and the log says so (`failed to connect to server!`).

## 6. Why the four tests need different configurations

**[T]+[P]** Because ports and roles are not interchangeable:

1. **TCP needs a listener on the receiving side.** Experiment A therefore puts
   NetAssist in *TCP Client* (it connects to the board's listener); experiment B
   puts NetAssist in *TCP Server* mode on 9061 *before* the board starts.
2. **UDP needs no listener but needs the destination address** in every
   `sendto()`. NetAssist must be in *UDP* mode; the "local port" it binds is the
   port the reply must come back to (9063 in experiment D), while the "remote
   port" is the board's port (9062 in experiment C).
3. **The same port number means different things.** 9060/9062 are bound on the
   board; 9061/9063 are bound on the PC. Mixing them up produces a silent timeout
   (UDP) or a refused connection (TCP).
4. **The manual's section 8.2.14 is wrong on exactly this point** — it asks for
   *TCP Server* mode with the PC at port 9062 for the UDP test. A TCP client
   cannot reach `udp_server.c`, which only ever creates a `SOCK_DGRAM` socket.
   Section 8.2.15's "TCP UDP" is a typo as well.

## 7. What each protocol makes easy to observe in this lab

| Observation | TCP (A, B) | UDP (C, D) |
|---|---|---|
| Explicit connection event in the console | yes (`client incoming succeed!`) | no |
| Effect of the peer not being ready | `connect()` fails / blocks, error printed | datagram lost silently, board waits in `recvfrom()` |
| Relation between what is sent and received | stream of bytes, same content | one datagram in, one datagram out |
| Ending the exchange | close handshake, socket destroyed | nothing to close; just stop sending |
| Log length | five cycles then `tcp_client_thread stop!` | five cycles then `udp_client_thread stop!` |

All rows in this table describe *the code*, i.e. what the programs are built to
do. The corresponding hardware observations are still **pending** and will be
added to this document (and to `tcp_*_analysis.md` / `udp_*_analysis.md`) only
when genuine screenshots and console captures exist.
