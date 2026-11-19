# Digital Calculator (LS1B200 / MIPS32) — C final project

A menu-based digital calculator written in portable ANSI C, built and tested
with a native Windows compiler and cross-compiled (and simulated) for the
Loongson LS1B200 MIPS32 target.

```text
==============================
      DIGITAL CALCULATOR
==============================
  1. Addition
  2. Subtraction
  3. Multiplication
  4. Division
  5. Exit
------------------------------
Enter your choice:
```

## Features

* Addition, subtraction, multiplication and division on integers **and**
  decimals (`2.5 + 1.5 = 4`, `1 / 4 = 0.25`).
* Division by zero is detected and reported; the program never crashes.
* Non-numeric input (`abc`, `12abc`, an empty line, `inf`) is rejected with a
  clear message instead of misbehaving.
* Invalid menu options are rejected; the menu is shown again after every
  calculation, so one run can perform any number of calculations.
* End of input (`Ctrl+Z`, closed pipe) terminates the program cleanly.
* Standard C library for the portable calculator core; the board port uses
  the existing RT-Thread/UART BSP. No external sensors or extra electronics.

## Requirements

| Purpose | Tool |
|---|---|
| Native build + tests | `gcc` (MinGW) and GNU `make` |
| Automated tests | Windows PowerShell 5.1 or later |
| MIPS32 build | MIPS SDE Lite `mips-sde-elf-gcc` (shipped with LoongIDE) |

## Quick start

```bat
cd C:\Users\testriad\Desktop\LoongSonExamples\DigitalCalculator
make            :: build build\calculator.exe
make test       :: build + run the 20 automated tests
make run        :: start the calculator
```

Without `make`:

```bat
gcc -std=c99 -Wall -Wextra -pedantic -O2 -o build\calculator.exe src\calculator.c
build\calculator.exe
```

## MIPS32 target

```bat
make mips        :: cross-compile -> build_mips\calculator.elf (ELF32, MIPS, LE)
make mips-test   :: run the same 20 tests on the MIPS32 image in the SDE simulator
```

or, without `make`:

```bat
target\build_mips.bat
```

## Run on a physical LS1B200 board (RT-Thread)

The simulator ELF above is **not** the board firmware. For the easiest board
route, a separate RT-Thread port is included:

```powershell
cd C:\Users\testriad\Desktop\LoongSonExamples\DigitalCalculator\board_rtthread
.\build.bat clean
.\build.bat
```

In LoongIDE open `board_rtthread\RThread6.lxp`, then use **Debug → Run** to
download and start it. Connect a serial terminal to **UART5, 115200 baud, 8-N-1**.
At the `msh>` prompt type `calculator`; type `5` to return to the shell. The
complete wiring, build, and download instructions are in
[board_rtthread/README.md](board_rtthread/README.md). Physical execution has not
been tested here because no LS1B200 board was connected.

## Direct bare-metal board image

For a Chapter 5-style image without RT-Thread, FinSH, or an `msh>` command,
open [board_baremetal/calculator_baremetal.lxp](board_baremetal/calculator_baremetal.lxp)
in LoongIDE and use **Project → Compile & Build**, then **Debug → Run**. The
image is linked at `0x80200000` and starts the calculator immediately after the
loader starts it. Its console is a polled **UART5** at 115200 baud, 8-N-1; use
the existing board/ISP serial console.

Command-line build:

```powershell
cd C:\Users\testriad\Desktop\LoongSonExamples\DigitalCalculator\board_baremetal
& 'C:\msys\1.0\bin\make.exe' -f Makefile clean all
```

This produces `Build\calculator_baremetal.exe` (the LoongIDE ELF) and
`Build\calculator_baremetal.bin` (the raw ISP/PMON image). The bare-metal
image still needs an ISP/PMON loader or LoongIDE's EJTAG download to place it
in RAM; PMON is only the loader and is not part of the running calculator.

## Project layout

```
DigitalCalculator/
├── src/calculator.c            Main implementation (single file, ~470 lines)
├── tests/
│   ├── run_tests.ps1           Automated test runner (20 cases)
│   ├── cases/                  Generated input scripts (*.in)
│   ├── results/                Native run: per-test output + test_results.txt
│   └── results-mips/           MIPS32 run: same tests on the simulator
├── screenshots/                Console evidence (.txt) + capture script
├── target/
│   ├── crt0.S                  Minimal MIPS32 startup code (simulator only)
│   ├── sim.ld                  Linker script for the SDE simulator
│   └── build_mips.bat          One-command MIPS32 build
├── board_rtthread/              Board image based on the existing LS1B200 RT-Thread BSP
├── docs/FINAL_REPORT.md        Full university project report
├── Makefile
└── README.md
```

## Results

* Native build (gcc 4.6.1): **20 / 20 tests PASS**
* MIPS32 build (mips-sde-elf-gcc 4.5.2, SDE simulator): **20 / 20 tests PASS**,
  output byte-identical to the native build
* Board RT-Thread firmware build: **successful**; physical LS1B200 execution
  not tested (no board connected)

See [docs/FINAL_REPORT.md](docs/FINAL_REPORT.md) for the full report.
