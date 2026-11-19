#include "uart5.h"
#include "ls1b.h"

#define UART5_BASE 0xBFE7C000u

#define UART_RBR 0
#define UART_THR 0
#define UART_IER 1
#define UART_FCR 2
#define UART_LCR 3
#define UART_MCR 4
#define UART_LSR 5
#define UART_MSR 6

#define LCR_DLAB 0x80
#define LCR_8N1  0x03
#define FCR_ENABLE_RESET 0x07
#define MCR_OUTPUT2 0x08
#define LSR_DATA_READY 0x01
#define LSR_THR_EMPTY 0x20

#define LS1B_XTAL_FREQUENCY 24000000u
#define UART5_BAUDRATE      115200u

static volatile unsigned char *uart5_reg(unsigned int offset)
{
    return (volatile unsigned char *)(UART5_BASE + offset);
}

/*
 * The UART clock is the LS1B bus clock, derived from the live PLL registers
 * exactly as the RT-Thread BSP does (LS1x_BUS_FREQUENCY).  On this board the
 * debugger sets CPU 200 MHz / DDR 100 MHz, so the bus is 50 MHz and the
 * divisor is 27 rather than the old hard-coded 54.
 */
static unsigned int uart5_baud_divisor(void)
{
    unsigned int bus_clock = LS1B_BUS_FREQUENCY(LS1B_XTAL_FREQUENCY);
    unsigned int divisor = bus_clock / (16u * UART5_BAUDRATE);

    return divisor ? divisor : 1u;
}

void uart5_init(void)
{
    unsigned int divisor = uart5_baud_divisor();
    unsigned char trash;

    *uart5_reg(UART_LCR) = 0;
    *uart5_reg(UART_IER) = 0;

    *uart5_reg(UART_LCR) = LCR_DLAB;
    *uart5_reg(0) = (unsigned char)(divisor & 0xFFu);
    *uart5_reg(1) = (unsigned char)((divisor >> 8) & 0xFFu);

    *uart5_reg(UART_LCR) = LCR_8N1;
    *uart5_reg(UART_FCR) = FCR_ENABLE_RESET;
    *uart5_reg(UART_MCR) = MCR_OUTPUT2;

    trash = *uart5_reg(UART_LSR);
    trash = *uart5_reg(UART_RBR);
    trash = *uart5_reg(UART_MSR);
    (void)trash;
}

int uart5_getc(void)
{
    while ((*uart5_reg(UART_LSR) & LSR_DATA_READY) == 0) {
    }

    return (int)*uart5_reg(UART_RBR);
}

void uart5_putc(char ch)
{
    while ((*uart5_reg(UART_LSR) & LSR_THR_EMPTY) == 0) {
    }

    *uart5_reg(UART_THR) = (unsigned char)ch;
}
