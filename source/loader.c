#include "loader.h"
#include "gpio.h"
#include "printf.h"
#include "string.h"
#include <rtthread.h>

// 测试程序：不调用任何函数，只做地址或者寄存器操作，避免程序触发hardfault
RETAIN void test_task(void *parameter)
{
    rt_kprintf("test task start\n");
    while (1)
    {
        LL_GPIO_TogglePin(LED_GREEN_GPIO_Port, LED_GREEN_Pin);  
        rt_thread_mdelay(500);
    }
}

void rt_application_init(void)
{
#ifdef RT_USING_COMPONENTS_INIT
    /* RT-Thread components initialization */
    rt_components_init();
#endif /* RT_USING_COMPONENTS_INIT */

    rt_thread_t tid = rt_thread_create("test", test_task, RT_NULL, 512, 1, 0);
    RT_ASSERT(tid != RT_NULL);

    rt_thread_startup(tid);
}

// 引导程序入口
void loader_entry(void)
{
    uint8_t result = 0;

    // STM32CubeMX初始化
    main();
    printf("init finish\n");

    // 读取配置信息
    config_t _config;
    result = loader_read_config(&_config);
    if (0 != result)
    {
        printf("config read fail\n");
        while (1)
        {
            LL_GPIO_TogglePin(LED_RED_GPIO_Port, LED_RED_Pin);
            HAL_Delay(500);
        }
    }
    printf("config read success\n");
    _config.boot_mode = (_config.boot_mode + 1) % 3;

    // 擦除配置信息
    result = loader_erase_config();
    if (0 != result)
    {
        printf("config erase fail\n");
        while (1)
        {
            LL_GPIO_TogglePin(LED_RED_GPIO_Port, LED_RED_Pin);
            HAL_Delay(500);
        }
    }
    printf("config erase success\n");

    // 写入新配置信息
    result = loader_write_config(&_config);
    if (0 != result)
    {
        printf("config write fail\n");
        while (1)
        {
            LL_GPIO_TogglePin(LED_RED_GPIO_Port, LED_RED_Pin);
            HAL_Delay(500);
        }
    }
    printf("config write success\n");
    printf("config test finish\n");

    // 擦除app_a
    result = loader_erase_app_sector(0, 0);
    if (0 != result)
    {
        printf("app_a erase fail\n");
        while (1)
        {
            LL_GPIO_TogglePin(LED_RED_GPIO_Port, LED_RED_Pin);
            HAL_Delay(500);
        }
    }
    printf("app_a erase success\n");

    // 擦除app_b
    result = loader_erase_app_sector(1, 0);
    if (0 != result)
    {
        printf("app_b erase fail\n");
        while (1)
        {
            LL_GPIO_TogglePin(LED_RED_GPIO_Port, LED_RED_Pin);
            HAL_Delay(500);
        }
    }
    printf("app_b erase success\n");

    // 写入app_a
    result = loader_write_app(0, (uint32_t *)&_retain_flash_addr, (uint32_t)&_retain_flash_end - (uint32_t)&_retain_flash_addr);
    if (0 != result)
    {
        printf("app_a write fail\n");
        while (1)
        {
            LL_GPIO_TogglePin(LED_RED_GPIO_Port, LED_RED_Pin);
            HAL_Delay(500);
        }
    }
    printf("app_a write success\n");

    // 写入app_b
    result = loader_write_app(1, (uint32_t *)&_retain_flash_addr, (uint32_t)&_retain_flash_end - (uint32_t)&_retain_flash_addr);
    if (0 != result)
    {
        printf("app_b write fail\n");
        while (1)
        {
            LL_GPIO_TogglePin(LED_RED_GPIO_Port, LED_RED_Pin);
            HAL_Delay(500);
        }
    }
    printf("app_b write success\n");

    // 循环跳转至app_a和app_b
    while (1)
    {
        printf("jump to test_app(0x%p)\n", FLASH_USER_ADDR);
        jump_to_app(FLASH_USER_ADDR);
        HAL_Delay(3000);
        printf("jump to test_app(0x%p)\n", FLASH_OEM_ADDR);
        jump_to_app(FLASH_OEM_ADDR);
        HAL_Delay(3000);
    }
}

ITCM uint8_t loader_read_config(config_t *config)
{
    if (NULL == config)
    {
        return 1;
    }
    memcpy((void *)config, (void *)&flash_config_addr, sizeof(config_t));
    return 0;
}

ITCM uint8_t loader_erase_config(void)
{
    // 在擦写前关闭全局中断
    __disable_irq();

    // 解锁Flash控制寄存器
    uint8_t result = HAL_FLASH_Unlock();
    if (0 != result)
    {
        goto exit;
    }

    FLASH_EraseInitTypeDef EraseInitStruct = {
        .TypeErase = FLASH_TYPEERASE_SECTORS,
        .Banks = (FLASH_BANK2_ADDR > FLASH_CONFIG_ADDR) ? FLASH_BANK_1 : FLASH_BANK_2,
        .Sector = (FLASH_CONFIG_ADDR - ((FLASH_BANK2_ADDR > FLASH_CONFIG_ADDR) ? FLASH_BANK1_ADDR : FLASH_BANK2_ADDR)) / FLASH_SECTOR_SIZE,
        .NbSectors = 1,
        .VoltageRange = FLASH_VOLTAGE_RANGE_3,
    };

    // 清除ECC标志
    __HAL_FLASH_CLEAR_FLAG_BANK1((FLASH_BANK2_ADDR > FLASH_CONFIG_ADDR) ? FLASH_FLAG_ALL_ERRORS_BANK1 : FLASH_FLAG_ALL_ERRORS_BANK2);

    // 执行擦除
    uint32_t SectorError;
    result = HAL_FLASHEx_Erase(&EraseInitStruct, &SectorError);
    if (0 != result)
    {
        goto exit;
    }

exit:
    // 上锁Flash控制寄存器
    HAL_FLASH_Lock();

    // 使能全局中断
    __enable_irq();

    return result;
}

ITCM uint8_t loader_erase_app_all(uint8_t app)
{
    if (app > 1)
    {
        return 1;
    }

    // 在擦写前关闭全局中断
    __disable_irq();

    // 解锁Flash控制寄存器
    uint8_t result = HAL_FLASH_Unlock();
    if (0 != result)
    {
        goto exit;
    }

    const uint32_t addr = (0 == app) ? FLASH_USER_ADDR : FLASH_OEM_ADDR;

    FLASH_EraseInitTypeDef EraseInitStruct = {
        .TypeErase = FLASH_TYPEERASE_SECTORS,
        .Banks = (FLASH_BANK2_ADDR > addr) ? FLASH_BANK_1 : FLASH_BANK_2,
        .Sector = (addr - ((FLASH_BANK2_ADDR > addr) ? FLASH_BANK1_ADDR : FLASH_BANK2_ADDR)) / FLASH_SECTOR_SIZE,
        .NbSectors = 5,
        .VoltageRange = FLASH_VOLTAGE_RANGE_3,
    };

    // 清除ECC标志
    __HAL_FLASH_CLEAR_FLAG_BANK1((FLASH_BANK2_ADDR > addr) ? FLASH_FLAG_ALL_ERRORS_BANK1 : FLASH_FLAG_ALL_ERRORS_BANK2);

    // 执行擦除
    uint32_t SectorError;
    result = HAL_FLASHEx_Erase(&EraseInitStruct, &SectorError);
    if (0 != result)
    {
        goto exit;
    }

exit:
    // 上锁Flash控制寄存器
    HAL_FLASH_Lock();

    // 使能全局中断
    __enable_irq();

    return result;
}

ITCM uint8_t loader_erase_app_sector(uint8_t app, uint8_t sector)
{
    if (app > 1 || sector > 4)
    {
        return 1;
    }

    // 在擦写前关闭全局中断
    __disable_irq();

    // 解锁Flash控制寄存器
    uint8_t result = HAL_FLASH_Unlock();
    if (0 != result)
    {
        goto exit;
    }

    const uint32_t addr = (0 == app) ? FLASH_USER_ADDR : FLASH_OEM_ADDR;

    FLASH_EraseInitTypeDef EraseInitStruct = {
        .TypeErase = FLASH_TYPEERASE_SECTORS,
        .Banks = (FLASH_BANK2_ADDR > addr) ? FLASH_BANK_1 : FLASH_BANK_2,
        .Sector = (addr - ((FLASH_BANK2_ADDR > addr) ? FLASH_BANK1_ADDR : FLASH_BANK2_ADDR)) / FLASH_SECTOR_SIZE + sector,
        .NbSectors = 1,
        .VoltageRange = FLASH_VOLTAGE_RANGE_3,
    };

    // 清除ECC标志
    __HAL_FLASH_CLEAR_FLAG_BANK1((FLASH_BANK2_ADDR > addr) ? FLASH_FLAG_ALL_ERRORS_BANK1 : FLASH_FLAG_ALL_ERRORS_BANK2);

    // 执行擦除
    uint32_t SectorError;
    result = HAL_FLASHEx_Erase(&EraseInitStruct, &SectorError);
    if (0 != result)
    {
        goto exit;
    }

exit:
    // 上锁Flash控制寄存器
    HAL_FLASH_Lock();

    // 使能全局中断
    __enable_irq();

    return result;
}

ITCM uint8_t loader_write_config(const config_t *config)
{
    // 在擦写前关闭全局中断
    __disable_irq();

    // 解锁Flash控制寄存器
    uint8_t result = HAL_FLASH_Unlock();
    if (0 != result)
    {
        goto exit;
    }

    const uint32_t addr = (uint32_t)&flash_config_addr;

    result = HAL_FLASH_Program(FLASH_TYPEPROGRAM_FLASHWORD, addr, (uint32_t)config);
    if (0 != result)
    {
        goto exit;
    }

exit:
    // 上锁Flash控制寄存器
    HAL_FLASH_Lock();

    // 使能全局中断
    __enable_irq();

    return result;
}

ITCM uint8_t loader_write_app(uint8_t app, const uint32_t *data, uint32_t size)
{
    if (app > 1 || NULL == data || !IS_ALIGN_4_BYTES(data) || 0 == size)
    {
        printf("\tapp=%u, data=0x%p, size=%u\n", app, data, size);
        return 1;
    }

    // 在擦写前关闭全局中断
    __disable_irq();

    // 解锁Flash控制寄存器
    uint8_t result = HAL_FLASH_Unlock();
    if (0 != result)
    {
        goto exit;
    }

    const uint32_t addr = (0 == app) ? FLASH_USER_ADDR : FLASH_OEM_ADDR;

    // 每次步进32字节
    for (uint32_t i = 0; i < size; i += 32)
    {
        // 计算当前写入的目标地址
        uint32_t current_addr = addr + i;

        // 计算当前源数据的地址
        // 注意：buffer是指针，buffer+8意味着地址向后移动8*4=32字节
        uint32_t current_data_ptr = (uint32_t)(data + (i / 4));

        result = HAL_FLASH_Program(FLASH_TYPEPROGRAM_FLASHWORD, current_addr, current_data_ptr);
        if (0 != result)
        {
            goto exit;
        }
    }

exit:
    // 上锁Flash控制寄存器
    HAL_FLASH_Lock();

    // 使能全局中断
    __enable_irq();

    return result;
}

uint8_t jump_to_app(uint32_t addr)
{
    if ((addr & 1) == 0)
    {
        addr |= 1;
    }
    void (*fn)(void) = (void (*)(void))addr;
    fn();

    return 1;
}