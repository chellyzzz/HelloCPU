/*
 *  am.h — Minimal Abstract Machine shim for NJU-ProjectN cpu-tests
 *
 *  The original <am.h> is part of https://github.com/NJU-ProjectN/abstract-machine
 *  and provides _ioe_init(), halt(), printf(), etc.
 *
 *  This shim provides the tiny subset needed to compile the 34 cpu-tests:
 *    - halt(int code)       → write exit code to MMIO (simulation stop)
 *    - _ioe_init()          → no-op (no I/O devices on bare-metal CPU)
 *    - printf(fmt, ...)     → forwarded to our klib snprintf + putchar
 */

#ifndef __AM_H__
#define __AM_H__

#include <stdarg.h>
#include "klib.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ---------------------------------------------------------------
 * _ioe_init() — initialize I/O extension (UART, timer, …)
 *
 * On the bare-metal HelloCPU we have no I/O controller;
 * UART is directly memory-mapped and the simulation layer
 * handles MMIO (0x10000000 / 0x10000004).
 * --------------------------------------------------------------- */
static inline void _ioe_init(void) {
    /* nothing to initialise */
}

/* ---------------------------------------------------------------
 * halt(code) — stop simulation
 *
 * Writes the exit code to the simulation-control MMIO at
 * 0x10000004.  sim_main.cpp polls this address and exits the
 * testbench once it becomes non‑zero.
 *
 *   code = 0  → PASS
 *   code ≠ 0  → FAIL
 * --------------------------------------------------------------- */
static inline void halt(int code) {
    volatile unsigned int *ctrl = (volatile unsigned int *)0x10000004;
    *ctrl = (unsigned int)code;
    /* busy-wait so the Verilator thread can observe the write */
    while (1) __asm__ volatile("" ::: "memory");
}

/* ---------------------------------------------------------------
 * printf(fmt, …) — formatted output over UART
 *
 * Some cpu-tests (e.g. hello-str.c) call printf().
 * We buffer the formatted output (1 KiB is enough for the
 * simple messages the tests produce) and then push every
 * character through putchar().
 * --------------------------------------------------------------- */
static inline int printf(const char *fmt, ...) {
    char buf[1024];
    va_list ap;
    int ret;

    va_start(ap, fmt);
    ret = vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);

    for (const char *p = buf; *p; p++) putchar(*p);
    return ret;
}

#ifdef __cplusplus
}
#endif

#endif /* __AM_H__ */