#include "raster.h"
#include "platform.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xtmrctr_l.h"

#ifndef FRAMEBUFFER_BASE
#define FRAMEBUFFER_BASE XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR
#endif
#ifndef TIMER_BASE
#define TIMER_BASE XPAR_AXI_TIMER_0_BASEADDR
#endif
#ifndef READY_BASE
#define READY_BASE XPAR_AXI_GPIO_0_BASEADDR
#endif

static void print_ratio(const char *label, uint32_t cycles, uint32_t pixels)
{
    if (!pixels) {
        xil_printf("%sN/A\r\n", label);
        return;
    }
    int decimals = (int)((uint64_t)(cycles % pixels) * 100 / pixels);
    xil_printf("%s%d.%c%c\r\n", label, (int)(cycles / pixels),
               '0' + decimals / 10, '0' + decimals % 10);
}

int main(void)
{
    init_platform();
    XGpio_WriteReg(READY_BASE, XGPIO_TRI_OFFSET, 0);
    XGpio_WriteReg(READY_BASE, XGPIO_DATA_OFFSET, 0);
    volatile uint8_t *framebuffer = (volatile uint8_t *)(uintptr_t)FRAMEBUFFER_BASE;
    for (int i = 0; i < PIXELS; ++i) framebuffer[i] = 0;

    XTmrCtr_SetControlStatusReg(TIMER_BASE, 0, 0);
    XTmrCtr_SetLoadReg(TIMER_BASE, 0, 0);
    XTmrCtr_LoadTimerCounterReg(TIMER_BASE, 0);
    XTmrCtr_SetControlStatusReg(TIMER_BASE, 0, XTC_CSR_ENABLE_TMR_MASK);
    uint32_t before = XTmrCtr_GetTimerCounterReg(TIMER_BASE, 0);
    Stats stats = rasterize(&demo, framebuffer);
    uint32_t cycles = XTmrCtr_GetTimerCounterReg(TIMER_BASE, 0) - before;
    XGpio_WriteReg(READY_BASE, XGPIO_DATA_OFFSET, 1);

    xil_printf("cycles=%d tested=%d covered=%d\r\n",
               (int)cycles, (int)stats.tested, (int)stats.covered);
    print_ratio("cycles/tested pixel=", cycles, stats.tested);
    print_ratio("cycles/covered pixel=", cycles, stats.covered);
    for (;;) {}
}
