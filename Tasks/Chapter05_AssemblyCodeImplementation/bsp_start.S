/*
 * Task 1 - Assembly Code Implementation
 * (guide section 5: the sum of consecutive odd numbers)
 *
 *   1 + 3 + 5 + ... + (2n - 1) = n^2
 *
 * The addition uses 32-bit unsigned arithmetic.  Before every addition the
 * remaining space of the accumulator is checked so that the result can never
 * overflow 0xFFFFFFFF; the loop stops just before the first overflowing term.
 *
 * Results are stored in main memory:
 *
 *   0x80030000  accumulated sum   (0xFFFE0001)
 *   0x80030004  number of terms   (0x0000FFFF)
 *   0x80030008  overflow flag     (0x00000001)
 *
 * Register usage:
 *   t0  accumulated sum
 *   t1  current odd number to be added
 *   t2  number of odd numbers actually added
 *   t3  0xFFFFFFFF, the largest 32-bit unsigned value
 *   t4  overflow flag
 *   t5  remaining space (t3 - t1)
 *   t6  t5 < t0 -> adding t1 would overflow
 *   t7  address used for the store instructions
 */

#include "regdef.h"

    .text
    .globl  bsp_start

    .set    noreorder
    .set    noat

/*
 * int bsp_start(void)
 */
    .ent    bsp_start
bsp_start:
    move    t0, zero                /* sum   = 0            */
    li      t1, 1                   /* addend = 1           */
    move    t2, zero                /* count  = 0           */
    li      t3, -1                  /* t3 = 0xFFFFFFFF      */
    move    t4, zero                /* flag   = 0           */

cal_loop:
    subu    t5, t3, t1              /* space left after adding t1 */
    sltu    t6, t5, t0              /* would sum + t1 overflow?   */
    bnez    t6, save_result
    nop

    addu    t0, t0, t1              /* sum   += addend      */
    addiu   t1, t1, 2               /* addend = next odd    */
    addiu   t2, t2, 1               /* count++              */
    b       cal_loop
    nop

save_result:
    li      t4, 1                   /* flag = 1: stopped before overflow */

    lui     t7, 0x8003
    sw      t0, 0(t7)               /* 0x80030000 = sum     */

    lui     t7, 0x8003
    ori     t7, t7, 0x0004
    sw      t2, 0(t7)               /* 0x80030004 = count   */

    lui     t7, 0x8003
    ori     t7, t7, 0x0008
    sw      t4, 0(t7)               /* 0x80030008 = flag    */

    move    v0, zero
    jr      ra
    nop
    .end    bsp_start

    .set    reorder

/*
 * @@ End
 */
