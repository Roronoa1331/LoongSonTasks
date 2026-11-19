@echo off
REM ---------------------------------------------------------------------------
REM  RThread6 - Chapter 7, The Sleeping-Barber Problem
REM  Command line build of the Loongson 1B image.
REM
REM  From PowerShell run it as:   .\build.bat
REM  (PowerShell does not execute programs from the current folder by name.)
REM
REM  Requires the LoongIDE MIPS toolchain (mips-sde-elf-*) and GNU make.
REM  The generated makefiles use E:\LoongIDE\mips-2011.03\bin - change
REM  Build\subdir.mk and Build\Makefile.mk if the toolchain lives elsewhere.
REM ---------------------------------------------------------------------------

setlocal
set PATH=c:\msys\1.0\bin;E:\LoongIDE\mips-2011.03\bin;%PATH%

cd /d "%~dp0Build"

if /I "%1"=="clean" goto cleanonly

make -f Makefile.mk all
if errorlevel 1 goto failed

echo.
echo Build finished: Build\RThread6.exe  (download this with LoongIDE)
echo                 Build\RThread6.bin  (raw binary image)
exit /b 0

:cleanonly
make -f Makefile.mk clean
echo Clean finished.
exit /b 0

:failed
echo.
echo BUILD FAILED
exit /b 1
