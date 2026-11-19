# Host simulation tests

The Loongson 1B board is not needed to verify the synchronization of Chapter 7:
this folder executes the project's **real** `main.c` on the PC and checks the
sleeping-barber invariants.

## How it works

| File | Purpose |
|---|---|
| [`rtthread.h`](rtthread.h) | Drop-in replacement for RT-Thread's header — declares only the API subset `main.c` uses. |
| [`bsp.h`](bsp.h) | Drop-in replacement for the BSP header (`ls1x_drv_init()`, `rt_ls1x_drv_init()`, `install_3th_libraries()`, `delay_ms()`). |
| [`rtthread_sim.c`](rtthread_sim.c) | The RT-Thread services: counting semaphores, mutexes, threads and `rt_kprintf()`, on top of Win32 threads with RT-Thread's scheduling rules. |
| [`sim_control.h`](sim_control.h) | Control interface used only by the harness. |
| [`main_host.c`](main_host.c) | Harness: starts `main.c`, runs the simulation and reports the final thread states. |
| [`run_scenarios.ps1`](run_scenarios.ps1) | Builds and runs all scenarios and checks the traces. |
| `out/` | Generated objects, executables and `.log` traces (created on demand). |

`../../main.c` is compiled with `-Dmain=app_main` so that the harness keeps its
own `main()`. Nothing inside `main.c` is changed for the tests.

### Scheduling model

The simulator reproduces the RT-Thread behaviour that the algorithm depends on:

* priorities `0..31`, lower number = higher priority; 32 levels as in
  `rtconfig.h`;
* the highest priority READY thread runs; a thread that releases a semaphore or
  a mutex, or starts a thread, is preempted immediately if this makes a higher
  priority thread ready;
* `rt_thread_mdelay(ms)` blocks the thread for `ms` simulated milliseconds;
* simulated time advances only when no thread is runnable (single emulated
  core);
* semaphore and mutex wait lists are ordered by priority, then FIFO.

A single controller loop makes all scheduling decisions, so the traces are
deterministic.

## Build and run

```text
cd tests\host_sim
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_scenarios.ps1
```

Requirements: a C compiler on `PATH` (`gcc` — MinGW is used here) and
PowerShell 5.1 or newer.

Expected tail of the run:

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

10 of 10 scenarios passed.
```

The script exits with code `0` when everything passed and `1` otherwise.

## Building one scenario by hand

```text
gcc -Wall -I. -Dcustomer_num=5 -DWAITING_CHAIRS=3 -Dmain=app_main -c ..\..\main.c -o app.o
gcc -Wall -I. -c rtthread_sim.c main_host.c
gcc rtthread_sim.o main_host.o app.o -o sim.exe
sim.exe
```

Valid overrides: `customer_num` (number of customer threads) and
`WAITING_CHAIRS` (N, number of chairs).

## Invariants checked

For every scenario `run_scenarios.ps1` verifies:

1. the simulator terminates with exactly **one** blocked thread — the sleeping
   barber on `cust_sem` (any other blocked thread would be a deadlock);
2. no livelock (context-switch budget of 200 000 is never reached);
3. `seated == "barber finish cut hair." count == "barber find customer" count`;
4. `seated + turned away == customer_num` (no lost or double counted customer);
5. no customer number appears twice;
6. every printed `freeseats` value lies in `[0, N-1]` (capacity never exceeded,
   never negative);
7. if `chairs >= customers`, nobody is turned away;
8. ten consecutive executions produce identical traces.

## Note on stack sizes

`main.c` uses the guide's `THREAD_STACK_SIZE (1024 * 20)`. The simulator treats
this as a lower bound and gives every emulated thread at least 256 KB, because
the PC C runtime (`printf`, newlib) uses far more stack than RT-Thread's own
`rt_kprintf()`. Stack sizing is therefore a target-only concern; the
synchronization behaviour is unaffected.
