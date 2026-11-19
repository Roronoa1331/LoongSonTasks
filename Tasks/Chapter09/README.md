# Chapter 9 — Porting Linux and Writing C Language Programs

Section 9 of the *Computer System Comprehensive Design Experiment Guide*.
Folder name: `Chapter09`.

The chapter walks through the tooling needed to build and download code for the
Loongson 1B from a PC: Tftpd32 for TFTP transfer, VMware + Ubuntu, a shared
folder, and the MIPS cross-compiler. The project kept here is the worked
example built with that setup.

## What is in the folder

| File / directory | Description |
|---|---|
| [`main.c`](main.c) | Entry point: initialises lwIP over GMAC0, then starts the demo selected by the `TEST_*` macros |
| [`lwip_test.h`](lwip_test.h) | IP addresses, ports, buffer sizes and the four `TEST_*` switches (`TEST_TCP_CLIENT` is the one enabled here) |
| [`lwip_test.c`](lwip_test.c) | Local and remote IP string definitions |
| [`tcp_server.c`](tcp_server.c), [`tcp_client.c`](tcp_client.c) | TCP demo code |
| [`udp_server.c`](udp_server.c), [`udp_client.c`](udp_client.c) | UDP demo code |
| [`src/install_3th_libraries.c`](src/install_3th_libraries.c) | Start-up hook that installs the optional third-party libraries (YAFFS2, lwIP, FTP) when their `USE_*` macros are enabled |
| [`include/`](include/) | `bsp.h`, `rtconfig.h`, OS priority and queue headers |
| [`RTT4/`](RTT4/), [`ls1x-drv/`](ls1x-drv/), [`lwIP-1.4.1/`](lwIP-1.4.1/) | RT-Thread 4.0.2 kernel, Loongson 1B drivers, lwIP stack and port |
| [`ld.script`](ld.script) | Memory layout — 64 MB RAM at `0x80000000`, code at `0x80200000` |
| [`example_9_1.lxp`](example_9_1.lxp) | LoongIDE project file |

## Build and run

1. Open `example_9_1.lxp` in LoongIDE.
2. **Project → Compile & Build**. The build writes `Build/example_9_1.exe`
   (the ELF downloaded to the board) and `example_9_1.bin` (raw image).
3. Set exactly one `TEST_*` macro to `1` in `lwip_test.h` if you want a
   different demo, then rebuild.
4. **Debug → Run** downloads the image over EJTAG.
5. Watch UART5 at 115200 baud, 8-N-1. With `TEST_TCP_CLIENT` enabled the board
   connects to a TCP server on the PC at the address configured in
   `lwip_test.h`.

The toolchain used by the generated makefile is the LoongIDE MIPS SDE install
(`mips-sde-elf-gcc`). Update the tool paths if yours lives elsewhere.
