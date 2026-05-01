/*
 *  trap.h — Compatibility layer for NJU-ProjectN cpu-tests
 *
 *  The original trap.h includes <am.h>, <klib.h>, <klib-macros.h>
 *  and defines a check() macro.
 *
 *  This version maps halt() to our simulation-shutdown MMIO
 *  and pulls in the mini libc (klib.h).
 */
#ifndef __TRAP_H__
#define __TRAP_H__

#include "am.h"
#include "klib.h"
#include "klib-macros.h"

/* check(cond) — if cond is false, halt with exit code 1 */
static inline void check(int cond) {
    if (!cond) halt(1);
}

#endif /* __TRAP_H__ */