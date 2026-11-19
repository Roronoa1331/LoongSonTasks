/*
 * Host-simulation replacement for the BSP header used by main.c.
 * main.c only needs the three board initialisation entry points and delay_ms().
 */

#ifndef _BSP_H
#define _BSP_H

#ifdef __cplusplus
extern "C" {
#endif

#define CPU_XTAL_FREQUENCY  24000000

extern int ls1x_drv_init(void);
extern int rt_ls1x_drv_init(void);
extern int install_3th_libraries(void);

extern void delay_us(unsigned int us);
extern void delay_ms(unsigned int ms);

#ifdef __cplusplus
}
#endif

#endif /* _BSP_H */
