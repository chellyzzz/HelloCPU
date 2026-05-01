#ifndef __ZXTEST_H__
#define __ZXTEST_H__

#include <stdint.h>

// UART output (DPI-C simulated)
#define SERIAL_PORT (*(volatile char *)0x10000000)
#define HALT_REG    (*(volatile int *)0x10000004)

static inline void putch(char c) { SERIAL_PORT = c; }

static inline void puts_(const char *s) {
    while (*s) putch(*s++);
}

static inline void halt(int code) { HALT_REG = code; while(1); }

// Simple hex print
static inline void print_hex(uint32_t val) {
    const char hex[] = "0123456789abcdef";
    puts_("0x");
    for (int i = 28; i >= 0; i -= 4)
        putch(hex[(val >> i) & 0xf]);
}

// Test macros
#define check(cond, errno) do { if (!(cond)) halt(errno); } while(0)
#define pass() halt(0)
#define fail(errno) halt(errno)

// Read mcycle CSR for timing
static inline uint32_t get_cycles() {
    uint32_t val;
    asm volatile("csrr %0, mcycle" : "=r"(val));
    return val;
}

#endif
