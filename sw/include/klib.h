#ifndef __KLIB_H__
#define __KLIB_H__

#include <stddef.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* memory operations */
void *memset(void *s, int c, size_t n);
void *memcpy(void *dest, const void *src, size_t n);
int   memcmp(const void *s1, const void *s2, size_t n);

/* string operations */
size_t strlen(const char *s);
int    strcmp(const char *s1, const char *s2);
char  *strcpy(char *dest, const char *src);
char  *strcat(char *dest, const char *src);
char  *strncpy(char *dest, const char *src, size_t n);

/* formatted output */
int vsnprintf(char *buf, size_t size, const char *fmt, va_list ap);
int snprintf(char *buf, size_t size, const char *fmt, ...);
int sprintf(char *buf, const char *fmt, ...);

/* putchar — writes one byte to UART (address 0x10000000) */
void putchar(char c);

/* puts — writes a string + newline to UART */
int puts(const char *s);

#ifdef __cplusplus
}
#endif

#endif /* __KLIB_H__ */