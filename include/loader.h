#ifndef LOADER_H
#define LOADER_H

#include "stm32h7xx_hal.h"
#include "semver.h"
#include <stdbool.h>

// 函数属性：将代码放在ITCM区域中，从RAM中零等待取指令
#define ITCM __attribute__((section(".itcm"), noinline))

// 函数属性：保留代码
#define RETAIN __attribute__((section(".retain"), noinline))

/* loader信息 */
typedef struct
{
    volatile semver_t version; // 程序语义化版本
} loader_info_t;

/* app信息 */
typedef struct
{
    volatile semver_t version; // 程序语义化版本
} app_info_t;

/* 配置信息 */
typedef struct
{
    volatile uint8_t boot_mode;     // 启动模式：0=正常启动，1=强制app_a，2=强制app_b
    volatile loader_info_t loader;  // 引导程序信息
    volatile app_info_t user;       // app_a信息
    volatile app_info_t oem;        // app_b信息
    volatile uint8_t invalid[22];   // 32字节对齐
} config_t;
_Static_assert(0 == (sizeof(config_t) & 31), "size must be a multiple of 32 bytes"); // 静态检查：32字节对齐

// 链接脚本符号
extern const uint8_t flash_sector_size;
#ifndef FLASH_SECTOR_SIZE
#define FLASH_SECTOR_SIZE ((uint32_t)&flash_sector_size)
#endif // FLASH_SECTOR_SIZE
extern const uint8_t flash_bank1_addr;
#ifndef FLASH_BANK1_ADDR
#define FLASH_BANK1_ADDR ((uint32_t)&flash_bank1_addr)
#endif // FLASH_BANK1_ADDR
extern const uint8_t flash_loader_addr;
#ifndef FLASH_LOADER_ADDR
#define FLASH_LOADER_ADDR ((uint32_t)&flash_loader_addr)
#endif // FLASH_LOADER_ADDR
extern const uint8_t flash_config_addr;
#ifndef FLASH_CONFIG_ADDR
#define FLASH_CONFIG_ADDR ((uint32_t)&flash_config_addr)
#endif // FLASH_CONFIG_ADDR
extern const uint8_t flash_user_addr;
#ifndef FLASH_USER_ADDR
#define FLASH_USER_ADDR ((uint32_t)&flash_user_addr)
#endif // FLASH_USER_ADDR
extern const uint8_t flash_bank2_addr;
#ifndef FLASH_BANK2_ADDR
#define FLASH_BANK2_ADDR ((uint32_t)&flash_bank2_addr)
#endif // FLASH_BANK2_ADDR
extern const uint8_t flash_patch_addr;
#ifndef FLASH_PATCH_ADDR
#define FLASH_PATCH_ADDR ((uint32_t)&flash_patch_addr)
#endif // FLASH_PATCH_ADDR
extern const uint8_t flash_oem_addr;
#ifndef FLASH_OEM_ADDR
#define FLASH_OEM_ADDR ((uint32_t)&flash_oem_addr)
#endif // FLASH_OEM_ADDR

// 保留段起始地址
extern const uint8_t _retain_flash_addr;

// 保留段结束地址
extern const uint8_t _retain_flash_end;

// 栈底起始地址
extern const uint8_t stack_addr;

// 栈最小大小
extern const uint8_t stack_size_min;

// 堆起始地址
extern const uint8_t heap_addr;

// 堆结束地址
extern const uint8_t heap_end;

// 判断是否4字节对齐
#define IS_ALIGN_4_BYTES(addr) (((uint32_t)(addr) & 0x03) == 0)

// 判断是否32字节对齐
#define IS_ALIGN_32_BYTES(addr) (((uint32_t)(addr) & 0x1F) == 0)

/* 引导程序 */
void loader_entry(void);

/* 读取配置信息 */
uint8_t loader_read_config(config_t *config);

/* 擦除配置信息 */
uint8_t loader_erase_config(void);

/* 擦除所选应用的所有扇区 */
uint8_t loader_erase_app_all(uint8_t app);

/* 擦除所选应用的所选扇区 */
uint8_t loader_erase_app_sector(uint8_t app, uint8_t sector);

/* 写入配置信息 */
uint8_t loader_write_config(const config_t *config);

/* 写入所选应用 */
uint8_t loader_write_app(uint8_t app, const uint32_t *data, uint32_t size);

/* 跳转到应用程序 */
uint8_t jump_to_app(uint32_t addr);

#endif // LOADER_H