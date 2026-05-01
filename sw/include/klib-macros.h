/*
 *  klib-macros.h — Compatibility macros for NJU-ProjectN cpu-tests
 *
 *  The original header is part of https://github.com/NJU-ProjectN/abstract-machine
 *  and provides convenience macros like LENGTH() and the bool type alias.
 *
 *  This shim provides the subset needed by the 34 cpu-tests:
 *    - LENGTH(arr) → number of elements in a static array
 *    - bool / true / false
 */

#ifndef __KLIB_MACROS_H__
#define __KLIB_MACROS_H__

/* number of elements in a static array */
#define LENGTH(arr)   (sizeof(arr) / sizeof((arr)[0]))

/* minimalist boolean type (matches original AM klib-macros.h)
 *
 * When <stdbool.h> is included (e.g. via klib.h), bool/true/false
 * are already defined through macros.  The fallback below is only
 * used when compiling the original AM test sources directly, without
 * a full libc.
 */
#ifndef __cplusplus
#ifndef bool
typedef int bool;
#endif
#ifndef true
#define true   1
#endif
#ifndef false
#define false  0
#endif
#endif

#endif /* __KLIB_MACROS_H__ */