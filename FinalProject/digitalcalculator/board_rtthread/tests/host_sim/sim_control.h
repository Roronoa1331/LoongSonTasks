/*
 * Control interface of the host RT-Thread simulator, used only by the
 * test harness (main_host.c) - main.c never sees this header.
 */

#ifndef __SIM_CONTROL_H__
#define __SIM_CONTROL_H__

#include <windows.h>
#include "rtthread.h"

void  rt_sim_init(void);
rt_thread_t rt_sim_make_main_thread(void);

/* Creates the OS thread that runs main() on the emulated "main" thread.
 * The thread blocks until the controller schedules it. */
HANDLE rt_sim_launch_app(int (*entry)(int argc, char **argv));

/* Runs the simulation until no thread can make progress.
 * 0 = quiescent, 1 = switch budget exceeded. */
int rt_sim_run(long max_switches);

/* Called once the application's main() has returned. */
void rt_sim_main_finished(void);

unsigned long long rt_sim_tick(void);
int  rt_sim_switch_count(void);
int  rt_sim_thread_count(void);
const char *rt_sim_thread_name(int index);
int  rt_sim_thread_state(int index);
int  rt_sim_thread_priority(int index);
const char *rt_sim_thread_wait(int index);

int rt_sim_state_blocked(void);
int rt_sim_state_done(void);

#endif /* __SIM_CONTROL_H__ */
