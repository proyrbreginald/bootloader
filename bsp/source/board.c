#include "loader.h"
#include "main.h"
#include <rthw.h>
#include <rtthread.h>

#if defined(RT_USING_HEAP)
void *rt_heap_begin_get(void)
{
    return (void *)&heap_addr;
}

void *rt_heap_end_get(void)
{
    return (void *)&heap_end;
}
#endif

void SysTick_Handler(void)
{
    rt_interrupt_enter();
    HAL_IncTick();
    rt_tick_increase();
    rt_interrupt_leave();
}

/**
 * This function will initial your board.
 */
void rt_hw_board_init(void)
{
    main();
    SystemCoreClockUpdate();
    /*
     * 1: OS Tick Configuration
     * Enable the hardware timer and call the rt_os_tick_callback function
     * periodically with the frequency RT_TICK_PER_SECOND.
     */
    HAL_SYSTICK_Config(HAL_RCC_GetSysClockFreq() / RT_TICK_PER_SECOND);

    /* Call components board initial (use INIT_BOARD_EXPORT()) */
#ifdef RT_USING_COMPONENTS_INIT
    rt_components_board_init();
#endif

#if defined(RT_USING_HEAP)
    rt_system_heap_init(rt_heap_begin_get(), rt_heap_end_get());
#endif
}

#ifdef RT_USING_FINSH
char rt_hw_console_getchar(void)
{
    /* Note: the initial value of ch must < 0 */
    int ch = -1;

    if (__HAL_UART_GET_FLAG(&UartHandle, UART_FLAG_RXNE) != RESET)
    {
        ch = UartHandle.Instance->DR & 0xff;
    }
    else
    {
        rt_thread_mdelay(10);
    }
    return ch;
}
#endif
