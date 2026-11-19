/*
 * ============================================================================
 * RT-Thread API simulator for the host (Windows).
 * ----------------------------------------------------------------------------
 * Implements exactly the API subset used by Chapter 7's main.c on top of
 * Win32 threads, with RT-Thread's scheduling rules:
 *
 *   - priorities are 0..31, lower number == higher priority
 *   - the scheduler always runs the highest priority READY thread
 *   - a thread that releases a semaphore/mutex or starts a thread is
 *     preempted immediately when a higher priority thread becomes READY
 *   - rt_thread_mdelay() blocks for a number of simulated milliseconds
 *   - simulated time only advances when no thread is READY, i.e. when the
 *     single emulated core has nothing left to run but sleeping threads
 *
 * One controller loop (rt_sim_run) makes every scheduling decision, so the
 * produced trace is deterministic and reproducible.
 * ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <windows.h>

#include "rtthread.h"
#include "sim_control.h"

#define SIM_MAX_THREADS 40

enum
{
    TS_CREATED = 0,     /* rt_thread_create() done, not started yet  */
    TS_READY,           /* runnable                                  */
    TS_BLOCKED,         /* waiting on a semaphore or a mutex         */
    TS_DELAYED,         /* inside rt_thread_mdelay()                 */
    TS_DONE             /* entry function returned                   */
};

struct sim_sem
{
    char name[16];
    int  value;
    int  alive;
};

struct sim_mutex
{
    char name[16];
    int  value;
    struct sim_thread *owner;
};

struct sim_thread
{
    char   name[12];
    void (*entry)(void *);
    void  *arg;
    int    priority;
    int    state;
    unsigned long long wake_tick;
    unsigned long long seq;

    HANDLE os_thread;
    HANDLE go;                          /* auto-reset: "it is your turn" */

    struct sim_sem   *wait_sem;
    struct sim_mutex *wait_mutex;
};

/* --- scheduler state ---------------------------------------------------- */

static CRITICAL_SECTION   g_lock;
static HANDLE             g_cpu_released;   /* manual reset event        */
static struct sim_thread *g_threads[SIM_MAX_THREADS];
static int                g_nthreads;
static struct sim_thread *g_current;
static unsigned long long g_tick;
static unsigned long long g_seq;
static int                g_switch_count;

/* ------------------------------------------------------------------------ */

static void fatal(const char *msg)
{
    fprintf(stderr, "SIM FATAL: %s\n", msg);
    fflush(stderr);
    exit(2);
}

/* ------------------------------------------------------------------------ */
/* Scheduling                                                                */
/* ------------------------------------------------------------------------ */

/* Highest priority READY thread, ties broken by creation order (RT-Thread
 * ready-queue order).  Advances simulated time when nothing is READY. */
static struct sim_thread *pick_next_locked(void)
{
    for (;;)
    {
        struct sim_thread *best = NULL;
        unsigned long long earliest = ~0ULL;
        int any_delayed = 0;
        int i;

        for (i = 0; i < g_nthreads; i++)
        {
            struct sim_thread *t = g_threads[i];

            if (t->state == TS_READY)
            {
                if (best == NULL ||
                    t->priority < best->priority ||
                    (t->priority == best->priority && t->seq < best->seq))
                {
                    best = t;
                }
            }
            else if (t->state == TS_DELAYED)
            {
                any_delayed = 1;
                if (t->wake_tick < earliest)
                    earliest = t->wake_tick;
            }
        }

        if (best != NULL)
            return best;

        if (!any_delayed)
            return NULL;                /* quiescent: nothing can ever run */

        if (earliest > g_tick)
            g_tick = earliest;

        for (i = 0; i < g_nthreads; i++)
        {
            struct sim_thread *t = g_threads[i];
            if (t->state == TS_DELAYED && t->wake_tick <= g_tick)
                t->state = TS_READY;
        }
    }
}

/* Hands the CPU back to the controller loop and blocks until this thread is
 * scheduled again.  Must be called with g_lock held; returns with g_lock
 * released.  The caller must already have removed the thread from READY. */
static void release_cpu(struct sim_thread *me)
{
    g_current  = NULL;
    g_switch_count++;
    LeaveCriticalSection(&g_lock);
    SetEvent(g_cpu_released);
    WaitForSingleObject(me->go, INFINITE);
}

/* Voluntary preemption point: loses the CPU when a higher priority thread has
 * become ready (semaphore/mutex release, thread startup). */
static void schedule_point(void)
{
    struct sim_thread *me;
    struct sim_thread *best;

    EnterCriticalSection(&g_lock);

    me = g_current;
    if (me == NULL || me->state != TS_READY)
    {
        LeaveCriticalSection(&g_lock);
        return;
    }

    best = pick_next_locked();
    if (best != NULL && best != me)
    {
        release_cpu(me);                /* me stays READY, it just loses the CPU */
        return;
    }

    LeaveCriticalSection(&g_lock);
}

static DWORD WINAPI thread_trampoline(LPVOID param)
{
    struct sim_thread *t = (struct sim_thread *)param;

    WaitForSingleObject(t->go, INFINITE);   /* wait until scheduled */

    t->entry(t->arg);

    /* RT-Thread deletes a thread whose entry function returns. */
    EnterCriticalSection(&g_lock);
    t->state = TS_DONE;
    release_cpu(t);
    return 0;
}

/* ------------------------------------------------------------------------ */
/* Threads                                                                   */
/* ------------------------------------------------------------------------ */

rt_thread_t rt_thread_create(const char *name,
                             void (*entry)(void *parameter),
                             void       *parameter,
                             rt_uint32_t stack_size,
                             rt_uint8_t  priority,
                             rt_uint32_t tick)
{
    struct sim_thread *t;
    DWORD stack;

    (void)tick;

    if (entry == NULL || priority >= RT_THREAD_PRIORITY_MAX || g_nthreads >= SIM_MAX_THREADS)
        return RT_NULL;

    t = (struct sim_thread *)calloc(1, sizeof(*t));
    if (t == NULL)
        return RT_NULL;

    strncpy(t->name, name ? name : "thread", sizeof(t->name) - 1);
    t->entry    = entry;
    t->arg      = parameter;
    t->priority = priority;
    t->state    = TS_CREATED;
    t->seq      = g_seq++;
    t->go       = CreateEvent(NULL, FALSE, FALSE, NULL);
    if (t->go == NULL)
    {
        free(t);
        return RT_NULL;
    }

    /* The target stack size is honoured as a lower bound; a PC thread needs
     * more head room because printf()/CRT use far more stack than RT-Thread's
     * tiny rt_kprintf() implementation. */
    stack = stack_size;
    if (stack < 256u * 1024u)
        stack = 256u * 1024u;

    t->os_thread = CreateThread(NULL, stack, thread_trampoline, t, 0, NULL);
    if (t->os_thread == NULL)
    {
        CloseHandle(t->go);
        free(t);
        return RT_NULL;
    }

    EnterCriticalSection(&g_lock);
    g_threads[g_nthreads++] = t;
    LeaveCriticalSection(&g_lock);

    return t;
}

rt_err_t rt_thread_startup(rt_thread_t thread)
{
    if (thread == NULL)
        return -1;

    EnterCriticalSection(&g_lock);
    if (thread->state == TS_CREATED)
        thread->state = TS_READY;
    LeaveCriticalSection(&g_lock);

    /* A thread with a higher priority than its creator preempts it at once. */
    schedule_point();
    return RT_EOK;
}

rt_err_t rt_thread_mdelay(rt_int32_t ms)
{
    struct sim_thread *me;

    if (ms <= 0)
    {
        schedule_point();
        return RT_EOK;
    }

    EnterCriticalSection(&g_lock);
    me = g_current;
    me->wake_tick = g_tick + (unsigned long long)ms;
    me->state     = TS_DELAYED;
    release_cpu(me);
    return RT_EOK;
}

/* ------------------------------------------------------------------------ */
/* Semaphores                                                                */
/* ------------------------------------------------------------------------ */

rt_sem_t rt_sem_create(const char *name, rt_uint32_t value, rt_uint8_t flag)
{
    struct sim_sem *s = (struct sim_sem *)calloc(1, sizeof(*s));

    (void)flag;
    if (s == NULL)
        return RT_NULL;

    strncpy(s->name, name ? name : "sem", sizeof(s->name) - 1);
    s->value = (int)value;
    s->alive = 1;
    return s;
}

rt_err_t rt_sem_take(rt_sem_t sem, rt_int32_t time)
{
    struct sim_thread *me;

    (void)time;
    if (sem == NULL || !sem->alive)
        return -1;

    EnterCriticalSection(&g_lock);

    if (sem->value > 0)
    {
        sem->value--;
        LeaveCriticalSection(&g_lock);
        return RT_EOK;
    }

    me = g_current;
    me->state    = TS_BLOCKED;
    me->wait_sem = sem;
    release_cpu(me);

    me->wait_sem = NULL;
    return RT_EOK;
}

rt_err_t rt_sem_release(rt_sem_t sem)
{
    struct sim_thread *woken = NULL;
    int i;

    if (sem == NULL || !sem->alive)
        return -1;

    EnterCriticalSection(&g_lock);

    sem->value++;

    /* Wake the highest priority thread blocked on this semaphore. */
    for (i = 0; i < g_nthreads; i++)
    {
        struct sim_thread *t = g_threads[i];
        if (t->state == TS_BLOCKED && t->wait_sem == sem)
        {
            if (woken == NULL ||
                t->priority < woken->priority ||
                (t->priority == woken->priority && t->seq < woken->seq))
            {
                woken = t;
            }
        }
    }

    if (woken != NULL)
    {
        woken->wait_sem = NULL;
        woken->state    = TS_READY;
        sem->value--;
    }

    LeaveCriticalSection(&g_lock);

    schedule_point();
    return RT_EOK;
}

rt_err_t rt_sem_delete(rt_sem_t sem)
{
    if (sem != NULL)
        sem->alive = 0;
    return RT_EOK;
}

/* ------------------------------------------------------------------------ */
/* Mutexes                                                                   */
/* ------------------------------------------------------------------------ */

rt_mutex_t rt_mutex_create(const char *name, rt_uint8_t flag)
{
    struct sim_mutex *m = (struct sim_mutex *)calloc(1, sizeof(*m));

    (void)flag;
    if (m == NULL)
        return RT_NULL;

    strncpy(m->name, name ? name : "mutex", sizeof(m->name) - 1);
    m->value = 1;
    m->owner = NULL;
    return m;
}

rt_err_t rt_mutex_take(rt_mutex_t mutex, rt_int32_t time)
{
    struct sim_thread *me;

    (void)time;
    if (mutex == NULL)
        return -1;

    EnterCriticalSection(&g_lock);

    if (mutex->value > 0)
    {
        mutex->value--;
        mutex->owner = g_current;
        LeaveCriticalSection(&g_lock);
        return RT_EOK;
    }

    me = g_current;
    me->state      = TS_BLOCKED;
    me->wait_mutex = mutex;
    release_cpu(me);

    /* The releasing thread already handed the mutex over to this thread. */
    me->wait_mutex = NULL;
    EnterCriticalSection(&g_lock);
    mutex->owner = me;
    LeaveCriticalSection(&g_lock);
    return RT_EOK;
}

rt_err_t rt_mutex_release(rt_mutex_t mutex)
{
    struct sim_thread *woken = NULL;
    int i;

    if (mutex == NULL)
        return -1;

    EnterCriticalSection(&g_lock);

    mutex->value++;
    mutex->owner = NULL;

    for (i = 0; i < g_nthreads; i++)
    {
        struct sim_thread *t = g_threads[i];
        if (t->state == TS_BLOCKED && t->wait_mutex == mutex)
        {
            if (woken == NULL ||
                t->priority < woken->priority ||
                (t->priority == woken->priority && t->seq < woken->seq))
            {
                woken = t;
            }
        }
    }

    if (woken != NULL)
    {
        mutex->value--;                 /* hand the mutex straight over */
        woken->state = TS_READY;
    }

    LeaveCriticalSection(&g_lock);

    schedule_point();
    return RT_EOK;
}

/* ------------------------------------------------------------------------ */
/* Console                                                                   */
/* ------------------------------------------------------------------------ */

void rt_kprintf(const char *fmt, ...)
{
    va_list ap;

    va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
    fflush(stdout);
}

/* ------------------------------------------------------------------------ */
/* Controller loop (test harness entry point)                                */
/* ------------------------------------------------------------------------ */

void rt_sim_init(void)
{
    InitializeCriticalSection(&g_lock);
    g_cpu_released = CreateEvent(NULL, TRUE, FALSE, NULL);
    if (g_cpu_released == NULL)
        fatal("cannot create controller event");

    g_tick         = 0;
    g_seq          = 0;
    g_nthreads     = 0;
    g_current      = NULL;
    g_switch_count = 0;
}

/* Registers the "main" thread object; the harness runs main() on it. */
rt_thread_t rt_sim_make_main_thread(void)
{
    struct sim_thread *t = (struct sim_thread *)calloc(1, sizeof(*t));

    if (t == NULL)
        fatal("out of memory");

    strncpy(t->name, "main", sizeof(t->name) - 1);
    t->priority = RT_MAIN_THREAD_PRIORITY;
    t->state    = TS_READY;
    t->seq      = g_seq++;
    t->go       = CreateEvent(NULL, FALSE, FALSE, NULL);
    if (t->go == NULL)
        fatal("cannot create main thread event");

    g_threads[g_nthreads++] = t;
    return t;
}

static int (*g_app_entry)(int, char **);

static DWORD WINAPI app_trampoline(LPVOID param)
{
    struct sim_thread *t = g_threads[0];

    (void)param;

    WaitForSingleObject(t->go, INFINITE);    /* wait until the controller picks us */
    g_app_entry(0, NULL);
    rt_sim_main_finished();
    return 0;
}

/* Creates the OS thread that executes the application's main(). */
HANDLE rt_sim_launch_app(int (*entry)(int argc, char **argv))
{
    g_app_entry = entry;
    return CreateThread(NULL, 0, app_trampoline, NULL, 0, NULL);
}

/* Called by the harness once main() has returned. */
void rt_sim_main_finished(void)
{
    EnterCriticalSection(&g_lock);
    g_threads[0]->state = TS_DONE;
    g_current = NULL;
    g_switch_count++;
    LeaveCriticalSection(&g_lock);
    SetEvent(g_cpu_released);
}

/* Runs the simulation until no thread can make progress.
 * Returns 0 on a clean quiescent state, 1 if the switch budget was exceeded. */
int rt_sim_run(long max_switches)
{
    for (;;)
    {
        struct sim_thread *next;

        EnterCriticalSection(&g_lock);
        next = pick_next_locked();
        if (next == NULL)
        {
            g_current = NULL;
            LeaveCriticalSection(&g_lock);
            return 0;
        }
        g_current = next;
        SetEvent(next->go);
        LeaveCriticalSection(&g_lock);

        if (g_switch_count > max_switches)
        {
            fprintf(stderr, "SIM: switch budget exceeded (%ld) - possible livelock\n",
                    max_switches);
            return 1;
        }

        WaitForSingleObject(g_cpu_released, INFINITE);
        ResetEvent(g_cpu_released);
    }
}

/* --- introspection for the test harness --------------------------------- */

unsigned long long rt_sim_tick(void)   { return g_tick; }
int rt_sim_switch_count(void)          { return g_switch_count; }
int rt_sim_thread_count(void)          { return g_nthreads; }

const char *rt_sim_thread_name(int index)
{
    return (index >= 0 && index < g_nthreads) ? g_threads[index]->name : "?";
}

int rt_sim_thread_state(int index)
{
    return (index >= 0 && index < g_nthreads) ? g_threads[index]->state : -1;
}

int rt_sim_thread_priority(int index)
{
    return (index >= 0 && index < g_nthreads) ? g_threads[index]->priority : -1;
}

int rt_sim_state_blocked(void) { return TS_BLOCKED; }
int rt_sim_state_done(void)    { return TS_DONE; }

/* Describes what a still-live thread is waiting for. */
const char *rt_sim_thread_wait(int index)
{
    static char buf[64];
    struct sim_thread *t;

    if (index < 0 || index >= g_nthreads)
        return "";

    t = g_threads[index];

    if (t->state == TS_BLOCKED && t->wait_sem != NULL)
    {
        sprintf(buf, "semaphore '%s'", t->wait_sem->name);
        return buf;
    }

    if (t->state == TS_BLOCKED && t->wait_mutex != NULL)
    {
        sprintf(buf, "mutex '%s'", t->wait_mutex->name);
        return buf;
    }

    switch (t->state)
    {
        case TS_DONE:    return "finished";
        case TS_DELAYED: return "delayed";
        case TS_READY:   return "runnable";
        default:         return "created";
    }
}
