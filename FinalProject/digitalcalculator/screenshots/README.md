# Screenshots / visual evidence

## What is in this folder

| File | Shows |
|---|---|
| `01_main_menu.txt` | Main calculator menu on start-up |
| `02_addition.txt` | `10 + 5` → `15` |
| `03_subtraction.txt` | `10 - 5` → `5` |
| `04_multiplication.txt` | `10 * 5` → `50` |
| `05_division.txt` | `10 / 5` → `2` |
| `06_division_by_zero.txt` | `10 / 0` → error message, program keeps running |
| `07_invalid_menu_option.txt` | Menu option `9` → invalid selection message |
| `08_invalid_numeric_input.txt` | Operand `abc` → invalid numeric input message |
| `09_decimal_calculation.txt` | `2.5 + 1.5` → `4` |
| `10_exit.txt` | Menu option `5` → `Goodbye.` and back to the prompt |
| `capture_log.txt` | Date, host and program behind the captures |
| `capture_session.ps1` | The script that produced the `.txt` captures |

## How these captures were made

They are **not** hand-written transcripts. `capture_session.ps1`:

1. starts the real `build\calculator.exe` inside a real Windows console (`conhost`);
2. injects real keyboard events into that console with `WriteConsoleInput()`, so
   Windows echoes the typed characters exactly as it does for a human
   (`Enter your choice: 1`, `Enter first number : 10`, …);
3. reads the console screen buffer back with `ReadConsoleOutputCharacter()`
   and stores exactly what the console displayed.

So every character in the files above is text the console really rendered.

## Why `.txt` instead of `.png`

The machine that built this project had **no interactive desktop session**
available: a direct screen grab (`Graphics.CopyFromScreen`) returned an
all-black image, and the console window itself was not created
(`MainWindowHandle = 0`). No photograph of the screen could be taken, and
inventing one would be dishonest, so the console content was recorded as text.

## How to produce the real `.png` screenshots (about 2 minutes each)

1. Open a terminal in the project folder and build:
   ```
   cd C:\Users\testriad\Desktop\LoongSonExamples\DigitalCalculator
   make
   ```
2. Run the calculator from the terminal:
   ```
   .\build\calculator.exe
   ```
3. Type the input shown in the matching `.txt` file, for example for
   `02_addition.txt`:
   ```
   1
   10
   5
   ```
4. Take the screenshot of the terminal window:
   * press `Alt` + `Print Screen` (captures only the active window), or
   * use the Snipping Tool (`Win` + `Shift` + `S`).
5. Save it in this folder with the same number, for example
   `02_addition.png`, then repeat for the other scenarios.

`docs/FINAL_REPORT.md` refers to the `.txt` captures directly and explains
where to place the `.png` files once they are produced.

> Note: the mouse/keyboard sequence above was executed on a **simulated
> desktop-less session**, so the recorded text is genuine program output, but
> the *appearance* of the window (fonts, colours, window frame) can only be
> shown by a real screen capture on your own machine.
