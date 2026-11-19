/*
 * crt0.S - minimal startup code for the MIPS SDE simulator (mipssim board)
 *
 * The MIPS SDE Lite toolchain shipped with LoongIDE does not include a
 * ready-made startup file for this simulator, so this file provides the
 * three things a bare MIPS32 core needs before main() can run:
 *
 *   1. a stack pointer,
 *   2. the global pointer ($gp) used by the -G8 small-data sections,
 *   3. a cleared .bss section.
 *
 * It is only used for the MIPS32 simulator build ("make mips").  The
 * calculator source file itself is plain ANSI C and needs none of this.
 */

    .set    noreorder
    .text

    .globl  _start
    .ent    _start
_start:
    la      $sp, _stack_top         /* stack grows down from the top of RAM */
    la      $gp, _gp                /* small-data base for libc/libm        */

    la      $t0, __bss_start        /* clear .bss                          */
    la      $t1, _end
1:  beq     $t0, $t1, 2f
    nop
    sw      $zero, 0($t0)
    addiu   $t0, $t0, 4
    b       1b
    nop

2:  jal     main                  /* main() from calculator.c            */
    nop
    move    $a0, $v0
    jal     exit                  /* flush stdio and stop the simulator  */
    nop

3:  b       3b
    nop
    .end    _start

/* Referenced by newlib's crt support; empty stubs are enough here. */
    .globl  _init
    .ent    _init
_init:
    jr      $ra
    nop
    .end    _init

    .globl  _fini
    .ent    _fini
_fini:
    jr      $ra
    nop
    .end    _fini
