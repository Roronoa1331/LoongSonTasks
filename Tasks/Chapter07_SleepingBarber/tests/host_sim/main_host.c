/*
 * ============================================================================
 * Host test harness for Chapter 7 (The Sleeping-Barber Problem).
 * ----------------------------------------------------------------------------
 * This program executes the *unmodified* ../../main.c of the Loongson project
 * on the PC by supplying:
 *   - a small RT-Thread API simulator (rtthread_sim.c)
 *   - no-op board initialisation stubs (ls1x_drv_init & friends)
 *
 * main.c is compiled with -Dmain=app_main so that this harness keeps its own
 * main() entry point.
 *
 * Build variants select the scenario, e.g.:
 *   gcc -I. -Dmain=app_main -Dcustomer_num=1 -DWAITING_CHAIRS=3 ...
 *
 * Exit code 0 = all invariants hold, 1 = a check failed.
 * ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

#include "sim_control.h"

#ifndef customer_num
#define customer_num 5
#endif

#ifndef WAITING_CHAIRS
#define WAITING_CHAIRS 3
#endif

#define MAX_SWITCHES 200000L

/* --- board initialisation stubs ----------------------------------------- */

int ls1x_drv_init(void)         { return 0; }
int rt_ls1x_drv_init(void)      { return 0; }
int install_3th_libraries(void) { return 0; }

void delay_us(unsigned int us)  { (void)us; }
void delay_ms(unsigned int ms)  { (void)ms; }

/* --- the application under test ----------------------------------------- */

extern int app_main(int argc, char **argv);

/* ======================================================================== */

int main(int argc, char **argv)
{
    HANDLE app;
    int    rc;
    int    i;
    int    blocked = 0;
    int    barber_threads = 0;
    int    customer_threads = 0;
    int    failed = 0;

    (void)argc;
    (void)argv;

    printf("=== HOST SIMULATION: customer_num=%d, waiting chairs=%d ===\n\n",
           customer_num, WAITING_CHAIRS);

    rt_sim_init();
    rt_sim_make_main_thread();
    app = rt_sim_launch_app(app_main);
    if (app == NULL)
    {
        printf("cannot start the application thread\n");
        return 2;
    }

    rc = rt_sim_run(MAX_SWITCHES);

    /* Give the remaining thread objects a moment to record their exit state. */
    Sleep(50);
    WaitForSingleObject(app, 2000);

    printf("\n\n==== HOST SIMULATION REPORT ====\n");
    printf("customer threads requested : %d\n", customer_num);
    printf("waiting chairs             : %d\n", WAITING_CHAIRS);
    printf("simulated time             : %lu ms\n", (unsigned long)rt_sim_tick());
    printf("context switches           : %d\n", rt_sim_switch_count());
    printf("livelock (budget exceeded) : %s\n", rc ? "YES" : "no");
    printf("\nthreads:\n");

    for (i = 0; i < rt_sim_thread_count(); i++)
    {
        const char *name = rt_sim_thread_name(i);
        const char *wait = rt_sim_thread_wait(i);

        printf("  %-9s prio %2d  %s\n", name, rt_sim_thread_priority(i), wait);

        if (strcmp(name, "barber") == 0 && rt_sim_thread_state(i) != rt_sim_state_done())
            barber_threads++;

        if (strcmp(name, "customer") == 0 && rt_sim_thread_state(i) != rt_sim_state_done())
            customer_threads++;

        if (rt_sim_thread_state(i) == rt_sim_state_blocked())
            blocked++;
    }

    printf("\nthreads still blocked      : %d\n", blocked);

    /* --- invariants ----------------------------------------------------- */

    if (rc != 0)
    {
        printf("CHECK FAILED: livelock / switch budget exceeded\n");
        failed = 1;
    }

    if (barber_threads != 1)
    {
        printf("CHECK FAILED: the barber thread is not alive at the end\n");
        failed = 1;
    }

    if (blocked != 1)
    {
        printf("CHECK FAILED: %d threads still blocked at the end "
               "(expected only the sleeping barber)\n", blocked);
        failed = 1;
    }

    if (customer_threads != 0)
    {
        printf("CHECK FAILED: %d customer threads never finished\n", customer_threads);
        failed = 1;
    }

    printf("\nVERDICT: %s\n", failed ? "FAIL" : "PASS");
    return failed;
}
