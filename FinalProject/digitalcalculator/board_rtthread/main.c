/*
 * Board application entry point for the RT-Thread LS1B200 port.
 * The UART console is initialized by the existing BSP before main() runs.
 */

#include <rtthread.h>
#include "bsp.h"

int calculator_main(void);

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    rt_kprintf("\r\nDigital Calculator ready. Type calculator at the msh prompt.\r\n");

    ls1x_drv_init();
    rt_ls1x_drv_init();
    install_3th_libraries();

    for (;;) {
        rt_thread_mdelay(1000);
    }

    return 0;
}
