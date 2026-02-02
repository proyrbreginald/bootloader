#include "loader.h"
#include "gpio.h"
#include "string.h"
#include "printf.h"

extern const uint32_t memory_bank1_addr;
extern const uint32_t memory_bank2_addr;
extern const uint32_t memory_loader_addr;
extern const uint32_t memory_config_addr;
extern const uint32_t memory_patch_addr;
extern const uint32_t memory_app_a_addr;
extern const uint32_t memory_app_b_addr;

void loader(void)
{
    // STM32CubeMX初始化
    main();

    // 读取配置信息
    config_t _config;
    memcpy((void *)&_config, (void *)&memory_config_addr, sizeof(config_t));
    _config.boot_mode = (_config.boot_mode + 1) % 3;

    uint8_t result = config_erase();
    if (0 != result)
    {
        while (1)
        {
            HAL_GPIO_TogglePin(LED_RED_GPIO_Port, LED_RED_Pin);
            HAL_Delay(100);
        }
    }

    result = config_write(&_config);
    if (0 != result)
    {
        while (1)
        {
            HAL_GPIO_TogglePin(LED_RED_GPIO_Port, LED_RED_Pin);
            HAL_Delay(500);
        }
    }

    while (1)
    {
        switch (_config.boot_mode)
        {
        case 0:
            printf("case 0\r\n");
            break;
            
        case 1:
            printf("case 1\r\n");
            break;
            
        case 2:
            printf("case 2\r\n");
            break;
        
        default:
            printf("default\r\n");
            break;
        }
        HAL_Delay(1000);
    }
}

ITCM uint8_t config_erase(void)
{
    // 在擦写前关闭全局中断
    __disable_irq();

    // 解锁Flash控制寄存器
    uint8_t result = HAL_FLASH_Unlock();
    if (0 != result)
    {
        goto exit;
    }

    const uint32_t bank1 = (uint32_t)&memory_bank1_addr;
    const uint32_t bank2 = (uint32_t)&memory_bank2_addr;
    const uint32_t addr = (uint32_t)&memory_config_addr;

    FLASH_EraseInitTypeDef EraseInitStruct = {
        .TypeErase = FLASH_TYPEERASE_SECTORS,
        .Banks = (bank2 > addr) ? FLASH_BANK_1 : FLASH_BANK_2,
        .Sector = ((addr - ((bank2 > addr) ? bank1 : bank2)) / (128u * 1024u)),
        .NbSectors = 1,
        .VoltageRange = FLASH_VOLTAGE_RANGE_3,
    };

    // 清除ECC标志
    __HAL_FLASH_CLEAR_FLAG_BANK1((bank2 > addr) ? FLASH_FLAG_ALL_ERRORS_BANK1 : FLASH_FLAG_ALL_ERRORS_BANK2);

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

ITCM uint8_t config_write(const config_t *config)
{
    // 在擦写前关闭全局中断
    __disable_irq();

    // 解锁Flash控制寄存器
    uint8_t result = HAL_FLASH_Unlock();
    if (0 != result)
    {
        goto exit;
    }

    const uint32_t addr = (uint32_t)&memory_config_addr;

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

/* 跳转到应用程序 */
uint8_t jump_to_app(const uint32_t addr)
{
    // 设置新的MSP值
    __set_MSP(*(volatile uint32_t *)addr);

    // 获取复位向量地址（应用程序入口点）
    const uint32_t reset_handler_addr = *(volatile uint32_t *)(addr + 4);

    // 设置向量表偏移
    SCB->VTOR = addr;

    // 禁用中断
    __disable_irq();

    // 调用函数指针
    uint8_t result = ((uint8_t (*)(void))reset_handler_addr)();

    return result;
}