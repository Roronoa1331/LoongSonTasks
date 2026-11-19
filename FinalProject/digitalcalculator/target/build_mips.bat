@echo off
REM ---------------------------------------------------------------------------
REM  build_mips.bat - cross-compile the Digital Calculator for MIPS32 and run
REM                  it in the MIPS SDE Lite instruction-set simulator.
REM
REM  Requires the LoongIDE MIPS toolchain (MIPS SDE Lite, mips-sde-elf-*).
REM  Adjust MIPS_BIN below if it lives somewhere else.
REM
REM  Usage:  target\build_mips.bat          (build + run the smoke test)
REM          target\build_mips.bat build    (build only)
REM ---------------------------------------------------------------------------

setlocal
set MIPS_BIN=E:\LoongIDE\mips-2011.03\bin
set PATH=%MIPS_BIN%;%PATH%

set PROJECT=%~dp0..
set OUT=%PROJECT%\build_mips
set CFLAGS=-mips32 -G0 -EL -msoft-float -O1 -Wall

if not exist "%OUT%" mkdir "%OUT%"

echo.
echo [1/4] Compiling startup code (crt0.S)
"%MIPS_BIN%\mips-sde-elf-gcc.exe" %CFLAGS% -c "%PROJECT%\target\crt0.S" -o "%OUT%\crt0.o"
if errorlevel 1 goto failed

echo [2/4] Compiling calculator.c for MIPS32
"%MIPS_BIN%\mips-sde-elf-gcc.exe" %CFLAGS% -c "%PROJECT%\src\calculator.c" -o "%OUT%\calculator.o"
if errorlevel 1 goto failed

echo [3/4] Linking simulator image
"%MIPS_BIN%\mips-sde-elf-gcc.exe" -mips32 -G0 -EL -msoft-float -nostartfiles ^
    -T "%PROJECT%\target\sim.ld" -Wl,--start-group -o "%OUT%\calculator.elf" ^
    "%OUT%\crt0.o" "%OUT%\calculator.o" -lcs3hosted -lc -lm -lgcc -Wl,--end-group
if errorlevel 1 goto failed

echo [4/4] Inspecting the generated image
"%MIPS_BIN%\mips-sde-elf-readelf.exe" -h "%OUT%\calculator.elf" | findstr /C:"Class" /C:"Data" /C:"Machine" /C:"Entry"
"%MIPS_BIN%\mips-sde-elf-size.exe" "%OUT%\calculator.elf"

REM Also compile in the board configuration used by the LoongIDE projects,
REM to show the source builds unchanged for the LS1B200 target settings.
"%MIPS_BIN%\mips-sde-elf-gcc.exe" -mips32 -G0 -EL -msoft-float -DLS1B -O0 -Wall ^
    -c "%PROJECT%\src\calculator.c" -o "%OUT%\calculator_ls1b.o"
if errorlevel 1 goto failed
echo Board-configuration object: build_mips\calculator_ls1b.o

echo.
echo BUILD OK: build_mips\calculator.elf
if /I "%1"=="build" exit /b 0

echo.
echo Running the MIPS32 image in the MIPS SDE simulator:
echo.
echo 1 ^| 10 ^| 5 ^| 4 ^| 10 ^| 0 ^| 5 ^| & "%MIPS_BIN%\mips-sde-elf-run.exe" "%OUT%\calculator.elf"
echo.
echo (Run "make mips-test" for the full automated suite on the simulator.)
exit /b 0

:failed
echo.
echo BUILD FAILED
exit /b 1
