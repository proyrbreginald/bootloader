#ifndef LOADER_H
#define LOADER_H

#include "semver.h"
#include <stdbool.h>

// 函数属性：将代码放在ITCM区域中，从RAM中零等待取指令
#define ITCM __attribute__((section(".itcm"), noinline))

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
    volatile uint8_t boot_mode;    // 启动模式：0=正常启动，1=强制app_a，2=强制app_b
    volatile loader_info_t loader; // 引导程序信息
    volatile app_info_t app_a;     // app_a信息
    volatile app_info_t app_b;     // app_b信息
    volatile uint8_t invalid[22];  // 32字节对齐
} config_t;

// 静态检查：32字节对齐
_Static_assert(0 == (sizeof(config_t) & 31), "size must be a multiple of 32 bytes");

/* 引导程序 */
void loader(void);

/* 读取配置信息 */
uint8_t config_read(config_t *config);

/* 擦除配置信息 */
uint8_t config_erase(void);

/* 写入配置信息 */
uint8_t config_write(const config_t *config);

/* 修改flash数据 */
uint8_t flash_modify(uint32_t addr, uint32_t *data, uint32_t size);

/* 跳转到应用程序 */
uint8_t jump_to_app(const uint32_t addr);

#endif // LOADER_H