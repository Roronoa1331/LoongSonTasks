# RThread6 — Chapter 7: The Sleeping-Barber Problem (Loongson 1B + RT-Thread)

Complete, buildable and tested implementation of section 7 of the
*Computer System Comprehensive Design Experiment Guide* —
**"7. Operating System Application Example 1: The Sleeping-Barber Problem"**.

The project is a LoongIDE RT-Thread application for the Loongson 1B
(LS1B / LS1B200, MIPS32 little-endian) development board. The whole design
code lives in a single [`main.c`](main.c) file, exactly as requested by
step 7.2 (6) of the guide: *"Delete the example code provided by the design
template in this file, and then add the design code, as shown in Code
Listing 11-59."*

---

## 1. Project overview

| Item | Value |
|---|---|
| Guide chapter | 7 — Operating System Application Example 1: The Sleeping-Barber Problem |
| Guide source listings | Code Listing 11-58 (PV operations), Code Listing 11-59 (C code in `main.c`) |
| Project folder | `Chapter07_SleepingBarber` (named after the manual's section title) |
| Project name used by the guide | `RThread6` (step 7.2 (2)) — kept for the LoongIDE project file |
| Board | Loongson 1B / LS1B200, MIPS32 little-endian |
| Operating system | RT-Thread 4.0.2 (`RTT4/`) |
| Toolchain | `mips-sde-elf-*` — SDE Lite 4.5.2 for MIPS (`E:\LoongIDE\mips-2011.03\bin`) |
| IDE | LoongIDE (`RThread6.lxp`) |
| Console | UART5, 115200 baud, 8 data bits, no parity, 1 stop bit |
| Threads | 1 barber (priority 10) + 5 customers (priorities 5…9) |
| IPC objects | `customers` semaphore, `barber` semaphore, `seatmutex` mutex, `freeseats` variable |
| Waiting-room chairs | N = 3 |

## 2. Problem statement

> A barbershop consists of a waiting room with *N* chairs and a barber room
> with one barber chair. The barber sleeps when there is no customer. A
> customer that arrives while the barber is cutting hair sits down on a free
> chair, if there is one. A customer that arrives while the barber sleeps
> wakes the barber up. A customer that arrives when every chair is occupied
> leaves the shop.

Two hazards are named explicitly in the chapter and must be prevented:

1. **Deadlock** — "if a barber is waiting for a customer while the customer is
   waiting for the barber".
2. **Starvation** — "if some customers do not wait for haircuts in order, some
   waiting customers may never get a haircut".

## 3. Objectives

* Implement the barber process/thread, the customer processes/threads, the
  bounded waiting room and the sleeping/waking protocol of the chapter.
* Use exactly the synchronization objects the chapter introduces:
  `freeseats` (variable), `customers` (semaphore, 0), `barber` (semaphore, 0)
  and `mutex` (mutex, 1).
* Demonstrate the five events of the barbershop on the serial console:
  a customer enters, a customer leaves, the barber sleeps, a customer waits on
  a chair, the barber cuts hair.
* Prove that the design is free of race conditions, deadlock and starvation.

## 4. Technologies used (and why)

| Technology | Reason |
|---|---|
| **C** | The guide's listings are C, and the LS1B BSP, the RT-Thread kernel and the LoongIDE templates are C. |
| **RT-Thread 4.0.2** | The chapter explicitly states: *"This section solves the Sleeping-Barber problem in the RT-Thread operating system."* It supplies `rt_sem_*`, `rt_mutex_*`, `rt_thread_*` and `rt_kprintf()`. |
| **LoongIDE + mips-sde-elf GCC** | The chapter's build and download steps (7.2.1) are written for LoongIDE and the Loongson 1B board. |
| **GNU make** (optional) | The makefiles that LoongIDE generates in `Build/` can be driven from a command line, which is what was used to verify the build here. |
| **Host RT-Thread simulator** (test only) | The board is not required to *verify* the algorithm: `tests/host_sim/` compiles the real `main.c` against a small RT-Thread API shim so the exact same source can be executed and checked on a PC. |

No extra libraries, no dynamic allocation beyond RT-Thread's heap, no FPU
(`-msoft-float`), no network, no file system.

## 5. Explanation of the Sleeping-Barber problem

Figure 7.1 of the guide shows one barber room (with the barber chair) and a
waiting room with several chairs. The events that can occur are:

* `(1)` If no customer waits, the barber goes to sleep.
* `(2)` A customer that arrives while the barber is busy and finds a free chair
  sits down.
* `(3)` A customer that arrives while the barber sleeps wakes the barber.
* `(4)` A customer that arrives when all chairs are occupied leaves.

Section 7.1 then names the four synchronization objects of the solution:

| Object | Kind | Initial value | Meaning |
|---|---|---|---|
| `freeseats` | shared variable | `N` (3) | chairs still free in the waiting room |
| `customers` | counting semaphore | `0` | number of customers waiting for a haircut |
| `barber` | counting semaphore | `0` | barber state: sleeping (0) / ready to cut |
| `mutex` | mutex | `1` | protects the critical section around `freeseats` |

> The chapter calls these "3 semaphores and 1 variable"; in RT-Thread terms it
> is **2 counting semaphores + 1 mutex + 1 variable**. The implementation
> follows the object list, not the wording.

## 6. Project architecture

```text
Chapter07_SleepingBarber/
├── main.c                    Chapter 7 design code (Code Listing 11-59)
├── include/                  Board + kernel configuration used by main.c
│   ├── bsp.h                 LS1B BSP interface (ls1x_drv_init, ...)
│   ├── rtconfig.h            RT-Thread configuration (32 priorities, 1000 Hz tick)
│   ├── app_os_priority.h     Priority assignment helpers of the template
│   └── queue_list.h          Template support header
├── RTT4/                     RT-Thread 4.0.2 kernel, LS1B port and components
│   ├── src/                  scheduler, thread, ipc, timer, mem, ...
│   ├── port/                 MIPS32 context switch, interrupt/tick, heap start
│   ├── components/           finsh (msh), dfs, libc, drivers
│   └── bsp-ls1x/             RT-Thread device drivers for the LS1B UARTs
├── ls1x-drv/                 Loongson 1B bare-metal drivers
│   ├── console/console.c     rt_hw_console_output() → ConsolePort (UART5)
│   ├── uart/ns16550.c        NS16550-compatible UART driver
│   └── ...                   gpio, i2c, spi, pwm, rtc, nand, fb, gmac, ...
├── src/install_3th_libraries.c   Third-party library installation hook
├── ld.script                 Memory layout: code at 0x80200000, entry `start`
├── Build/                    Generated LoongIDE makefiles + build output
│   ├── RThread6.exe          ELF32 MIPS little-endian executable
│   └── RThread6.bin          Raw binary image
├── RThread6.lxp              LoongIDE project file
├── RThread6.layout           LoongIDE editor layout
├── build.bat                 One-command build from a Windows shell
├── makefile.init             User hook included by Build/Makefile.mk
│                             (fixes make's default goal after a rebuild)
├── docs/
│   ├── report.md             Technical report (design, analysis, test results)
│   └── diagrams/diagrams.md  Architecture, state machines, timeline (Mermaid)
├── tests/host_sim/           Automated host tests of the very same main.c
└── README.md
```

Only `main.c` is the application. Everything else is the platform: the
RT-Thread kernel, the MIPS32 port, the LS1B drivers and the LoongIDE build
infrastructure, identical to the project the wizard generates in step 7.2.

## 7. Semaphores and mutexes used

### `customers` — counting semaphore, initial value 0

Counts the customers that have sat down and are waiting for the barber.
`V(customers)` is executed by a customer after it takes a chair,
`P(customers)` by the barber before it accepts one customer.
Because the value starts at `0`, the barber's first `P(customers)` blocks —
that *is* the barber going to sleep.

### `barber` — counting semaphore, initial value 0

Signals "the barber is ready to cut the hair of the customer it just picked".
The barber executes `V(barber)` once per accepted customer, the customer
executes `P(barber)` to wait for its turn.

### `mutex` (`seatmutex`) — mutex, initial value 1

Protects the critical section that reads and writes `freeseats`
(read-modify-write). Without it two customers arriving at the same time could
both observe `freeseats == 1` and both take the last chair — a classic race
condition.

### `freeseats` — shared variable, initial value N = 3

Number of chairs still free. It is only accessed while `mutex` is held.

## 8. Synchronization algorithm

The implementation is the chapter's Code Listing 11-58, one-to-one:

```text
process barber() {                     process customer() {
    while (true) {                         P(mutex);
        P(customer);                       if (freeseats > 0) {
        P(mutex);                              freeseats--;
        freeseats++;                           V(customers);
        V(barber);                             V(mutex);
        V(mutex);                              P(barber);
    }                                      } else {
}                                              V(mutex);
                                           }
                                       }
```

Mapped onto RT-Thread (`main.c`):

| PV operation | RT-Thread call |
|---|---|
| `P(customers)` / `V(customers)` | `rt_sem_take(customers, RT_WAITING_FOREVER)` / `rt_sem_release(customers)` |
| `P(barber)` / `V(barber)` | `rt_sem_take(barber, RT_WAITING_FOREVER)` / `rt_sem_release(barber)` |
| `P(mutex)` / `V(mutex)` | `rt_mutex_take(mutex, RT_WAITING_FOREVER)` / `rt_mutex_release(mutex)` |

Four properties of the algorithm make it correct:

1. **Mutual exclusion** — every access to `freeseats` happens between
   `rt_mutex_take()` and `rt_mutex_release()`, so the check-and-decrement is
   atomic and the waiting room can never be over-filled.
2. **No deadlock, because of the release order** — a customer releases `mutex`
   *before* it blocks in `P(barber)`. The barber therefore never has to wait
   for a mutex owned by a customer that is itself waiting for the barber.
3. **No missed wake-up** — `V(customers)` is executed while the customer still
   holds the mutex, i.e. before the barber can possibly finish its
   `P(customers)`/`P(mutex)` pair. The counting semaphore remembers the wake-up
   even if the barber is not scheduled immediately.
4. **No starvation** — the barber performs exactly one `V(barber)` for each
   `P(customers)`, so every customer that got a chair is served. RT-Thread
   mutexes and semaphores wake waiters in priority order and preserve FIFO
   among equal priorities.

## 9. Explanation of each important source file

| File | Role |
|---|---|
| [`main.c`](main.c) | The whole Chapter 7 application: the two semaphores, the mutex, `freeseats`, `barber_thread()`, `customer_thread()` and `main()` including the "create → startup" sequence and the console output. |
| [`include/rtconfig.h`](include/rtconfig.h) | Kernel configuration: `RT_THREAD_PRIORITY_MAX 32`, `RT_TICK_PER_SECOND 1000`, heap, semaphore/mutex/event/mailbox, console, finsh, `RT_USING_UART5`. |
| [`include/bsp.h`](include/bsp.h) | Declares `ls1x_drv_init()`, `rt_ls1x_drv_init()`, `install_3th_libraries()`, `printk`/`DBG_OUT` and the enabled LS1B peripherals (UART5 is the console). |
| [`RTT4/src/ipc.c`](RTT4/src/ipc.c) | RT-Thread semaphore and mutex implementation (counting value, waiter lists, priority inheritance). |
| [`RTT4/src/scheduler.c`](RTT4/src/scheduler.c) | Priority preemptive scheduler — the reason the five customers run in priority order. |
| [`RTT4/src/thread.c`](RTT4/src/thread.c) | `rt_thread_create()`, `rt_thread_startup()`, `rt_thread_mdelay()`, stack overflow check. |
| [`RTT4/port/bsp_start.c`](RTT4/port/bsp_start.c) | `rt_hw_board_init()`: heap init, `console_init(115200)`, tick, interrupts, then starts the main thread. |
| [`RTT4/port/start.S`](RTT4/port/start.S) | Reset entry `start`, `.bss` clear, stack set-up, jump to `rt_hw_board_init`. |
| [`ls1x-drv/console/console.c`](ls1x-drv/console/console.c) | `rt_hw_console_output()` — every `rt_kprintf()` finally lands here and goes to `ConsolePort` = `devUART5`. |
| [`ls1x-drv/uart/ns16550.c`](ls1x-drv/uart/ns16550.c) | NS16550-compatible UART driver used by the console. |
| [`ld.script`](ld.script) | Places `.text` at `0x80200000` (KSEG0), entry symbol `start`. |
| [`src/install_3th_libraries.c`](src/install_3th_libraries.c) | Hook called by `main()` before the threads are created. |
| [`makefile.init`](makefile.init) | Hook that `Build/Makefile.mk` includes first; pins `.DEFAULT_GOAL := all` so a rebuild is never mistaken for "nothing to be done" once the `*.d` files exist. |
| [`build.bat`](build.bat) | One-command build: sets `PATH`, runs `make -f Makefile.mk all`. |
| [`tests/host_sim/main_host.c`](tests/host_sim/main_host.c) | Test harness: runs the unmodified `main.c` on the PC and checks the invariants. |
| [`tests/host_sim/rtthread_sim.c`](tests/host_sim/rtthread_sim.c) | RT-Thread API simulator (priority preemptive, counting semaphores, mutexes, simulated ticks). |
| [`tests/host_sim/run_scenarios.ps1`](tests/host_sim/run_scenarios.ps1) | Builds and runs nine shop configurations and verifies the traces. |

## 10. Installation

### 10.1 Required software

1. **LoongIDE** (supplies the MIPS toolchain) — installed here at `E:\LoongIDE`.
   The generated makefiles expect the compiler at
   `E:\LoongIDE\mips-2011.03\bin\`.
2. **GNU make** (optional, only for command-line builds). Any of
   `cs-make.exe` (shipped with the toolchain) or MSYS `make`.
3. **PuTTY** (or any serial terminal) for the console output.

Verify the toolchain:

```text
E:\LoongIDE\mips-2011.03\bin\mips-sde-elf-gcc.exe --version
```

### 10.2 Getting the project

Copy the whole `Chapter07_SleepingBarber` folder to the PC. No packages have to be
installed: the RT-Thread kernel, the MIPS port and the LS1B drivers are already
inside the folder.

## 11. How to run the application

### 11.1 Build in LoongIDE (the way the chapter describes)

1. Start LoongIDE.
2. `Project → Open Project…` and select
   [`RThread6.lxp`](RThread6.lxp).
3. `Project → Compile & Build`.
4. The output appears in `Build\RThread6.exe` and `Build\RThread6.bin`.

### 11.2 Build from a command line (verified)

From **PowerShell** (note the `.\` — PowerShell does not run a program from the
current folder by name):

```text
cd c:\Users\testriad\Desktop\LoongSonExamples\Chapter07_SleepingBarber
.\build.bat
```

From **cmd.exe**:

```text
cd /d c:\Users\testriad\Desktop\LoongSonExamples\Chapter07_SleepingBarber
build.bat
```

or manually:

```text
cd Build
make -f Makefile.mk clean
make -f Makefile.mk all
```

`build.bat clean` removes the objects. `make -f Makefile.mk` alone also works
thanks to [`makefile.init`](makefile.init); naming the `all` target explicitly is
the safest form.

Expected result:

```text
   text    data     bss     dec     hex filename
 252196    5064   24024  281284   44ac4 RThread6.exe
Finished building target: RThread6.exe
```

### 11.3 Download and observe (chapter 7.2.1)

1. Connect the board to the PC with the Mini-USB cable and the USB-to-serial
   cable to the **UART5** connector (Figure 7.6).
2. Power on the Loongson 1B board.
3. Open `Device Manager` and note the virtual COM port number (the book's PC
   uses **COM5**, Figure 7.7).
4. Start PuTTY, select `Session`:

   | Setting | Value |
   |---|---|
   | Connection type | `Serial` |
   | Serial line | `COM5` (yours may differ) |
   | Speed | `115200` |

   Click `Open` (Figures 7.13 / 7.14).
5. In LoongIDE choose `Debug → Run`. The program is downloaded and started;
   the trace appears in the PuTTY window.

The same 115200 8-N-1 configuration is hard-coded in the firmware
(`console_init(115200)` in `RTT4/port/bsp_start.c`, `ConsolePort = devUART5`
in `ls1x-drv/include/ns16550.h`).

### 11.4 Run the automated tests (no board required)

```text
cd tests\host_sim
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_scenarios.ps1
```

See [`tests/host_sim/README.md`](tests/host_sim/README.md).

## 12. Example execution

Real output of the default configuration (5 customers, 3 chairs), produced by
executing this project's `main.c`:

```text
Welcome to RT-Thread.

create semaphore barber done.  The value of barber = 0
create semaphore customers done. The value of customers = 0
create mutex is sucessful.
barber thread  startup.
customers 1 thread  startup.
customers 2 thread  startup.
customers 3 thread  startup.
customers 4 thread  startup.
customers 5 thread  startup.
freeseats=2
customers 1 is waitting to cut hair.
freeseats=1
customers 2 is waitting to cut hair.
freeseats=0
customers 3 is waitting to cut hair.
customers 4 leave.
customers 5 leave.
barber find customer 0 .
barber begin to cut hair.
barber finish cut hair.
barber find customer 1 .
barber begin to cut hair.
barber finish cut hair.
barber find customer 2 .
barber begin to cut hair.
barber finish cut hair.
```

Reading the trace:

* `barber thread startup.` then **no** output until `freeseats=2`: the barber
  is blocked in `P(customers)`, i.e. **sleeping**.
* `freeseats=2/1/0` — customers 1, 2 and 3 take the three chairs
  (`freeseats` is printed after the decrement, so a free chair count of `0`
  means the shop is full).
* `customers 1..3 is waitting to cut hair.` — they block in `P(barber)`.
* `customers 4 leave.` / `customers 5 leave.` — the waiting room is full, the
  capacity limit works.
* `barber find customer N` / `begin` / `finish` × 3 — the barber woke up on the
  first `V(customers)`, served the three seated customers and then blocked
  again (sleeping).

The trace is deterministic for this configuration because the five customers
have five different priorities.

## 13. Testing scenarios and results

### 13.1 How the tests are executed

`tests/host_sim/` compiles the **unmodified** `main.c` (`-Dmain=app_main`)
against a small RT-Thread API simulator that reproduces RT-Thread's priority
preemptive scheduling, counting semaphores, mutexes and simulated ticks. Nine
shop configurations are built and executed, and every trace is verified against
the sleeping-barber invariants.

### 13.2 Results (real run)

```text
Scenario                  Customers Chairs Seated TurnedAway Haircuts Switches SimMs Result
S1_zero_customers                 0      3      0          0        0        2     0 PASS
S2_one_customer                   1      3      1          0        1        9    90 PASS
S3_one_customer_one_chair         1      1      1          0        1        9    90 PASS
S4_three_customers                3      3      3          0        3       21   170 PASS
S5_five_three_chairs              5      3      3          2        3       27   170 PASS
S6_five_five_chairs               5      5      5          0        5       33   250 PASS
S7_twenty_one_chair              20      1      2         18        2       53   130 PASS
S8_twenty_ten_chairs             20     10     11          9       11       75   490 PASS
S9_twenty_twenty_chairs          20     20     20          0       20       93   850 PASS
S5_repeated_10_times              5      3      3          2        3       27   170 PASS
```

| Required scenario | Scenario | Observable result |
|---|---|---|
| Zero customers | S1 | only the startup lines; the barber stays blocked on `cust_sem`, 0 haircuts |
| One customer | S2, S3 | one chair taken, one haircut, no departure |
| Several customers, sequentially | S2 → S9 | customers are served in priority (= arrival) order |
| Several customers, concurrently | S5, S6, S8, S9 | arrivals at the same tick, mutex serialises them |
| Waiting room completely full | S5, S7, S8 | `freeseats=0` then `customers N leave.` |
| Customer arrives while the barber sleeps | S2 | the first `V(customers)` wakes the barber |
| Long-running, repeated arrivals | S7, S8, S9 | 20 customers, up to 20 haircuts, no leak, no deadlock |
| Repeated execution | S5 × 10 | ten runs produced byte-identical traces |

### 13.3 Invariants checked for every scenario

1. The simulator finishes with **exactly one** blocked thread — the sleeping
   barber on `cust_sem`. Any other blocked thread would be a deadlock.
2. No livelock: the switch budget (200 000 context switches) is never reached.
3. `seated customers == "barber finish cut hair." count == "barber find customer" count`.
4. `seated + turned away == customer_num` — no customer is lost or double
   counted.
5. Every customer number appears at most once (nobody is both seated and
   turned away).
6. `freeseats` is printed only in the range `[0, N-1]`, i.e. the waiting room is
   never over-filled and never negative.
7. If `chairs >= customers`, nobody is turned away.
8. Ten consecutive runs of the same binary produce identical traces
   (deterministic, no race).

All nine scenarios and the repeatability run **passed**. Full logs are written
to `tests/host_sim/out/*.log`.

## 14. Corrections applied to the printed listing

Code Listing 11-59 is followed as closely as possible; the message strings,
priorities, delays, stack size, timeslice and the PV structure are unchanged.
Six points had to be adapted because the printed listing cannot build or is
unsafe in C:

| # | In the listing | In `main.c` | Why |
|---|---|---|---|
| 1 | `static void customer_thread(int num)` | `static void customer_thread(void *arg)` | `rt_thread_create()` takes `void (*)(void *)`. An `int` parameter cannot be a thread entry. |
| 2 | `rt_thread_create(..., num[i], ...)` | `(void *)&num[i]` | `int` cannot be passed where `void *` is expected; the address of the customer number is passed and dereferenced. |
| 3 | `static rt_err_t res;` / `static rt_uint8_t number;` inside thread functions | plain local variables | `static` locals are shared by all five customer threads; a real (non-static) local keeps each thread's copy private. The barber's counter is still incremented exactly like the listing. |
| 4 | `int num[customer_num]={0,1,2,3,4};` | initialised by a loop `num[i]=i` | identical values for the default five customers, and still correct when the tests build a bigger shop. |
| 5 | no check of the `rt_*_create()` results | one combined `RT_NULL` check that closes the shop | avoids a `RT_ASSERT` panic inside the kernel when the heap is exhausted. |
| 6 | `#define customer_num 5` / `freeseats = 3` | same defaults, wrapped in `#ifndef` | lets the host test harness build other shop sizes without editing `main.c`. The Loongson build always uses 5 and 3. |

`THREAD_STACK_SIZE 1024*20` from the listing is kept **unchanged**: with
`RT_USING_OVERFLOW_CHECK` enabled and `rt_kprintf()` using the newlib
`vsnprintf()`, a 1 KB stack overflows and trips the kernel assertion.

## 15. Conclusion

The project implements Chapter 7 of the guide on the Loongson 1B board with
RT-Thread: one barber thread, five customer threads with different priorities,
a waiting room with three chairs, and the two counting semaphores plus one
mutex that the chapter prescribes. The PV algorithm of Code Listing 11-58 is
reproduced exactly; the design code of Code Listing 11-59 is in
[`main.c`](main.c) and builds to a valid MIPS32 little-endian image
(`Build/RThread6.exe`, `Build/RThread6.bin`).

The synchronization was verified by executing the same `main.c` on a host
RT-Thread simulator in nine shop configurations plus a ten-run repeatability
check. Every scenario passed: mutual exclusion holds, the waiting room is never
over-filled, every seated customer is served, the barber sleeps and wakes
correctly, and no thread is left blocked except the sleeping barber.

The technical report with the full analysis is in
[`docs/report.md`](docs/report.md); the diagrams are in
[`docs/diagrams/diagrams.md`](docs/diagrams/diagrams.md).
