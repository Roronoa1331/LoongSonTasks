#include "uart5.h"

extern int calculator_main(void);

int bsp_start(void)
{
    uart5_init();
    return calculator_main();
}
