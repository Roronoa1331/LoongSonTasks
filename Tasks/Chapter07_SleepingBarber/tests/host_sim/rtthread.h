/*
 * Host-simulation replacement for <rtthread.h>.
 *
 * Chapter 7's main.c is compiled unmodified against this header so that the
 * exact same source that is cross-compiled for the Loongson 1B can also be
 * executed and verified on a PC.  Only the small API subset used by main.c is
 * provided.  The scheduling semantics deliberately mirror RT-Thread:
 *   - preemptive, priority based (lower number == higher priority)
 *   - a thread runs until it blocks, delays, or a higher priority thread
 *     becomes ready
 *   - rt_thread_mdelay() blocks for a number of simulated milliseconds
 *   - semaphores are counting semaphores, FIFO among equal priorities
 */

#ifndef __HOST_RTTHREAD_H__
#define __HOST_RTTHREAD_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef signed long   rt_err_t;
typedef signed long   rt_int32_t;
typedef unsigned char rt_uint8_t;
typedef unsigned int  rt_uint32_t;
typedef unsigned long rt_ubase_t;

#define RT_NULL             ((void *)0)
#define RT_EOK              0
#define RT_WAITING_FOREVER  ((rt_int32_t)-1)

#define RT_IPC_FLAG_PRIO    0x00
#define RT_IPC_FLAG_FIFO    0x01

/* Scheduling constants of the Loongson target (include/rtconfig.h). */
#define RT_THREAD_PRIORITY_MAX   32
#define RT_TICK_PER_SECOND       1000
#define RT_MAIN_THREAD_PRIORITY  10

struct sim_sem;
struct sim_mutex;
struct sim_thread;

typedef struct sim_sem    *rt_sem_t;
typedef struct sim_mutex  *rt_mutex_t;
typedef struct sim_thread *rt_thread_t;

rt_sem_t    rt_sem_create(const char *name, rt_uint32_t value, rt_uint8_t flag);
rt_err_t    rt_sem_take(rt_sem_t sem, rt_int32_t time);
rt_err_t    rt_sem_release(rt_sem_t sem);
rt_err_t    rt_sem_delete(rt_sem_t sem);

rt_mutex_t  rt_mutex_create(const char *name, rt_uint8_t flag);
rt_err_t    rt_mutex_take(rt_mutex_t mutex, rt_int32_t time);
rt_err_t    rt_mutex_release(rt_mutex_t mutex);

rt_thread_t rt_thread_create(const char *name,
                             void (*entry)(void *parameter),
                             void       *parameter,
                             rt_uint32_t stack_size,
                             rt_uint8_t  priority,
                             rt_uint32_t tick);
rt_err_t    rt_thread_startup(rt_thread_t thread);
rt_err_t    rt_thread_mdelay(rt_int32_t ms);

void        rt_kprintf(const char *fmt, ...);

#ifdef __cplusplus
}
#endif

#endif /* __HOST_RTTHREAD_H__ */
