#include "board.h"
#include "loader.h"
#include "main.h"
#include "uart_fifo.h"
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

    // 初始化终端
    console_init();
}

#ifdef RT_USING_FINSH

#define CONSOLE_BUF_SIZE 64 /* 定义缓冲区大小 */

/* 静态定义缓冲区内存 */
static uint8_t _console_buf[CONSOLE_BUF_SIZE];

/* 定义UART FIFO对象实例 */
static uart_fifo_t console_fifo;

/* 提供一个 API 返回实例指针 (可选，如果你想对外隐藏变量) */
uart_fifo_t *get_console_fifo_instance(void)
{
    return &console_fifo;
}

/* 初始化函数 */
void console_init(void)
{
    /* 初始化UART FIFO模块 */
    uart_fifo_init(&console_fifo, _console_buf, CONSOLE_BUF_SIZE, "shell_rx");

    /* 使能USART1的接收缓冲区非空中断 (RXNE) */
    LL_USART_EnableIT_RXNE_RXFNE(USART1);

    /* 确保USART已使能 */
    if (!LL_USART_IsEnabled(USART1))
    {
        LL_USART_Enable(USART1);
    }
}

/* FinSH移植接口 */
char rt_hw_console_getchar(void)
{
    /* ---> 调用封装好的模块读取数据 (会阻塞) <--- */
    return uart_fifo_read_wait(&console_fifo);
}
#endif
