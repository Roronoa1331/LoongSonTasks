@echo off
REM Open the LS1B200 UART5 console through the raw Win32 serial path.
REM Use this when PuTTY reports "Unable to configure serial port".
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0com_terminal.ps1" -Port COM9
pause
