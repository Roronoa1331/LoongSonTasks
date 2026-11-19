# Technical Report

## Chapter 7 — Operating System Application Example 1: The Sleeping-Barber Problem

| | |
|---|---|
| Course | Computer System Comprehensive Design Experiment |
| Target platform | Loongson 1B / LS1B200, MIPS32 little-endian, 64 MB RAM |
| Operating system | RT-Thread 4.0.2 |
| Toolchain | mips-sde-elf (SDE Lite 4.5.2 for MIPS) inside LoongIDE |
| Project | `RThread6` |
| Deliverable | `Build/RThread6.exe` (ELF32 MIPS LE), `Build/RThread6.bin` |
| Date of build/test | see `Build/RThread6.exe` timestamp; logs in `tests/host_sim/out/` |

---

## 1. Introduction

Chapter 7 of the guide introduces the classical process-synchronization problem
of the barbershop and solves it with semaphores and a mutex inside RT-Thread.
The chapter consists of:

* the problem description and its five shop events (section 7.0),
* the design content — the synchronization objects and the PV algorithm
  (section 7.1, Code Listing 11-58),
* the design steps inside LoongIDE (section 7.2, Code Listing 11-59),
* the compilation, download and console verification procedure (section 7.2.1).

This report documents the design decisions, the reasoning behind the
synchronization, and the verification that was actually carried out.

## 2. Requirements extracted from Chapter 7

| Id | Requirement (source) | Where it is implemented |
|---|---|---|
| R1 | A waiting room with several chairs and a barber room with one chair (7.0) | `WAITING_CHAIRS = 3` → `freeseats`, one `barber_thread` |
| R2 | The barber sleeps when no customer waits (7.0 (1)) | `rt_sem_take(customers, RT_WAITING_FOREVER)` blocks on value 0 |
| R3 | A customer arriving while the barber is busy sits on a free chair (7.0 (2)) | `if (freeseats > 0) { freeseats--; ... }` |
| R4 | A customer arriving while the barber sleeps wakes him (7.0 (3)) | `rt_sem_release(customers)` → the barber's `rt_sem_take` returns |
| R5 | A customer arriving at a full waiting room leaves (7.0 (4)) | `else { rt_kprintf("customers %d leave.\n", ...); }` |
| R6 | No deadlock ("barber waiting for a customer while the customer waits for the barber") | customer releases `mutex` before `P(barber)` |
| R7 | No starvation (customers must be served in order) | one `V(barber)` per `P(customers)`; RT-Thread priority + FIFO wake-up |
| R8 | 3 semaphores and 1 variable: `freeseats`, `customers`, `barber`, `mutex` (7.1) | declared in `main.c` with initial values N, 0, 0, 1 |
| R9 | PV algorithm of Code Listing 11-58 | `barber_thread()` / `customer_thread()` |
| R10 | RT-Thread solution, 1 barber + 5 customer threads, different customer priorities to simulate the arrival order (7.2) | `rt_thread_create("barber", ..., THREAD_PRIORITY, ...)` and `j = THREAD_PRIORITY - 5 + i` |
| R11 | Project created with the LoongIDE New Project Wizard, named `RThread6` (7.2 (2)) | `RThread6.lxp` |
| R12 | Design code written into `main.c` after deleting the template code (7.2 (6)) | `main.c` |
| R13 | Build with `Project → Compile & Build` (7.2.1 (1)) | `RThread6.lxp`, `Build/` |
| R14 | Observe the printed test information in PuTTY on the virtual serial port at 115200 (7.2.1 (5)-(12)) | `console_init(115200)` → `ConsolePort` = `devUART5` |

## 3. Design

### 3.1 Thread model

| Thread | Priority | Stack | Timeslice | Behaviour |
|---|---|---|---|---|
| `main` | 10 (`RT_MAIN_THREAD_PRIORITY`) | 8 KB | — | initialises the BSP, creates the IPC objects, creates and starts the six application threads, then exits |
| `barber` | 10 | 20 KB | 5 ticks | infinite loop: `P(customers)`, `P(mutex)`, `freeseats++`, `V(barber)`, `V(mutex)`, cut hair 40 ms |
| `customer` ×5 | 5, 6, 7, 8, 9 | 20 KB | 5 ticks | wait 50 ms (arrival), `P(mutex)`, sit down or leave, `V(customers)`, `V(mutex)`, `P(barber)` |

RT-Thread has 32 priority levels, `0` being the highest. The five customers
are given priorities 5…9 — all **higher** than the barber's 10 — which is what
makes the arrival order of the guide reproducible: when the 50 ms delays
expire, the scheduler runs customer 1 first, then 2, …, then 5.

The tick is 1000 Hz (`RT_TICK_PER_SECOND 1000`), so `rt_thread_mdelay(40)` and
`rt_thread_mdelay(50)` correspond to 40 ms and 50 ms.

### 3.2 Synchronization objects

| Object | RT-Thread type | Initial value | Protected data |
|---|---|---|---|
| `customers` | `rt_sem_t` (counting) | 0 | number of customers waiting for a haircut |
| `barber` | `rt_sem_t` (counting) | 0 | "barber is ready for the next seated customer" |
| `mutex` | `rt_mutex_t` | 1 | `freeseats` |
| `freeseats` | `unsigned char` | 3 | chairs still free |

All three IPC objects are created with `RT_IPC_FLAG_PRIO`, so waiters are woken
in priority order, and FIFO among equal priorities — that is the property that
turns R7 (no starvation) into a guarantee rather than a hope.

### 3.3 Event sequences

**Barber.** The thread starts before any customer exists. Its first
`rt_sem_take(customers, RT_WAITING_FOREVER)` cannot succeed because the
semaphore value is 0, so the thread is placed on the semaphore's wait list and
the scheduler switches away. This state — a thread blocked on an empty
counting semaphore — *is* "the barber is sleeping".

**Customer with a free chair.** Takes the mutex, decrements `freeseats`, prints
the new free-seat count, `V(customers)`, releases the mutex, prints that it is
waiting, and blocks in `P(barber)`. The `V(customers)` makes the barber runnable
(priority 10 versus the customer's 5…9, so the customer is not preempted — it
finishes its critical section first, which is exactly what the algorithm assumes).

**Customer at a full waiting room.** `freeseats == 0`; it prints
`customers N leave.`, releases the mutex and its thread entry returns, which
makes RT-Thread delete the thread.

**Barber waking up.** `P(customers)` returns, the barber prints
`barber find customer N .`, enters the critical section, restores one chair
(`freeseats++`), signals `barber` for exactly that customer, leaves the critical
section and cuts hair for 40 ms. Then it loops back to `P(customers)`.

### 3.4 Output design

The printed messages are the ones of Code Listing 11-59, unchanged, so the trace
can be compared one-to-one with Figure 7.14 of the guide:

| Message | Meaning |
|---|---|
| `create semaphore barber done.  The value of barber = 0` | `barber` created, barber asleep |
| `create semaphore customers done. The value of customers = 0` | `customers` created |
| `create mutex is sucessful.` | mutex created (spelling as in the guide) |
| `barber thread  startup.` / `customers N thread  startup.` | threads created and started |
| `freeseats=K` | a customer just took a chair; K chairs are still free |
| `customers N is waitting to cut hair.` | customer N will wait for the barber |
| `customers N leave.` | waiting room full, customer N leaves |
| `barber find customer N .` | the barber woke up and accepted a customer |
| `barber begin to cut hair.` / `barber finish cut hair.` | the haircut interval |

## 4. Correctness analysis

### 4.1 Mutual exclusion

`freeseats` is read and written only inside the `rt_mutex_take(mutex)` …
`rt_mutex_release(mutex)` region, in both the barber and the customer code.
RT-Thread mutexes are recursive and owned, so no other thread can be inside the
same region. Consequently the check `freeseats > 0` and the decrement are atomic
and, with N = 3, at most three customers can ever be seated.

### 4.2 Freedom from deadlock

The only two blocking resources are `mutex` and the semaphores.

* The barber acquires `mutex` only *after* `P(customers)` succeeded, and it never
  blocks while holding it.
* A customer releases `mutex` **before** it executes `P(barber)`. Therefore a
  customer can never hold the mutex while waiting for the barber, and the barber
  can never wait for a mutex held by a thread that waits for the barber — the
  deadlock named in the chapter cannot occur.
* `V(barber)` is executed by the barber for every `P(customers)`, so no customer
  can wait on `barber` without a matching signal; `P(barber)` is therefore
  guaranteed to return.

### 4.3 No lost wake-up

`V(customers)` is executed while the customer still holds the mutex. Even if the
barber is not scheduled immediately, the counting semaphore keeps the value, so
the wake-up cannot be lost. Conversely the barber never executes `P(mutex)` while
holding a value of `customers` it has not yet consumed.

### 4.4 No starvation

Each iteration of the barber consumes exactly one unit of `customers` and emits
exactly one unit of `barber`. Customer *i* blocks in `P(barber)` only after its
own `V(customers)`, so it is guaranteed to be matched by one of the barber's
future iterations. Wait lists are ordered by priority and, within a priority, by
arrival (FIFO), so no seated customer is skipped.

### 4.5 Bounded waiting room

`freeseats` starts at N and only changes inside the mutex:
`freeseats--` once per seated customer and `freeseats++` once per accepted
customer. Hence `0 <= freeseats <= N` holds at all times — this is the invariant
that the automated tests check on every printed value.

## 5. Verification

### 5.1 Static verification (build)

The project was compiled with the same flags LoongIDE generates
(`-mips32 -G0 -EL -msoft-float -DLS1B -DOS_RTTHREAD -O0 -g -Wall`):

```text
mips-sde-elf-gcc -mips32 -G0 -EL -msoft-float ... -c ../main.c -o main.o
...
   text    data     bss     dec     hex filename
 252196    5064   24024  281284   44ac4 RThread6.exe
Finished building target: RThread6.exe
```

`main.c` compiles with **no warnings**. (The remaining warnings of the build come
from the unmodified RT-Thread/newlib sources, e.g.
`dfs_select.h` and `ns16550.c`, and are pre-existing.)

The produced image was inspected:

```text
ELF 32-bit LSB executable, MIPS, MIPS32 rel2, statically linked,
entry point 0x80200000
```

and contains the expected strings (`barber find customer %d .`,
`freeseats=%d`, `customers %d leave.`, …), which proves the Chapter 7 code is
really linked into the downloadable image.

**Build reproducibility note.** The dependency files that the compiler writes
(`-MMD -MP`) each contain a rule whose target is the `*.d` file itself. Because
`Build/Makefile.mk` includes them, GNU make adopted the first such rule as its
default goal as soon as the project had been built once, and a plain
`make -f Makefile.mk` answered *"Nothing to be done for `main.d'"* instead of
rebuilding. The project therefore ships [`makefile.init`](makefile.init) — a hook
that `Build/Makefile.mk` includes at the very top and that LoongIDE does **not**
regenerate — which pins `.DEFAULT_GOAL := all`. `build.bat` additionally names
the `all` target explicitly. Both paths were verified: an up-to-date tree answers
`Nothing to be done for 'all'`, and after touching `main.c` the image is rebuilt
and relinked.

### 5.2 Dynamic verification (execution)

Because the LS1B board is not attached to the machine used for this report, the
algorithm was executed instead of only compiled. `tests/host_sim/` provides:

* `rtthread.h` / `bsp.h` — drop-in replacements of the two headers `main.c`
  includes;
* `rtthread_sim.c` — a simulator that implements `rt_sem_create/take/release`,
  `rt_mutex_create/take/release`, `rt_thread_create/startup/mdelay` and
  `rt_kprintf` on top of Win32 threads, with RT-Thread's scheduling rules
  (highest priority runs, immediate preemption, simulated ticks advance only
  when no thread is runnable);
* `main_host.c` — runs the **unmodified** `main.c` and reports the final thread
  states;
* `run_scenarios.ps1` — builds and runs nine shop configurations and checks the
  invariants of section 13.3 of the README.

#### Results

| Scenario | Customers | Chairs | Seated | Turned away | Haircuts | Result |
|---|---|---|---|---|---|---|
| S1 zero customers | 0 | 3 | 0 | 0 | 0 | PASS |
| S2 one customer | 1 | 3 | 1 | 0 | 1 | PASS |
| S3 one chair | 1 | 1 | 1 | 0 | 1 | PASS |
| S4 three customers | 3 | 3 | 3 | 0 | 3 | PASS |
| S5 guide default | 5 | 3 | 3 | 2 | 3 | PASS |
| S6 enough chairs | 5 | 5 | 5 | 0 | 5 | PASS |
| S7 single chair, long run | 20 | 1 | 2 | 18 | 2 | PASS |
| S8 ten chairs, long run | 20 | 10 | 11 | 9 | 11 | PASS |
| S9 twenty chairs | 20 | 20 | 20 | 0 | 20 | PASS |
| S5 repeated ×10 | 5 | 3 | 3 | 2 | 3 | PASS (identical traces) |

Observations:

* **Zero customers (S1).** Only the startup lines are printed. The barber is the
  single blocked thread, sitting on `cust_sem`, which is the correct "sleeping"
  state. No deadlock: nothing else exists.
* **Customers while the barber sleeps (S2).** The barber's `P(customers)`
  returns as soon as the customer executes `V(customers)`.
* **Waiting room full (S5, S7, S8).** `freeseats` reaches 0 and the extra
  customers print `customers N leave.`; the number of arrivals that were seated
  never exceeds N *at the same moment* (S7 seats 2 over time with a single chair,
  S8 seats 11 over time with 10 chairs — because the barber keeps freeing chairs
  between arrivals).
* **Long runs (S7–S9).** No leak, no livelock, always exactly one blocked thread
  at the end.
* **Repeatability.** Ten consecutive executions of the same binary produced
  byte-identical traces, i.e. the outcome does not depend on thread scheduling
  races.

#### Why the host simulator is a valid check

It is not a re-implementation of the algorithm: the algorithm object under test
is `../../main.c` itself, compiled unchanged. Only the RT-Thread *services* are
replaced. The simulator deliberately keeps the semantics that matter for this
problem — priority-ordered preemption, counting semaphores, owned mutexes, and
blocking delays — so the invariant checks exercise the real PV code.

### 5.3 What could not be verified here

Running the firmware on a physical Loongson 1B board and reading the output in
PuTTY (guide section 7.2.1 steps 2–12) requires the hardware, the USB-to-serial
cable on UART5 and LoongIDE's download/debug connection. That step is documented
in the README (section 11.3) but was **not** performed on this machine. The
image itself is built and structurally verified.

## 6. Deviations from the printed listing

See the table in README section 14. Summary:

1. `customer_thread` must have a `void *` parameter (RT-Thread thread entry
   signature); the customer number is passed by address.
2. `static` local variables in the thread functions were made real locals — with
   `static` all five customer threads would share one `res` variable.
3. The customer-number array is initialised with a loop instead of a fixed
   `{0,1,2,3,4}` initialiser so that larger shops used by the tests work.
4. A `RT_NULL` check of the three created IPC objects was added.
5. `customer_num` and `WAITING_CHAIRS` keep the guide's values (5 and 3) as
   defaults but are wrapped in `#ifndef` so the tests can build other shops.

The message strings, priorities, delays, timeslice, PV structure and the
20 KB stack size are exactly the guide's.

## 7. Conclusion

The Sleeping-Barber problem of Chapter 7 was implemented on the Loongson 1B with
RT-Thread as required: one barber thread, five customer threads with distinct
priorities, a three-chair waiting room, and the chapter's `customers`/`barber`
semaphores plus `mutex` guarding `freeseats`. The PV algorithm is reproduced
without changing its semantics, the design compiles into a valid MIPS32
little-endian image without warnings, and the synchronization was executed and
checked in nine configurations — all passed, with mutual exclusion, bounded
capacity, absence of deadlock and livelock, no lost customer and deterministic
behaviour.

## Appendix A — Build log excerpt

```text
Building file: ../main.c
mips-sde-elf-gcc.exe -mips32 -G0 -EL -msoft-float -DLS1B -DOS_RTTHREAD -O0 -g -Wall
    -c -fmessage-length=0 -pipe -I"../" -I"../include" -I"../RTT4/include" ...
Finished building: ../main.c
...
Invoking: SDE Lite C Linker
mips-sde-elf-gcc.exe -mips32 -G0 -EL -msoft-float -nostartfiles -static
    -T ../ld.script -o RThread6.exe -e start ...
Invoking: SDE Lite C Objcopy
mips-sde-elf-objcopy.exe -O binary RThread6.exe RThread6.bin
   text    data     bss     dec     hex filename
 252196    5064   24024  281284   44ac4 RThread6.exe
Finished building target: RThread6.exe
```

## Appendix B — Guide reference

| Guide section | Content | Where |
|---|---|---|
| 7.0 | Problem description, events (1)–(4), deadlock and starvation remarks | README §2, §5 |
| 7.1 | `freeseats`, `customers`, `barber`, `mutex`; PV definitions; Code Listing 11-58 | README §7, §8 |
| 7.2 | RT-Thread design steps; naming the project `RThread6`; Code Listing 11-59 | `main.c`, `RThread6.lxp` |
| 7.2.1 | Compile & Build, USB/serial wiring to UART5, PuTTY on COM5 @ 115200, Debug → Run | README §11.3 |
| Figure 7.1 | Barbershop layout | `docs/diagrams/diagrams.md` §1 |
| Figure 7.14 | Console output | README §12 |
