# Bare-metal calculator board image

This is the direct Chapter 5-style version of the calculator. It uses the
Chapter 5 MIPS startup and linker layout, a polled NS16550 UART5 driver, and
newlib `_read`/`_write` retargeting. It does not use RT-Thread, FinSH, or an
`msh>` command.

## LoongIDE project

Open **`calculator_baremetal.lxp`** in LoongIDE. This is the project file for
this folder; without it LoongIDE has nothing to open here.

1. **Project → Open Project** and select `calculator_baremetal.lxp`
   (or double-click the file).
2. **Project → Compile & Build** (`Ctrl+F9`).
3. **Debug → Run** (`F9`) to download and start the image on the board.

The project builds the nine source units in this folder:

| Source | Role |
|---|---|
| `core/start.S` | startup entry (`start`), stack, `.bss`, cache, vectors |
| `core/cache.S`, `core/irq_s.S`, `core/ls1b_*_handler.S` | Chapter 5 support code |
| `bsp_start.c` | initialises UART5 and calls `calculator_main()` |
| `uart5.c` | polled NS16550 UART5 at 115200 8-N-1 |
| `include/uart5.h` | UART5 driver interface (in the project's include folder) |
| `syscalls.c` | newlib `_read`/`_write`/`_sbrk` retargeting |
| `src/calculator.c` | the portable calculator core |
| `ld.script` | image at `0x80200000`, 64 MB RAM, 16 KB stack |

`core/` is copied from `..\..\Chapter05_AssemblyCodeImplementation\core`, and
`src/calculator.c` is a copy of `..\board_rtthread\src\calculator.c`. Keep the
calculator copy in sync if the shared core changes.

## Command-line build

```powershell
cd C:\Users\testriad\Desktop\LoongSonExamples\DigitalCalculator\board_baremetal
& 'C:\msys\1.0\bin\make.exe' -f Makefile clean all
```

The build produces:

* `Build\calculator_baremetal.exe` — ELF32, little-endian MIPS, entry
  `0x80200000` (the file LoongIDE downloads);
* `Build\calculator_baremetal.bin` — raw ISP/XMODEM image linked at
  `0x80200000`.

Both the command-line makefile and the LoongIDE project use the MIPS SDE Lite
toolchain at `E:\LoongIDE\mips-2015.05\bin` and the same compiler definitions
(`LS1B`, `CALCULATOR_BAREMETAL`).

## Running on the board

The calculator starts immediately after the loader jumps to `0x80200000`;
there is no `calculator` shell command and no `msh>` prompt. Connect the
terminal to the board connector wired to **UART5** at **115200 baud, 8-N-1**.
The first screen is the calculator menu.

Downloading can be done either way:

* LoongIDE **Debug → Run** through the board's USB-Link/EJTAG probe; or
* the board's ISP/PMON loader (XMODEM) of `Build\calculator_baremetal.bin` to
  `0x80200000`, then start it.

The PMON download connection and the UART5 console are separate ports.

## Verification status

* 2026-11-19: `calculator_baremetal.lxp` opens in LoongIDE and **Compile &
  Build** completes with the IDE's own generated makefiles; the linked image is
  ELF32 MIPS little-endian with entry point `0x80200000`.
* 2026-11-19: With the LxLink probe connected (FTDI `EJTAG Probe V1.3`,
  serial `LXLINK-0103`), LoongIDE **Debug → Run** completes, starts gdb and
  starts the image on the board; no `No LxLink found` error.
* 2026-11-19: **UART5 output verified on COM8 at 115200** — the board prints
  the welcome banner and the calculator menu. This required fixing the baud
  divisor: it was hard-coded to 54 (100 MHz bus), but this board's bus clock
  is `DDR / 2` = 50 MHz, so the divisor is now computed from the live PLL
  registers (27 on the 200 MHz CPU / 100 MHz DDR setting).
* The interactive arithmetic test is still pending: the LxLink probe dropped
  off USB during that test. Reseat the probe, run again, and type `1`, `2.5`,
  `1.5` on the UART5 terminal to see `Result: 4`.
