# Loongson 1B — Computer System Comprehensive Design

Lab tasks and the final project for the *Computer System Comprehensive Design*
course, built for the **Loongson 1B (LS1B200)**, a MIPS32 little-endian SoC.
The tasks follow chapters 5–9 of the course guide; the final project is a
digital calculator in C.

All targets are cross-compiled with `mips-sde-elf-gcc` (LoongIDE toolchain),
loaded onto the board through LoongIDE/EJTAG or PMON, and observed over a
115200 baud serial console. The firmware sources, RT-Thread 4.0.2 kernel,
lwIP 1.4.1 and the `ls1x` board drivers are included; generated build output
(`Build/`, `_obj/`, `*.exe`, `*.bin`) is not.

## Repository layout

```
.
├── Tasks/
│   ├── Chapter05_AssemblyCodeImplementation/
│   ├── Chapter06_SerialPortRunningLED/
│   ├── Chapter07_SleepingBarber/
│   ├── Chapter08_ImplementationofNetworkTransmission/
│   └── Chapter09/
└── FinalProject/
    └── digitalcalculator/
```

## Tasks (chapters 05–09)

| Chapter | Topic | What it does |
|---|---|---|
| [05](Tasks/Chapter05_AssemblyCodeImplementation/README.md) | Assembly code implementation | Bare-metal MIPS32 assembly that sums consecutive odd numbers (`1+3+…+(2n−1) = n²`) with an overflow check; results land at `0x80030000`/`…04`/`…08` (`0xFFFE0001`, `65535`, flag `1`). |
| [06](Tasks/Chapter06_SerialPortRunningLED/README.md) | Serial-port controlled running LED | UART3 command console (`ON n`, `OFF`, `SPEED ms`, `START`, `STOP`) driving eight active-low LEDs on GPIO bank 0 with a timed running-LED pattern. |
| [07](Tasks/Chapter07_SleepingBarber/README.md) | OS application 1 — sleeping barber | RT-Thread implementation: 1 barber thread + 5 customer threads, 3 waiting chairs, synchronised with `customers`/`barber` semaphores, a `seatmutex` and a `freeseats` variable. |
| [08](Tasks/Chapter08_ImplementationofNetworkTransmission/README.md) | Network transmission | lwIP 1.4.1 over GMAC0 with four switchable demos — TCP server, TCP client, UDP server (echo), UDP client — plus reproducible per-configuration builds and captured evidence. |
| [09](Tasks/Chapter09/README.md) | Porting Linux and writing C programs | `example_9_1`: the LoongIDE project that builds an RT-Thread + lwIP TCP client, used with the chapter's Linux/TFTP/cross-compiler workflow. |

Each task folder has its own README with wiring, memory map, build steps and
expected serial output.

## Final project — digital calculator

[`FinalProject/digitalcalculator`](FinalProject/digitalcalculator/README.md) is
a menu-driven calculator in portable ANSI C: add, subtract, multiply and divide
on integers **and** decimals, with division-by-zero and invalid-input handling
and a loop that returns to the menu after every calculation.

```text
==============================
      DIGITAL CALCULATOR
==============================
  1. Addition
  2. Subtraction
  3. Multiplication
  4. Division
  5. Exit
```

Three ways to run it:

| Route | Command / project | Result |
|---|---|---|
| Native (Windows) | `make` then `make run`, or `gcc -std=c99 -o build\calculator.exe src\calculator.c` | `build\calculator.exe` |
| MIPS32 simulator | `make mips`, `make mips-test` | `build_mips\calculator.elf` in the SDE simulator |
| LS1B200 board | `board_rtthread\` (RT-Thread + `msh>` command) or `board_baremetal\` (polled UART5 image, LoongIDE `.lxp`) | Firmware downloaded over EJTAG |

Testing: 20 automated cases in `tests\run_tests.ps1`, all passing on the native
build and on the MIPS32 simulator with byte-identical output. On the board,
connect a serial terminal to UART5 at 115200 8-N-1 and type `calculator`.

## Building

Everything expects the LoongIDE MIPS toolchain
(`mips-sde-elf-gcc`, e.g. `E:\LoongIDE\mips-2015.05\bin`) and GNU make from MSYS
(`C:\msys\1.0\bin`). Per-task commands are in the linked READMEs.

## Notes

- These are target images (MIPS ELF), not Windows executables — running them on
  a PC means the MIPS simulator, not double-clicking the file.
- Several chapter folders keep the original LoongIDE project files (`.lxp`) and
  their saved debug targets, so the board IP addresses in them may need
  adjusting to your lab network.
- Hardware-dependent results (LEDs, serial, network) were verified on the
  LS1B200 board or its simulator as described in each task README.
