#ifndef BOARD_H
#define BOARD_H

#include <rthw.h>
#include "stm32h7xx_hal.h"
#include "uart_fifo.h"

uart_fifo_t* get_console_fifo_instance(void);
void console_init(void);

#endif // BOARD_H