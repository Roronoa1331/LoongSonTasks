# Run the Digital Calculator on an LS1B200 board

This folder is a board-target RT-Thread project based on the repository's
existing Chapter 7 LS1B200 BSP. It uses the BSP's startup code, linker script,
RT-Thread kernel, FinSH/MSH shell, and UART5 console. It does **not** use the
simulator startup file in `..\target\crt0.S` or `..\target\sim.ld`.

## Build the board firmware

Prerequisites: LoongIDE/MIPS SDE Lite at `E:\LoongIDE\mips-2011.03` and GNU
make at `C:\msys\1.0\bin` (the paths used by the copied BSP makefiles).

From PowerShell:

```powershell
cd C:\Users\testriad\Desktop\LoongSonExamples\DigitalCalculator\board_rtthread
.\build.bat clean
.\build.bat
```

The build creates:

* `Build\RThread6.exe` — ELF32, little-endian MIPS firmware, linked at the
  LS1B200 BSP's `0x80200000` entry point;
* `Build\RThread6.bin` — raw binary image for the LoongIDE download workflow.

The project file `RThread6.lxp` also includes `src\calculator.c` and its
`CALCULATOR_RTTHREAD` compile definition. Open that project in LoongIDE and
use **Project → Compile & Build** if you prefer the IDE. Do not regenerate the
project's build files without preserving that source entry and definition.

## Download and use it on the board

1. Connect the board to power and connect the PC's USB-to-serial adapter to
   the board's **UART5** console connector. This BSP selects UART5.
2. In Windows Device Manager, find the COM port assigned to that adapter.
3. Open PuTTY (or another serial terminal) with:
   * Connection type: **Serial**
   * Serial line: the COM port found above (for example `COM5`)
   * Speed: **115200**
   * Data bits: **8**, parity: **None**, stop bits: **1**, flow control: **None**
4. Power on or reset the board.
5. In LoongIDE, open `RThread6.lxp` and choose **Debug → Run** to download and
   start the firmware. If your LoongIDE setup uses a separate debug target or
   probe selection, select the LS1B200 target configured for your board.
6. In the UART terminal, wait for the `msh>` prompt and type:

   ```text
   calculator
   ```

7. Use the calculator menu normally. Type `5` to exit back to `msh>`; type
   `calculator` again to start another session.

The calculator reads and echoes characters through the BSP's polled UART5
console while it is running as an MSH command. FinSH is retained, so its shell
and the calculator do not compete for UART input.

## ISP/PMON transfer alternative

If your board kit uses the PMON ISP/XMODEM loader instead of LoongIDE
**Debug -> Run**, use the raw image `Build\RThread6.bin`. The PMON transfer
connection and the calculator console are separate:

* ISP/PMON download: the board's monitor/download COM connection;
* calculator input/output: UART5 at 115200 baud, 8-N-1.

The repository already contains a PowerShell XMODEM loader in
`..\..\Chapter08_ImplementationofNetworkTransmission\tools`. From this
directory, replace `COM8` with the COM port used by the board's PMON
connection:

```powershell
cd C:\Users\testriad\Desktop\LoongSonExamples\DigitalCalculator\board_rtthread
.\build.bat
& ..\..\Chapter08_ImplementationofNetworkTransmission\tools\pmon_load.ps1 `
  -Port COM8 `
  -Image .\Build\RThread6.bin `
  -Base 0x80200000
```

Before running the command, reset the board and leave it at the `PMON>`
prompt. Wait for the loader to report that the image was loaded. Then use
LoongIDE **Debug -> Run** to start the firmware if PMON `g 0x80200000` does
not start RT-Thread on your board. Finally, open the UART5 terminal and wait
for `msh>`, then enter `calculator`.

## Verification status

The RT-Thread project was built successfully with the installed MIPS SDE Lite
compiler. Its ELF is MIPS ELF32 with entry point `0x80200000`. This environment
has no connected board, so firmware download, UART wiring, and physical
LS1B200 execution could not be verified here. The board's precise pinout,
debug probe, and LoongIDE download settings must match your hardware kit.

The project retains a few warnings from the supplied Chapter 7 RT-Thread/BSP
sources (FinSH, DFS header, UART driver); `src\calculator.c` compiled without
calculator-specific warnings.
