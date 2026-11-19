# Chapter 5 — Assembly Code Implementation

Section 5 of the *Computer System Comprehensive Design Experiment Guide*:
the sum of consecutive odd numbers, written in Loongson MIPS32 assembly.
Folder name: `Chapter05_AssemblyCodeImplementation`.

This project is a small bare-metal application for the Loongson LS1B/LS232 MIPS32 processor. It runs directly on the hardware or monitor without Linux, an RTOS, or a standard C runtime.

## What the program does

The application calculates the sum of consecutive odd numbers:

```text
1 + 3 + 5 + ... + (2n - 1) = n²
```

The calculation uses 32-bit unsigned arithmetic. Before each addition, the program checks whether the next value would overflow `0xFFFFFFFF`. It stops before the overflow occurs.

The final values are:

```text
sum  = 65535² = 0xFFFE0001
count = 65535
flag = 1
```

The results are written to these memory addresses:

| Address | Meaning |
|---|---|
| `0x80030000` | Calculated sum |
| `0x80030004` | Number of accumulated terms |
| `0x80030008` | Overflow-status flag |

A flag value of `1` means that the next odd number could not be added without overflowing a 32-bit unsigned integer.

## Startup and execution flow

1. The linker entry point is `start` in [`core/start.S`](core/start.S).
2. The startup code disables interrupts and clears the `.bss` section.
3. It initializes the stack and global pointer.
4. It detects and initializes the instruction and data caches.
5. It installs the MIPS exception and interrupt vectors.
6. It calls `bsp_start` in [`bsp_start.S`](bsp_start.S).
7. `bsp_start` performs the odd-number summation and writes the results to memory.
8. The startup code calls `_sys_exit`, which executes a MIPS `break` instruction and then stops.

## Project structure

| File or directory | Description |
|---|---|
| [`bsp_start.S`](bsp_start.S) | Main calculation and result storage |
| [`core/start.S`](core/start.S) | CPU startup, stack, `.bss`, cache, and exit setup |
| [`core/cache.S`](core/cache.S) | Cache-size detection and cache operations |
| [`core/irq_s.S`](core/irq_s.S) | Exception-vector installation and dispatch |
| [`core/stackframe.h`](core/stackframe.h) | Register save and restore macros |
| [`core/ls1b_interrupt_handler.S`](core/ls1b_interrupt_handler.S) | Interrupt-handler placeholder |
| [`core/ls1b_exception_handler.S`](core/ls1b_exception_handler.S) | Exception-handler placeholder |
| [`core/mips/cpu.h`](core/mips/cpu.h) | Loongson CPU, memory, cache, and vector definitions |
| [`ld.script`](ld.script) | MIPS linker script and memory layout |
| [`Build/`](Build/) | Generated object files, dependencies, executable, and binary |

## Memory layout

The linker script defines a 64 MB RAM region beginning at `0x80000000`.

```text
RAM origin: 0x80000000
Code start: 0x80200000
Stack size: 16 KB
Entry point: start
```

The stack is allocated at the end of the `.bss` section.

## Building

The generated build configuration uses the LoongIDE MIPS toolchain, including:

```text
mips-sde-elf-gcc
mips-sde-elf-objcopy
mips-sde-elf-size
```

From the `Build` directory, run:

```text
make -f Makefile.mk
```

The build produces:

```text
Build/example_7_2.exe
Build/example_7_2.bin
```

The current generated makefile expects the compiler tools at:

```text
E:/LoongIDE/mips-2015.05/bin/
```

If the toolchain is installed elsewhere, update the tool paths in the generated build configuration or regenerate the project using the LoongIDE project settings.

## Running and viewing the result

This is not a Windows application, so `example_7_2.exe` cannot be launched by double-clicking it. It must be downloaded to a Loongson LS1B/LS1B200 board or run in a compatible MIPS emulator.

### Using LoongIDE and an LS1B board

The project file is [`example_7_2.lxp`](example_7_2.lxp). Its saved debug configuration expects:

```text
Target: LS1B200
CPU: MIPS32, little-endian, soft-float
PMON IP: 192.168.1.2
PMON port: 9090
Debugger IP: 127.0.0.2
Debugger port: 50000
```

Adjust the IP addresses and ports if your board or debug server uses different settings.

1. Connect the LS1B board to the same network as the development computer.
2. Start the board's PMON monitor and the required LoongIDE debug server.
3. Open `example_7_2.lxp` in LoongIDE.
4. Build the project with **Build** or **Build All**.
5. Start the debugger. LoongIDE should download `Build/example_7_2.exe` to the target.
6. Run the program until it returns from `bsp_start`, or set a breakpoint near the end of [`bsp_start.S`](bsp_start.S).
7. Open LoongIDE's memory or debugger view and inspect the following addresses:

| Address | Expected value |
|---|---:|
| `0x80030000` | `0xFFFE0001` |
| `0x80030004` | `0x0000FFFF` |
| `0x80030008` | `0x00000001` |

The target is configured for little-endian access, so each value is stored least-significant byte first in raw memory.

### Without a board or emulator

You can still inspect the expected result from the source code, but the assembly cannot execute natively on Windows. The existing binary is a target MIPS binary, not a Windows `.exe`.

## Important notes

- The source is MIPS32 assembly and is intended for a Loongson-compatible environment.
- The program writes to fixed memory addresses, so it should be run only on a target or emulator with the expected memory map.
- The interrupt and exception handlers are framework placeholders; they do not yet implement device-specific handling.
- The `Build` directory contains generated files and normally does not need to be edited manually.
