/*
 *  klib-macros.h — Compatibility macros for NJU-ProjectN cpu-tests
 *
 *  The original header is part of https://github.com/NJU-ProjectN/abstract-machine
 *  and provides convenience macros like LENGTH() and the bool type alias.
 *
 *  This shim provides the subset needed by the 34 cpu-tests:
 *    - LENGTH(arr) → number of elements in a static array
 *    - bool / true / false via <stdbool.h>
 */

#ifndef __KLIB_MACROS_H__
#define __KLIB_MACROS_H__

#include <stdbool.h>

/* number of elements in a static array */
#define LENGTH(arr)   (sizeof(arr) / sizeof((arr)[0]))

#endif /* __KLIB_MACROS_H__ */
