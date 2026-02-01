.syntax unified
.cpu cortex-m7
.fpu fpv5-d16
.thumb

.global isr_table
.global default_handler

/* 存储器地址信息，用于引导程序跳转到应用程序 */
.word _itcm_flash_addr
.word _itcm_ram_addr
.word _itcm_ram_end
.word _data_flash_addr      /* 数据段在Flash中的起始地址 */
.word _data_ram_addr        /* 数据段在RAM中的起始地址 */
.word _data_ram_end         /* 数据段在RAM中的结束地址 */
.word _bss_ram_addr         /* BSS段在RAM中的起始地址 */
.word _bss_ram_end          /* BSS段在RAM中的结束地址 */

.section .text.reset_handler
.type reset_handler, %function

reset_handler:
  /* 设置初始堆栈指针 */
  ldr sp, =stack_init_val

  /* 退出可能的低功耗模式，切换到正常模式并配置电源供应 */
  bl ExitRun0Mode 

  /* 初始化FPU、时钟系统并配置中断向量表 */
  bl SystemInit 

  /* 将数据段初始化值从Flash复制到SRAM */
  ldr r0, =_data_ram_addr   /* 源地址：RAM中数据段的起始地址 */
  ldr r1, =_data_ram_end    /* 目标地址：RAM中数据段的结束地址 */
  ldr r2, =_data_flash_addr /* Flash中存储的初始化数据地址 */
  movs r3, #0               /* 偏移量初始化为0 */
  b loop_copy_data

copy_data:
  ldr r4, [r2, r3]          /* 从Flash加载一个字到r4 */
  str r4, [r0, r3]          /* 存储到SRAM中对应位置 */
  adds r3, r3, #4           /* 地址偏移增加4个字节(32位) */

loop_copy_data:
  adds r4, r0, r3           /* 计算当前处理的位置 */
  cmp r4, r1                /* 比较当前位置与结束位置 */
  bcc copy_data             /* 如果未达到结束位置则继续复制 */
 
  /* --- 复制ITCM代码从Flash到ITCM --- */
  /* 逻辑与复制.data段完全相同，只是地址不同 */
  ldr r0, =_itcm_ram_addr    /* 目标地址：ITCMRAM起始 */
  ldr r1, =_itcm_ram_end    /* 目标地址：ITCMRAM结束 */
  ldr r2, =_itcm_flash_addr /* 源地址：Flash */
  movs r3, #0               /* 偏移清零 */
  b loop_copy_itcm

copy_itcm:
  ldr r4, [r2, r3]
  str r4, [r0, r3]
  adds r3, r3, #4

loop_copy_itcm:
  adds r4, r0, r3
  cmp r4, r1
  bcc copy_itcm

  /* 使用0填充BSS段(未初始化的数据段) */
  ldr r2, =_bss_ram_addr    /* 获取BSS段起始地址 */
  ldr r4, =_bss_ram_end     /* 获取BSS段结束地址 */
  movs r3, #0               /* 加载0值 */
  b loop_fill_bss_zero

fill_bss_zero:
  str r3, [r2]              /* 将0写入BSS段当前地址 */
  adds r2, r2, #4           /* 地址前进4个字节 */

loop_fill_bss_zero:
  cmp r2, r4                /* 比较当前地址与BSS段结束地址 */
  bcc fill_bss_zero         /* 如果未到达结束地址则继续填充 */

  /* 调用应用程序入口点 */
  bl loader                 /* 调用loader函数 */
  bx lr                     /* 返回(正常情况下不会执行到这里) */
.size reset_handler, .-reset_handler

/* 默认中断处理程序 */
.section .text.default_handler, "ax", %progbits
default_handler:
Infinite_Loop:
  b Infinite_Loop           /* 陷入无限循环 */
.size default_handler, .-default_handler

/* 中断向量表定义 */
.section .isr_vector, "a", %progbits
.type isr_table, %object

isr_table:
.word stack_init_val        /* 初始堆栈指针值 */
.word reset_handler         /* 复位处理程序 */

/* Cortex-M内核中断 */
.word NMI_Handler                           /* 不可屏蔽中断处理程序 */
.word HardFault_Handler                     /* 硬件错误中断处理程序 */
.word MemManage_Handler                     /* 内存管理中断处理程序 */
.word BusFault_Handler                      /* 总线错误中断处理程序 */
.word UsageFault_Handler                    /* 使用错误中断处理程序 */
.word 0                                     /* 保留 */
.word 0                                     /* 保留 */
.word 0                                     /* 保留 */
.word 0                                     /* 保留 */
.word SVC_Handler                           /* 系统服务调用通过SVC指令 */
.word DebugMon_Handler                      /* 调试监控器处理程序 */
.word 0                                     /* 保留 */
.word PendSV_Handler                        /* 可挂起的系统服务 */
.word SysTick_Handler                       /* 系统节拍定时器中断 */

/* 外部中断向量表 - STM32H743特有中断 */
.word WWDG_IRQHandler                       /* 窗口看门狗中断 */
.word PVD_AVD_IRQHandler                    /* 掉电/可编程电压检测器通过外部中断线路 */
.word TAMP_STAMP_IRQHandler                 /* 防篡改和时间戳通过外部中断线路 */
.word RTC_WKUP_IRQHandler                   /* RTC唤醒通过外部中断线路 */
.word FLASH_IRQHandler                      /* Flash存储器 */
.word RCC_IRQHandler                        /* RCC时钟控制器 */
.word EXTI0_IRQHandler                      /* 外部中断线路0 */
.word EXTI1_IRQHandler                      /* 外部中断线路1 */
.word EXTI2_IRQHandler                      /* 外部中断线路2 */
.word EXTI3_IRQHandler                      /* 外部中断线路3 */
.word EXTI4_IRQHandler                      /* 外部中断线路4 */
.word DMA1_Stream0_IRQHandler               /* DMA1流0 */
.word DMA1_Stream1_IRQHandler               /* DMA1流1 */
.word DMA1_Stream2_IRQHandler               /* DMA1流2 */
.word DMA1_Stream3_IRQHandler               /* DMA1流3 */
.word DMA1_Stream4_IRQHandler               /* DMA1流4 */
.word DMA1_Stream5_IRQHandler               /* DMA1流5 */
.word DMA1_Stream6_IRQHandler               /* DMA1流6 */
.word ADC_IRQHandler                        /* ADC1, ADC2和ADC3 */
.word FDCAN1_IT0_IRQHandler                 /* FDCAN1中断线路0 */
.word FDCAN2_IT0_IRQHandler                 /* FDCAN2中断线路0 */
.word FDCAN1_IT1_IRQHandler                 /* FDCAN1中断线路1 */
.word FDCAN2_IT1_IRQHandler                 /* FDCAN2中断线路1 */
.word EXTI9_5_IRQHandler                    /* 外部线路[9:5] */
.word TIM1_BRK_IRQHandler                   /* TIM1刹车中断 */
.word TIM1_UP_IRQHandler                    /* TIM1更新中断 */
.word TIM1_TRG_COM_IRQHandler               /* TIM1触发和通信中断 */
.word TIM1_CC_IRQHandler                    /* TIM1捕获比较中断 */
.word TIM2_IRQHandler                       /* TIM2全局中断 */
.word TIM3_IRQHandler                       /* TIM3全局中断 */
.word TIM4_IRQHandler                       /* TIM4全局中断 */
.word I2C1_EV_IRQHandler                    /* I2C1事件 */
.word I2C1_ER_IRQHandler                    /* I2C1错误 */
.word I2C2_EV_IRQHandler                    /* I2C2事件 */
.word I2C2_ER_IRQHandler                    /* I2C2错误 */
.word SPI1_IRQHandler                       /* SPI1全局中断 */
.word SPI2_IRQHandler                       /* SPI2全局中断 */
.word USART1_IRQHandler                     /* USART1全局中断 */
.word USART2_IRQHandler                     /* USART2全局中断 */
.word USART3_IRQHandler                     /* USART3全局中断 */
.word EXTI15_10_IRQHandler                  /* 外部线路[15:10] */
.word RTC_Alarm_IRQHandler                  /* RTC报警中断(A和B)通过外部中断线路 */
.word 0                                     /* 保留 */
.word TIM8_BRK_TIM12_IRQHandler             /* TIM8刹车和TIM12全局中断 */
.word TIM8_UP_TIM13_IRQHandler              /* TIM8更新和TIM13全局中断 */
.word TIM8_TRG_COM_TIM14_IRQHandler         /* TIM8触发和通信和TIM14全局中断 */
.word TIM8_CC_IRQHandler                    /* TIM8捕获比较中断 */
.word DMA1_Stream7_IRQHandler               /* DMA1流7 */
.word FMC_IRQHandler                        /* FMC全局中断 */
.word SDMMC1_IRQHandler                     /* SDMMC1全局中断 */
.word TIM5_IRQHandler                       /* TIM5全局中断 */
.word SPI3_IRQHandler                       /* SPI3全局中断 */
.word UART4_IRQHandler                      /* UART4全局中断 */
.word UART5_IRQHandler                      /* UART5全局中断 */
.word TIM6_DAC_IRQHandler                   /* TIM6和DAC1&2未触发错误 */
.word TIM7_IRQHandler                       /* TIM7全局中断 */
.word DMA2_Stream0_IRQHandler               /* DMA2流0 */
.word DMA2_Stream1_IRQHandler               /* DMA2流1 */
.word DMA2_Stream2_IRQHandler               /* DMA2流2 */
.word DMA2_Stream3_IRQHandler               /* DMA2流3 */
.word DMA2_Stream4_IRQHandler               /* DMA2流4 */
.word ETH_IRQHandler                        /* 以太网全局中断 */
.word ETH_WKUP_IRQHandler                   /* 以太网通过外部中断唤醒 */
.word FDCAN_CAL_IRQHandler                  /* FDCAN校准单元中断 */
.word 0                                     /* 保留 */
.word 0                                     /* 保留 */
.word 0                                     /* 保留 */
.word 0                                     /* 保留 */
.word DMA2_Stream5_IRQHandler               /* DMA2流5 */
.word DMA2_Stream6_IRQHandler               /* DMA2流6 */
.word DMA2_Stream7_IRQHandler               /* DMA2流7 */
.word USART6_IRQHandler                     /* USART6全局中断 */
.word I2C3_EV_IRQHandler                    /* I2C3事件 */
.word I2C3_ER_IRQHandler                    /* I2C3错误 */
.word OTG_HS_EP1_OUT_IRQHandler             /* USB OTG HS端点1接收 */
.word OTG_HS_EP1_IN_IRQHandler              /* USB OTG HS端点1发送 */
.word OTG_HS_WKUP_IRQHandler                /* USB OTG HS通过外部中断唤醒 */
.word OTG_HS_IRQHandler                     /* USB OTG HS全局中断 */
.word DCMI_IRQHandler                       /* DCMI全局中断 */
.word 0                                     /* 保留 */
.word RNG_IRQHandler                        /* 随机数发生器全局中断 */
.word FPU_IRQHandler                        /* 浮点运算单元全局中断 */
.word UART7_IRQHandler                      /* UART7全局中断 */
.word UART8_IRQHandler                      /* UART8全局中断 */
.word SPI4_IRQHandler                       /* SPI4全局中断 */
.word SPI5_IRQHandler                       /* SPI5全局中断 */
.word SPI6_IRQHandler                       /* SPI6全局中断 */
.word SAI1_IRQHandler                       /* SAI1全局中断 */
.word LTDC_IRQHandler                       /* LTDC全局中断 */
.word LTDC_ER_IRQHandler                    /* LTDC错误全局中断 */
.word DMA2D_IRQHandler                      /* DMA2D全局中断 */
.word SAI2_IRQHandler                       /* SAI2全局中断 */
.word QUADSPI_IRQHandler                    /* 四路SPI全局中断 */
.word LPTIM1_IRQHandler                     /* 低功耗定时器1全局中断 */
.word CEC_IRQHandler                        /* HDMI_CEC全局中断 */
.word I2C4_EV_IRQHandler                    /* I2C4事件 */
.word I2C4_ER_IRQHandler                    /* I2C4错误 */
.word SPDIF_RX_IRQHandler                   /* SPDIF_RX全局中断 */
.word OTG_FS_EP1_OUT_IRQHandler             /* USB OTG FS端点1接收 */
.word OTG_FS_EP1_IN_IRQHandler              /* USB OTG FS端点1发送 */
.word OTG_FS_WKUP_IRQHandler                /* USB OTG FS通过外部中断唤醒 */
.word OTG_FS_IRQHandler                     /* USB OTG FS全局中断 */
.word DMAMUX1_OVR_IRQHandler                /* DMAMUX1溢出中断 */
.word HRTIM1_Master_IRQHandler              /* HRTIM主定时器全局中断 */
.word HRTIM1_TIMA_IRQHandler                /* HRTIM定时器A全局中断 */
.word HRTIM1_TIMB_IRQHandler                /* HRTIM定时器B全局中断 */
.word HRTIM1_TIMC_IRQHandler                /* HRTIM定时器C全局中断 */
.word HRTIM1_TIMD_IRQHandler                /* HRTIM定时器D全局中断 */
.word HRTIM1_TIME_IRQHandler                /* HRTIM定时器E全局中断 */
.word HRTIM1_FLT_IRQHandler                 /* HRTIM故障全局中断 */
.word DFSDM1_FLT0_IRQHandler                /* DFSDM滤波器0中断 */
.word DFSDM1_FLT1_IRQHandler                /* DFSDM滤波器1中断 */
.word DFSDM1_FLT2_IRQHandler                /* DFSDM滤波器2中断 */
.word DFSDM1_FLT3_IRQHandler                /* DFSDM滤波器3中断 */
.word SAI3_IRQHandler                       /* SAI3全局中断 */
.word SWPMI1_IRQHandler                     /* 单线协议接口1全局中断 */
.word TIM15_IRQHandler                      /* TIM15全局中断 */
.word TIM16_IRQHandler                      /* TIM16全局中断 */
.word TIM17_IRQHandler                      /* TIM17全局中断 */
.word MDIOS_WKUP_IRQHandler                 /* MDIOS唤醒中断 */
.word MDIOS_IRQHandler                      /* MDIOS全局中断 */
.word JPEG_IRQHandler                       /* JPEG全局中断 */
.word MDMA_IRQHandler                       /* MDMA全局中断 */
.word 0                                     /* 保留 */
.word SDMMC2_IRQHandler                     /* SDMMC2全局中断 */
.word HSEM1_IRQHandler                      /* HSEM1全局中断 */
.word 0                                     /* 保留 */
.word ADC3_IRQHandler                       /* ADC3全局中断 */
.word DMAMUX2_OVR_IRQHandler                /* DMAMUX溢出中断 */
.word BDMA_Channel0_IRQHandler              /* BDMA通道0全局中断 */
.word BDMA_Channel1_IRQHandler              /* BDMA通道1全局中断 */
.word BDMA_Channel2_IRQHandler              /* BDMA通道2全局中断 */
.word BDMA_Channel3_IRQHandler              /* BDMA通道3全局中断 */
.word BDMA_Channel4_IRQHandler              /* BDMA通道4全局中断 */
.word BDMA_Channel5_IRQHandler              /* BDMA通道5全局中断 */
.word BDMA_Channel6_IRQHandler              /* BDMA通道6全局中断 */
.word BDMA_Channel7_IRQHandler              /* BDMA通道7全局中断 */
.word COMP1_IRQHandler                      /* 比较器1全局中断 */
.word LPTIM2_IRQHandler                     /* 低功耗定时器2全局中断 */
.word LPTIM3_IRQHandler                     /* 低功耗定时器3全局中断 */
.word LPTIM4_IRQHandler                     /* 低功耗定时器4全局中断 */
.word LPTIM5_IRQHandler                     /* 低功耗定时器5全局中断 */
.word LPUART1_IRQHandler                    /* 低功耗UART1中断 */
.word 0                                     /* 保留 */
.word CRS_IRQHandler                        /* 时钟恢复系统全局中断 */
.word ECC_IRQHandler                        /* ECC诊断全局中断 */
.word SAI4_IRQHandler                       /* SAI4全局中断 */
.word 0                                     /* 保留 */
.word 0                                     /* 保留 */
.word WAKEUP_PIN_IRQHandler                 /* 6个唤醒引脚中断 */
.size isr_table, .-isr_table

/* 定义所有中断处理程序的弱符号，并将它们映射到默认处理程序 */
/* 弱符号允许用户在C代码中重定义这些处理程序 */

.weak NMI_Handler
.thumb_set NMI_Handler, default_handler

.weak HardFault_Handler
.thumb_set HardFault_Handler, default_handler

.weak MemManage_Handler
.thumb_set MemManage_Handler, default_handler

.weak BusFault_Handler
.thumb_set BusFault_Handler, default_handler

.weak UsageFault_Handler
.thumb_set UsageFault_Handler, default_handler

.weak SVC_Handler
.thumb_set SVC_Handler, default_handler

.weak DebugMon_Handler
.thumb_set DebugMon_Handler, default_handler

.weak PendSV_Handler
.thumb_set PendSV_Handler, default_handler

.weak SysTick_Handler
.thumb_set SysTick_Handler, default_handler

.weak WWDG_IRQHandler
.thumb_set WWDG_IRQHandler, default_handler

.weak PVD_AVD_IRQHandler
.thumb_set PVD_AVD_IRQHandler, default_handler

.weak TAMP_STAMP_IRQHandler
.thumb_set TAMP_STAMP_IRQHandler, default_handler

.weak RTC_WKUP_IRQHandler
.thumb_set RTC_WKUP_IRQHandler, default_handler

.weak FLASH_IRQHandler
.thumb_set FLASH_IRQHandler, default_handler

.weak RCC_IRQHandler
.thumb_set RCC_IRQHandler, default_handler

.weak EXTI0_IRQHandler
.thumb_set EXTI0_IRQHandler, default_handler

.weak EXTI1_IRQHandler
.thumb_set EXTI1_IRQHandler, default_handler

.weak EXTI2_IRQHandler
.thumb_set EXTI2_IRQHandler, default_handler

.weak EXTI3_IRQHandler
.thumb_set EXTI3_IRQHandler, default_handler

.weak EXTI4_IRQHandler
.thumb_set EXTI4_IRQHandler, default_handler

.weak DMA1_Stream0_IRQHandler
.thumb_set DMA1_Stream0_IRQHandler, default_handler

.weak DMA1_Stream1_IRQHandler
.thumb_set DMA1_Stream1_IRQHandler, default_handler

.weak DMA1_Stream2_IRQHandler
.thumb_set DMA1_Stream2_IRQHandler, default_handler

.weak DMA1_Stream3_IRQHandler
.thumb_set DMA1_Stream3_IRQHandler, default_handler

.weak DMA1_Stream4_IRQHandler
.thumb_set DMA1_Stream4_IRQHandler, default_handler

.weak DMA1_Stream5_IRQHandler
.thumb_set DMA1_Stream5_IRQHandler, default_handler

.weak DMA1_Stream6_IRQHandler
.thumb_set DMA1_Stream6_IRQHandler, default_handler

.weak ADC_IRQHandler
.thumb_set ADC_IRQHandler, default_handler

.weak FDCAN1_IT0_IRQHandler
.thumb_set FDCAN1_IT0_IRQHandler, default_handler

.weak FDCAN2_IT0_IRQHandler
.thumb_set FDCAN2_IT0_IRQHandler, default_handler

.weak FDCAN1_IT1_IRQHandler
.thumb_set FDCAN1_IT1_IRQHandler, default_handler

.weak FDCAN2_IT1_IRQHandler
.thumb_set FDCAN2_IT1_IRQHandler, default_handler

.weak EXTI9_5_IRQHandler
.thumb_set EXTI9_5_IRQHandler, default_handler

.weak TIM1_BRK_IRQHandler
.thumb_set TIM1_BRK_IRQHandler, default_handler

.weak TIM1_UP_IRQHandler
.thumb_set TIM1_UP_IRQHandler, default_handler

.weak TIM1_TRG_COM_IRQHandler
.thumb_set TIM1_TRG_COM_IRQHandler, default_handler

.weak TIM1_CC_IRQHandler
.thumb_set TIM1_CC_IRQHandler, default_handler

.weak TIM2_IRQHandler
.thumb_set TIM2_IRQHandler, default_handler

.weak TIM3_IRQHandler
.thumb_set TIM3_IRQHandler, default_handler

.weak TIM4_IRQHandler
.thumb_set TIM4_IRQHandler, default_handler

.weak I2C1_EV_IRQHandler
.thumb_set I2C1_EV_IRQHandler, default_handler

.weak I2C1_ER_IRQHandler
.thumb_set I2C1_ER_IRQHandler, default_handler

.weak I2C2_EV_IRQHandler
.thumb_set I2C2_EV_IRQHandler, default_handler

.weak I2C2_ER_IRQHandler
.thumb_set I2C2_ER_IRQHandler, default_handler

.weak SPI1_IRQHandler
.thumb_set SPI1_IRQHandler, default_handler

.weak SPI2_IRQHandler
.thumb_set SPI2_IRQHandler, default_handler

.weak USART1_IRQHandler
.thumb_set USART1_IRQHandler, default_handler

.weak USART2_IRQHandler
.thumb_set USART2_IRQHandler, default_handler

.weak USART3_IRQHandler
.thumb_set USART3_IRQHandler, default_handler

.weak EXTI15_10_IRQHandler
.thumb_set EXTI15_10_IRQHandler, default_handler

.weak RTC_Alarm_IRQHandler
.thumb_set RTC_Alarm_IRQHandler, default_handler

.weak TIM8_BRK_TIM12_IRQHandler
.thumb_set TIM8_BRK_TIM12_IRQHandler, default_handler

.weak TIM8_UP_TIM13_IRQHandler
.thumb_set TIM8_UP_TIM13_IRQHandler, default_handler

.weak TIM8_TRG_COM_TIM14_IRQHandler
.thumb_set TIM8_TRG_COM_TIM14_IRQHandler, default_handler

.weak TIM8_CC_IRQHandler
.thumb_set TIM8_CC_IRQHandler, default_handler

.weak DMA1_Stream7_IRQHandler
.thumb_set DMA1_Stream7_IRQHandler, default_handler

.weak FMC_IRQHandler
.thumb_set FMC_IRQHandler, default_handler

.weak SDMMC1_IRQHandler
.thumb_set SDMMC1_IRQHandler, default_handler

.weak TIM5_IRQHandler
.thumb_set TIM5_IRQHandler, default_handler

.weak SPI3_IRQHandler
.thumb_set SPI3_IRQHandler, default_handler

.weak UART4_IRQHandler
.thumb_set UART4_IRQHandler, default_handler

.weak UART5_IRQHandler
.thumb_set UART5_IRQHandler, default_handler

.weak TIM6_DAC_IRQHandler
.thumb_set TIM6_DAC_IRQHandler, default_handler

.weak TIM7_IRQHandler
.thumb_set TIM7_IRQHandler, default_handler

.weak DMA2_Stream0_IRQHandler
.thumb_set DMA2_Stream0_IRQHandler, default_handler

.weak DMA2_Stream1_IRQHandler
.thumb_set DMA2_Stream1_IRQHandler, default_handler

.weak DMA2_Stream2_IRQHandler
.thumb_set DMA2_Stream2_IRQHandler, default_handler

.weak DMA2_Stream3_IRQHandler
.thumb_set DMA2_Stream3_IRQHandler, default_handler

.weak DMA2_Stream4_IRQHandler
.thumb_set DMA2_Stream4_IRQHandler, default_handler

.weak ETH_IRQHandler
.thumb_set ETH_IRQHandler, default_handler

.weak ETH_WKUP_IRQHandler
.thumb_set ETH_WKUP_IRQHandler, default_handler

.weak FDCAN_CAL_IRQHandler
.thumb_set FDCAN_CAL_IRQHandler, default_handler

.weak DMA2_Stream5_IRQHandler
.thumb_set DMA2_Stream5_IRQHandler, default_handler

.weak DMA2_Stream6_IRQHandler
.thumb_set DMA2_Stream6_IRQHandler, default_handler

.weak DMA2_Stream7_IRQHandler
.thumb_set DMA2_Stream7_IRQHandler, default_handler

.weak USART6_IRQHandler
.thumb_set USART6_IRQHandler, default_handler

.weak I2C3_EV_IRQHandler
.thumb_set I2C3_EV_IRQHandler, default_handler

.weak I2C3_ER_IRQHandler
.thumb_set I2C3_ER_IRQHandler, default_handler

.weak OTG_HS_EP1_OUT_IRQHandler
.thumb_set OTG_HS_EP1_OUT_IRQHandler, default_handler

.weak OTG_HS_EP1_IN_IRQHandler
.thumb_set OTG_HS_EP1_IN_IRQHandler, default_handler

.weak OTG_HS_WKUP_IRQHandler
.thumb_set OTG_HS_WKUP_IRQHandler, default_handler

.weak OTG_HS_IRQHandler
.thumb_set OTG_HS_IRQHandler, default_handler

.weak DCMI_IRQHandler
.thumb_set DCMI_IRQHandler, default_handler

.weak RNG_IRQHandler
.thumb_set RNG_IRQHandler, default_handler

.weak FPU_IRQHandler
.thumb_set FPU_IRQHandler, default_handler

.weak UART7_IRQHandler
.thumb_set UART7_IRQHandler, default_handler

.weak UART8_IRQHandler
.thumb_set UART8_IRQHandler, default_handler

.weak SPI4_IRQHandler
.thumb_set SPI4_IRQHandler, default_handler

.weak SPI5_IRQHandler
.thumb_set SPI5_IRQHandler, default_handler

.weak SPI6_IRQHandler
.thumb_set SPI6_IRQHandler, default_handler

.weak SAI1_IRQHandler
.thumb_set SAI1_IRQHandler, default_handler

.weak LTDC_IRQHandler
.thumb_set LTDC_IRQHandler, default_handler

.weak LTDC_ER_IRQHandler
.thumb_set LTDC_ER_IRQHandler, default_handler

.weak DMA2D_IRQHandler
.thumb_set DMA2D_IRQHandler, default_handler

.weak SAI2_IRQHandler
.thumb_set SAI2_IRQHandler, default_handler

.weak QUADSPI_IRQHandler
.thumb_set QUADSPI_IRQHandler, default_handler

.weak LPTIM1_IRQHandler
.thumb_set LPTIM1_IRQHandler, default_handler

.weak CEC_IRQHandler
.thumb_set CEC_IRQHandler, default_handler

.weak I2C4_EV_IRQHandler
.thumb_set I2C4_EV_IRQHandler, default_handler

.weak I2C4_ER_IRQHandler
.thumb_set I2C4_ER_IRQHandler, default_handler

.weak SPDIF_RX_IRQHandler
.thumb_set SPDIF_RX_IRQHandler, default_handler

.weak OTG_FS_EP1_OUT_IRQHandler
.thumb_set OTG_FS_EP1_OUT_IRQHandler, default_handler

.weak OTG_FS_EP1_IN_IRQHandler
.thumb_set OTG_FS_EP1_IN_IRQHandler, default_handler

.weak OTG_FS_WKUP_IRQHandler
.thumb_set OTG_FS_WKUP_IRQHandler, default_handler

.weak OTG_FS_IRQHandler
.thumb_set OTG_FS_IRQHandler, default_handler

.weak DMAMUX1_OVR_IRQHandler
.thumb_set DMAMUX1_OVR_IRQHandler, default_handler

.weak HRTIM1_Master_IRQHandler
.thumb_set HRTIM1_Master_IRQHandler, default_handler

.weak HRTIM1_TIMA_IRQHandler
.thumb_set HRTIM1_TIMA_IRQHandler, default_handler

.weak HRTIM1_TIMB_IRQHandler
.thumb_set HRTIM1_TIMB_IRQHandler, default_handler

.weak HRTIM1_TIMC_IRQHandler
.thumb_set HRTIM1_TIMC_IRQHandler, default_handler

.weak HRTIM1_TIMD_IRQHandler
.thumb_set HRTIM1_TIMD_IRQHandler, default_handler

.weak HRTIM1_TIME_IRQHandler
.thumb_set HRTIM1_TIME_IRQHandler, default_handler

.weak HRTIM1_FLT_IRQHandler
.thumb_set HRTIM1_FLT_IRQHandler, default_handler

.weak DFSDM1_FLT0_IRQHandler
.thumb_set DFSDM1_FLT0_IRQHandler, default_handler

.weak DFSDM1_FLT1_IRQHandler
.thumb_set DFSDM1_FLT1_IRQHandler, default_handler

.weak DFSDM1_FLT2_IRQHandler
.thumb_set DFSDM1_FLT2_IRQHandler, default_handler

.weak DFSDM1_FLT3_IRQHandler
.thumb_set DFSDM1_FLT3_IRQHandler, default_handler

.weak SAI3_IRQHandler
.thumb_set SAI3_IRQHandler, default_handler

.weak SWPMI1_IRQHandler
.thumb_set SWPMI1_IRQHandler, default_handler

.weak TIM15_IRQHandler
.thumb_set TIM15_IRQHandler, default_handler

.weak TIM16_IRQHandler
.thumb_set TIM16_IRQHandler, default_handler

.weak TIM17_IRQHandler
.thumb_set TIM17_IRQHandler, default_handler

.weak MDIOS_WKUP_IRQHandler
.thumb_set MDIOS_WKUP_IRQHandler, default_handler

.weak MDIOS_IRQHandler
.thumb_set MDIOS_IRQHandler, default_handler

.weak JPEG_IRQHandler
.thumb_set JPEG_IRQHandler, default_handler

.weak MDMA_IRQHandler
.thumb_set MDMA_IRQHandler, default_handler

.weak SDMMC2_IRQHandler
.thumb_set SDMMC2_IRQHandler, default_handler

.weak HSEM1_IRQHandler
.thumb_set HSEM1_IRQHandler, default_handler

.weak ADC3_IRQHandler
.thumb_set ADC3_IRQHandler, default_handler

.weak DMAMUX2_OVR_IRQHandler
.thumb_set DMAMUX2_OVR_IRQHandler, default_handler

.weak BDMA_Channel0_IRQHandler
.thumb_set BDMA_Channel0_IRQHandler, default_handler

.weak BDMA_Channel1_IRQHandler
.thumb_set BDMA_Channel1_IRQHandler, default_handler

.weak BDMA_Channel2_IRQHandler
.thumb_set BDMA_Channel2_IRQHandler, default_handler

.weak BDMA_Channel3_IRQHandler
.thumb_set BDMA_Channel3_IRQHandler, default_handler

.weak BDMA_Channel4_IRQHandler
.thumb_set BDMA_Channel4_IRQHandler, default_handler

.weak BDMA_Channel5_IRQHandler
.thumb_set BDMA_Channel5_IRQHandler, default_handler

.weak BDMA_Channel6_IRQHandler
.thumb_set BDMA_Channel6_IRQHandler, default_handler

.weak BDMA_Channel7_IRQHandler
.thumb_set BDMA_Channel7_IRQHandler, default_handler

.weak COMP1_IRQHandler
.thumb_set COMP1_IRQHandler, default_handler

.weak LPTIM2_IRQHandler
.thumb_set LPTIM2_IRQHandler, default_handler

.weak LPTIM3_IRQHandler
.thumb_set LPTIM3_IRQHandler, default_handler

.weak LPTIM4_IRQHandler
.thumb_set LPTIM4_IRQHandler, default_handler

.weak LPTIM5_IRQHandler
.thumb_set LPTIM5_IRQHandler, default_handler

.weak LPUART1_IRQHandler
.thumb_set LPUART1_IRQHandler, default_handler

.weak CRS_IRQHandler
.thumb_set CRS_IRQHandler, default_handler

.weak ECC_IRQHandler
.thumb_set ECC_IRQHandler, default_handler

.weak SAI4_IRQHandler
.thumb_set SAI4_IRQHandler, default_handler

.weak WAKEUP_PIN_IRQHandler
.thumb_set WAKEUP_PIN_IRQHandler, default_handler