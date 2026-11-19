/*
 * sim.ld - linker script for the MIPS SDE simulator
 *
 * Address 0xA0000000 is the uncached KSEG1 window that the MIPS SDE
 * simulator uses for its 1 MB of simulated program RAM (this is the only
 * RAM area the "mips-sde-elf-run" program provides by default).  The
 * layout below is a plain single-region layout: code, read-only data,
 * initialised data, GP small data, then .bss, with the stack at the top.
 *
 * This script is used only by "make mips" (simulator run).  A real
 * Loongson LS1B200 image is produced by LoongIDE and uses the board's own
 * linker script instead.
 */

ENTRY(_start)

MEMORY
{
    ram : ORIGIN = 0xA0000000, LENGTH = 1M
}

SECTIONS
{
    . = ORIGIN(ram);

    .text   : { *(.text)   *(.text.*)   } > ram
    .rodata : { *(.rodata) *(.rodata.*) } > ram
    .data   : { *(.data)   *(.data.*)   } > ram

    /* $gp must sit within +/-32 KB of every small-data symbol */
    .sdata  : { _gp = . + 0x7ff0; *(.sdata) *(.sdata.*) } > ram
    .sbss   : { *(.sbss) *(.sbss.*) } > ram

    .bss    :
    {
        __bss_start = .;
        *(.bss) *(.bss.*) *(COMMON)
        . = ALIGN(4);
        _end = .;
    } > ram

    __cs3_heap_start = _end;
    __cs3_heap_limit = _end + 0x4000;
    _stack_top       = ORIGIN(ram) + LENGTH(ram) - 16;
}
