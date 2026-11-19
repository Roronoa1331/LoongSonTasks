# Chapter 6 — Design of the Serial-Port Controlled Running LED Experiment

Section 6 of the *Computer System Comprehensive Design Experiment Guide*.
Folder name: `Chapter06_SerialPortRunningLED`.

The application reads one command per line from **UART3** and drives eight
active-low LEDs through the Loongson 1B (LS1B/LS1B200) GPIO controller. The
whole experiment lives in [`main.c`](main.c).

## Commands

Every command is case-insensitive, surrounding blanks are ignored, and `\r`,
`\n` or `\r\n` all terminate a line. Backspace (`0x08` / `0x7F`) edits the
current line.

| Command | Behaviour | Reply |
|---|---|---|
| `ON 1` … `ON 8` | Turn the selected LED on and the other seven off; stops the running LED | `OK` |
| `OFF` | Turn every LED off; stops the running LED | `OK` |
| `SPEED 100` … `SPEED 1000` | Set the running-LED step interval in milliseconds | `OK` |
| `START` | Start the running LED from its current position | `OK` |
| `STOP` | Stop the running LED where it is | `OK` |
| anything else, or a line over 31 characters | — | `ERR` |

After reset the firmware turns all LEDs off, parks the running LED on position 1
with a 500 ms step interval, and prints `READY`.

## Hardware mapping

| LED | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| GPIO | 9 | 11 | 15 | 17 | 20 | 22 | 6 | 7 |

All eight pins are in GPIO bank 0. The LEDs are active-low, so a pin driven to
`0` lights the LED. UART3 runs at 115200 baud, 8 data bits, no parity, one stop
bit — the guide notes that *"our serial port is connected to UART3"*.

## Files

| File | Description |
|---|---|
| [`main.c`](main.c) | UART3 polling, command parser, GPIO/LED driving, timing |
| [`include/`](include/) | Board and kernel configuration |
| [`RTT4/`](RTT4/) | RT-Thread 4.0.2 kernel, MIPS32 port and components |
| [`ls1x-drv/`](ls1x-drv/) | Loongson LS1B drivers (UART, GPIO, …) |
| [`src/`](src/) | Third-party library installation hook |
| [`ld.script`](ld.script) | Memory layout — 64 MB RAM at `0x80000000`, code at `0x80200000`, entry `start` |
| [`TaskTwoAgain.lxp`](TaskTwoAgain.lxp) | LoongIDE project file (project name kept from the original build) |
| [`Build/`](Build/) | Generated makefiles, objects and `TaskTwoAgain.exe` / `.bin` |

## Build

The generated makefiles use the LoongIDE MIPS toolchain at
`E:\LoongIDE\mips-2011.03\bin\`:

```text
cd Build
make -f Makefile.mk all
```

This produces `Build/TaskTwoAgain.exe` and `Build/TaskTwoAgain.bin`. Or open
[`TaskTwoAgain.lxp`](TaskTwoAgain.lxp) in LoongIDE and use
`Project → Compile & Build`.

## Run

The image is a MIPS32 little-endian target binary, not a Windows program.
Download it to an LS1B board with LoongIDE (`Debug → Run`), then open a serial
terminal on the UART3 port at 115200 8-N-1 and type the commands above.
