/*
 *  klib.c — bare-metal mini libc for RISC‑V CPU verification
 *
 *  All functions are self‑contained; no external headers except klib.h
 *  and compiler built‑ins (__builtin_va_*).
 */
#include <stdint.h>
#include "klib.h"

/* ================================================================== */
/*  Memory helpers                                                     */
/* ================================================================== */

void *memset(void *s, int c, size_t n)
{
    unsigned char *p = (unsigned char *)s;
    while (n--) *p++ = (unsigned char)c;
    return s;
}

void *memcpy(void *dest, const void *src, size_t n)
{
    unsigned char       *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) *d++ = *s++;
    return dest;
}

int memcmp(const void *s1, const void *s2, size_t n)
{
    const unsigned char *a = (const unsigned char *)s1;
    const unsigned char *b = (const unsigned char *)s2;
    while (n--) {
        if (*a != *b)
            return (int)*a - (int)*b;
        a++; b++;
    }
    return 0;
}

/* ================================================================== */
/*  String helpers                                                     */
/* ================================================================== */

size_t strlen(const char *s)
{
    size_t n = 0;
    while (*s++) n++;
    return n;
}

int strcmp(const char *s1, const char *s2)
{
    while (*s1 && *s1 == *s2) {
        s1++; s2++;
    }
    return (unsigned char)*s1 - (unsigned char)*s2;
}

char *strcpy(char *dest, const char *src)
{
    char *d = dest;
    while ((*d++ = *src++) != '\0');
    return dest;
}

char *strcat(char *dest, const char *src)
{
    char *d = dest;
    while (*d) d++;
    while ((*d++ = *src++) != '\0');
    return dest;
}

char *strncpy(char *dest, const char *src, size_t n)
{
    size_t i;
    for (i = 0; i < n && src[i] != '\0'; i++)
        dest[i] = src[i];
    for ( ; i < n; i++)
        dest[i] = '\0';
    return dest;
}

/* ================================================================== */
/*  UART output                                                        */
/* ================================================================== */

/* UART TX register — matches sim_main.cpp MMIO at 0x10000000 */
#define UART_TX  (*(volatile unsigned char *)0x10000000)

void putchar(char c)
{
    UART_TX = (unsigned char)c;
}

int puts(const char *s)
{
    while (*s) putchar(*s++);
    putchar('\n');
    return 0;
}

/* ================================================================== */
/*  Mini printf engine                                                 */
/* ================================================================== */

static void print_hex(char **pbuf, size_t *pleft, unsigned int val,
                      int width, char pad)
{
    char tmp[12];
    int  i = 0, j;
    if (val == 0) {
        tmp[i++] = '0';
    } else {
        while (val) {
            int d = val & 0xf;
            tmp[i++] = (d < 10) ? ('0' + d) : ('a' + d - 10);
            val >>= 4;
        }
    }
    /* padding */
    while (i < width && *pleft > 1) {
        *(*pbuf)++ = pad;
        (*pleft)--;
        width--;
    }
    /* digits in reverse */
    for (j = i - 1; j >= 0 && *pleft > 1; j--) {
        *(*pbuf)++ = tmp[j];
        (*pleft)--;
    }
}

static void print_dec(char **pbuf, size_t *pleft, unsigned int val,
                      int width, char pad)
{
    char tmp[12];
    int  i = 0, j;
    if (val == 0) {
        tmp[i++] = '0';
    } else {
        /* avoid division/modulo which pulls in __udivsi3/__umodsi3 */
        unsigned int v = val;
        while (v) {
            /* subtract 10 at a time to get the next digit */
            unsigned int q = 0;
            unsigned int rem = 0;
            while (v >= 10) {
                v -= 10;
                q++;
            }
            rem = v;
            v = q;
            tmp[i++] = '0' + rem;
        }
    }
    while (i < width && *pleft > 1) {
        *(*pbuf)++ = pad;
        (*pleft)--;
        width--;
    }
    for (j = i - 1; j >= 0 && *pleft > 1; j--) {
        *(*pbuf)++ = tmp[j];
        (*pleft)--;
    }
}

int vsnprintf(char *buf, size_t size, const char *fmt, va_list ap)
{
    char *p = buf;
    size_t left = size ? size - 1 : 0;
    int written = 0;

    if (size == 0) return 0;

    while (*fmt && left > 0) {
        if (*fmt != '%') {
            *p++ = *fmt++;
            left--;
            written++;
            continue;
        }
        fmt++; /* skip '%' */

        /* flags */
        char pad = ' ';
        int  width = 0;

        if (*fmt == '0') { pad = '0'; fmt++; }

        while (*fmt >= '0' && *fmt <= '9') {
            width = width * 10 + (*fmt - '0');
            fmt++;
        }

        switch (*fmt) {

        case 's': {
            const char *s = va_arg(ap, const char *);
            if (!s) s = "(null)";
            while (*s && left > 0) {
                *p++ = *s++;
                left--;
                written++;
            }
            break;
        }

        case 'c': {
            char c = (char)va_arg(ap, int);
            if (left > 0) {
                *p++ = c;
                left--;
                written++;
            }
            break;
        }

        case 'd': {
            int val = va_arg(ap, int);
            unsigned int uval;
            if (val < 0) {
                if (left > 0) {
                    *p++ = '-';
                    left--;
                    written++;
                }
                uval = (unsigned int)-val;
            } else {
                uval = (unsigned int)val;
            }
            print_dec(&p, &left, uval, width, pad);
            break;
        }

        case 'u': {
            unsigned int val = va_arg(ap, unsigned int);
            print_dec(&p, &left, val, width, pad);
            break;
        }

        case 'x': {
            unsigned int val = va_arg(ap, unsigned int);
            print_hex(&p, &left, val, width, pad);
            break;
        }

        case 'p': {
            if (left > 0) {
                *p++ = '0';
                left--;
                written++;
            }
            if (left > 0) {
                *p++ = 'x';
                left--;
                written++;
            }
            print_hex(&p, &left,
                      (unsigned int)(uintptr_t)va_arg(ap, void *), 0, '0');
            break;
        }

        case '%': {
            if (left > 0) {
                *p++ = '%';
                left--;
                written++;
            }
            break;
        }

        default: break;
        }
        if (*fmt) fmt++;
    }

    *p = '\0';
    /* count remaining va_arg-consumed but not emitted */
    /* (we don't have an easy way to count them, but test
     *  programs only rely on the emitted characters) */
    return written;
}

int snprintf(char *buf, size_t size, const char *fmt, ...)
{
    va_list ap;
    int ret;
    va_start(ap, fmt);
    ret = vsnprintf(buf, size, fmt, ap);
    va_end(ap);
    return ret;
}

int sprintf(char *buf, const char *fmt, ...)
{
    va_list ap;
    int ret;
    va_start(ap, fmt);
    ret = vsnprintf(buf, 0x7fffffff, fmt, ap);
    va_end(ap);
    return ret;
}

/* ================================================================== */
/*  64‑bit integer helpers (libgcc replacements for rv32)              */
/*  The toolchain only provides elf64‑littleriscv libgcc, which is     */
/*  incompatible with our -mabi=ilp32 output.  These minimal stubs      */
/*  cover the symbols generated by GCC for long long operations.       */
/* ================================================================== */
typedef          long long int64_t;
typedef unsigned long long uint64_t;

int64_t __divdi3(int64_t a, int64_t b)
{
    int neg = 0;
    if (a < 0) { a = -a; neg = !neg; }
    if (b < 0) { b = -b; neg = !neg; }

    uint64_t q = 0;
    uint64_t r = 0;
    uint64_t ua = (uint64_t)a;
    uint64_t ub = (uint64_t)b;

    for (int i = 63; i >= 0; i--) {
        r = (r << 1) | ((ua >> i) & 1);
        if (r >= ub) {
            r -= ub;
            q |= (uint64_t)1 << i;
        }
    }
    return neg ? -(int64_t)q : (int64_t)q;
}

int64_t __moddi3(int64_t a, int64_t b)
{
    int neg = (a < 0);
    if (neg) a = -a;
    if (b < 0) b = -b;

    uint64_t r = 0;
    uint64_t ua = (uint64_t)a;
    uint64_t ub = (uint64_t)b;

    for (int i = 63; i >= 0; i--) {
        r = (r << 1) | ((ua >> i) & 1);
        if (r >= ub)
            r -= ub;
    }
    return neg ? -(int64_t)r : (int64_t)r;
}

uint64_t __udivdi3(uint64_t a, uint64_t b)
{
    uint64_t q = 0;
    uint64_t r = 0;

    for (int i = 63; i >= 0; i--) {
        r = (r << 1) | ((a >> i) & 1);
        if (r >= b) {
            r -= b;
            q |= (uint64_t)1 << i;
        }
    }
    return q;
}

uint64_t __umoddi3(uint64_t a, uint64_t b)
{
    uint64_t r = 0;

    for (int i = 63; i >= 0; i--) {
        r = (r << 1) | ((a >> i) & 1);
        if (r >= b)
            r -= b;
    }
    return r;
}

int64_t __muldi3(int64_t a, int64_t b)
{
    int neg = 0;
    if (a < 0) { a = -a; neg = !neg; }
    if (b < 0) { b = -b; neg = !neg; }

    uint64_t res = 0;
    while (b) {
        if (b & 1)
            res += (uint64_t)a;
        a <<= 1;
        b >>= 1;
    }
    return neg ? -(int64_t)res : (int64_t)res;
}
