        /*
 * ============================================================================
 * Chapter 7 - Operating System Application Example 1
 *             The Sleeping-Barber Problem
 * ----------------------------------------------------------------------------
 * Loongson 1B (LS1B/LS1B200, MIPS32 little-endian) + RT-Thread 4.0.2
 *
 * This file is the design code of Code Listing 11-59 ("C code added in the
 * main.c file").  One barber thread and five customer threads are created;
 * the five customers get five different priorities, which simulates the
 * order in which the customers arrive at the barbershop.
 *
 * Synchronization objects required by section 7.1 of the guide:
 *
 *   freeseats (variable) : number of chairs still free, initial value N = 3
 *   customers (semaphore): number of customers waiting, initial value 0
 *   barber    (semaphore): state of the barber (sleeping/working), initial 0
 *   mutex     (mutex)    : protects the critical section, initial value 1
 *
 * PV algorithm of Code Listing 11-58:
 *
 *   process barber() {                      process customer() {
 *     while (true) {                          P(mutex);
 *       P(customer);                          if (freeseats > 0) {
 *       P(mutex);                               freeseats--;
 *       freeseats++;                            V(customers);
 *       V(barber);                              V(mutex);
 *       V(mutex);                               P(barber);
 *     }                                       } else {
 *   }                                           V(mutex);
 *                                             }
 *                                           }
 *
 * ============================================================================
 */

#include <rtthread.h>

#include "bsp.h"

#define THREAD_PRIORITY     10                      /* Define the thread priority          */
#define THREAD_STACK_SIZE   (1024 * 20)             /* Define the thread stack size        */
#define THREAD_TIMESLICE    5                       /* Define the thread time-slice length */

/*
 * The two values below are the ones the guide uses for the demonstration:
 * five customers and three waiting-room chairs.  They are wrapped in #ifndef
 * so that the host test harness (tests/host_sim) can build scenarios with a
 * different number of customers / chairs without touching this file.  The
 * Loongson build always uses the defaults.
 */
#ifndef customer_num
#define customer_num        5                       /* Define the total number of customers */
#endif

#ifndef WAITING_CHAIRS
#define WAITING_CHAIRS      3                       /* N: chairs in the waiting room        */
#endif

static rt_sem_t customers = RT_NULL;               /* Define the semaphore customers, value 0 */
static rt_sem_t barber = RT_NULL;                  /* Define the semaphore barber,    value 0 */
static rt_mutex_t mutex = RT_NULL;                 /* Define the mutex mutex,         value 1 */

static rt_thread_t barber_tid = RT_NULL;           /* Define 1 thread handle barber_tid      */
static rt_thread_t customer_tid[customer_num];     /* Define 5 thread handles                */

static int num[customer_num];                      /* Define the customer-number recording array num */

static unsigned char freeseats = WAITING_CHAIRS;    /* Number of available chairs, initial value N (3) */

/*----------------------------------------------------------------------------*/
/* Barber thread                                                              */
/*----------------------------------------------------------------------------*/
static void barber_thread(void *arg)               /* Thread function barber_thread */
{
    rt_err_t res;                                  /* Define the variable res                    */
    rt_uint8_t number = 0;                         /* Define the number of customers served      */

    (void)arg;

    while (1)                                      /* Infinite loop                              */
    {
        /* Acquire the semaphore customers, wait for a customer to appear.
         * While no customer is waiting this call blocks, i.e. the barber sleeps. */
        res = rt_sem_take(customers, RT_WAITING_FOREVER);

        /* If acquiring the semaphore fails, print the failure information and delete the semaphore customers */
        if (res != RT_EOK)
        {
            rt_kprintf("barber thread take a dynamic semaphore failed.\n");
            rt_sem_delete(customers);
            return;
        }

        /* If acquiring the semaphore succeeds, print the information that the barber finds a customer */
        rt_kprintf("barber find customer %d .\n", number);

        number++;                                  /* The number of customers served increases by 1 */

        rt_mutex_take(mutex, RT_WAITING_FOREVER);  /* Acquire the mutex and enter the critical section */
        freeseats++;                               /* The number of empty chairs increases by 1        */
        rt_sem_release(barber);                    /* V(barber): the barber is ready to cut hair       */
        rt_mutex_release(mutex);                   /* Release the mutex mutex                          */

        rt_kprintf("barber begin to cut hair.\n"); /* Print that the barber begins to cut hair  */
        rt_thread_mdelay(40);                      /* Simulate the time needed for a haircut    */
        rt_kprintf("barber finish cut hair.\n");   /* Print that the barber has finished        */
    }
}

/*----------------------------------------------------------------------------*/
/* Customer thread - the entry parameter distinguishes the five customers     */
/*----------------------------------------------------------------------------*/
static void customer_thread(void *arg)
{
    /*
     * The guide declares this parameter as "int num" and passes num[i]
     * directly to rt_thread_create().  rt_thread_create() requires a
     * "void *" entry parameter, so the address of the customer number is
     * passed instead and dereferenced here.  The customer number itself is
     * still 0..customer_num-1, exactly as in the guide.
     */
    int customer_index = *(int *)arg;
    rt_err_t res;                                  /* Define the result variable */

    rt_thread_mdelay(50);                          /* Simulate the arrival time of the customer */

    rt_mutex_take(mutex, RT_WAITING_FOREVER);      /* Acquire the mutex and enter the critical section */

    if (freeseats > 0)                             /* If there is an empty seat */
    {
        freeseats--;                               /* The number of empty seats decreases by 1 */
        rt_kprintf("freeseats=%d\n", freeseats);   /* Print the number of empty chairs         */
        rt_sem_release(customers);                 /* V(customers): wake the barber up         */
        rt_mutex_release(mutex);                   /* Release the mutex mutex                  */

        /* Print the information about which customer is waiting for a haircut */
        rt_kprintf("customers %d is waitting to cut hair.\n", customer_index + 1);

        /* P(barber): if the barber is busy the customer waits inside the shop */
        res = rt_sem_take(barber, RT_WAITING_FOREVER);
        (void)res;
    }
    else                                           /* If there is no empty chair */
    {
        rt_kprintf("customers %d leave.\n", customer_index + 1); /* The customer leaves the barbershop */
        rt_mutex_release(mutex);                   /* Release the mutex */
    }
}

/*----------------------------------------------------------------------------*/
int main(int argc, char **argv)
{
    int i = 0;                                     /* Initialize the variable i */
    int j = 0;                                     /* Initialize the variable j */

    (void)argc;
    (void)argv;

    rt_kprintf("\r\nWelcome to RT-Thread.\r\n\r\n");

    ls1x_drv_init();                               /* Initialize the internal and external peripheral controllers */
    rt_ls1x_drv_init();                            /* Initialize the peripheral controllers for RTT                */
    install_3th_libraries();                       /* Install the third-party libraries                            */

    for (i = 0; i < customer_num; i++)             /* Initialize the 5 customer thread handles to NULL */
        customer_tid[i] = RT_NULL;

    /* Customer numbers: the guide writes "num[customer_num] = {0,1,2,3,4}",
     * which is the same as this loop for the default shop of five customers
     * and stays correct when the test harness builds a bigger shop. */
    for (i = 0; i < customer_num; i++)
        num[i] = i;

    /* The following code creates the semaphore barber, initial value 0 (sleeping) */
    barber = rt_sem_create("barber_sem", 0, RT_IPC_FLAG_PRIO);
    if (barber != RT_NULL)
        rt_kprintf("create semaphore barber done.  The value of barber = 0\n");

    /* The following code creates the semaphore customers, initial value 0 (nobody waiting) */
    customers = rt_sem_create("cust_sem", 0, RT_IPC_FLAG_PRIO);
    if (customers != RT_NULL)
        rt_kprintf("create semaphore customers done. The value of customers = 0\n");

    /* The following code creates the mutex mutex, initial value 1 */
    mutex = rt_mutex_create("seatmutex", RT_IPC_FLAG_PRIO);
    if (mutex != RT_NULL)
        rt_kprintf("create mutex is sucessful. \n");

    /* Without all three synchronization objects the shop cannot be opened */
    if (barber == RT_NULL || customers == RT_NULL || mutex == RT_NULL)
    {
        rt_kprintf("create semaphore/mutex failed, barbershop is closed.\r\n");
        return -1;
    }

    /* The following code creates the barber thread */
    barber_tid = rt_thread_create("barber",        /* Name           */
                                  barber_thread,   /* Thread function*/
                                  RT_NULL,         /* Parameter      */
                                  THREAD_STACK_SIZE, /* Stack size   */
                                  THREAD_PRIORITY, /* Priority       */
                                  THREAD_TIMESLICE); /* Time slice   */

    /* The following code starts the barber thread */
    if (barber_tid != RT_NULL)
    {
        rt_thread_startup(barber_tid);
        rt_kprintf("barber thread  startup. \n");
    }

    /* The following code creates 5 customer threads */
    for (i = 0; i < customer_num; i++)
    {
        /* Priority of each customer thread, derived from the customer number */
        j = THREAD_PRIORITY - 5 + i;

        customer_tid[i] = rt_thread_create("customer",       /* Name            */
                                           customer_thread,  /* Thread function */
                                           (void *)&num[i],  /* Entry parameter */
                                           THREAD_STACK_SIZE, /* Stack size     */
                                           j,                /* Priority        */
                                           THREAD_TIMESLICE); /* Time slice     */

        /* Start the different customer threads and print the corresponding information */
        if (customer_tid[i] != RT_NULL)
        {
            rt_thread_startup(customer_tid[i]);
            rt_kprintf("customers %d thread  startup. \n", i + 1);
        }
    }

    return 0;
}

/*
 * @@ End
 */
