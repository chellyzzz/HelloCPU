/*
 * hcpu CoreMark port — core_portme.h
 * RV32IM bare-metal, no FPU, mcycle timer, UART at 0x10000000
 */
#ifndef CORE_PORTME_H
#define CORE_PORTME_H

/* ----- Platform features ----- */
#define HAS_FLOAT  0
#define HAS_TIME_H 0
#define USE_CLOCK  0
#define HAS_STDIO  0
#define HAS_PRINTF 0

/* ----- Compiler info ----- */
#ifndef COMPILER_VERSION
#ifdef __riscv
#define COMPILER_VERSION "riscv64-linux-gnu-gcc " __VERSION__
#else
#define COMPILER_VERSION "gcc " __VERSION__
#endif
#endif

#ifndef COMPILER_FLAGS
#define COMPILER_FLAGS "rv32im_zicsr -O2"
#endif

#ifndef MEM_LOCATION
#define MEM_LOCATION "STACK"
#endif

/* ----- Data types (RV32) ----- */
typedef signed short   ee_s16;
typedef unsigned short ee_u16;
typedef signed int     ee_s32;
typedef float          ee_f32;
typedef unsigned char  ee_u8;
typedef unsigned int   ee_u32;
typedef ee_u32         ee_ptr_int;
typedef ee_u32         ee_size_t;
#define NULL ((void *)0)
#define align_mem(x) (void *)(4 + (((ee_ptr_int)(x)-1) & ~3))

/* ----- Timing (mcycle CSR) ----- */
#define CORETIMETYPE ee_u32
typedef ee_u32 CORE_TICKS;

/* ----- Memory & seeds ----- */
#define SEED_METHOD         SEED_VOLATILE
#define MEM_METHOD          MEM_STACK
#define MULTITHREAD         1
#define MAIN_HAS_NOARGC     1
#define MAIN_HAS_NORETURN   0

extern ee_u32 default_num_contexts;

typedef struct CORE_PORTABLE_S {
    ee_u8 portable_id;
} core_portable;

void portable_init(core_portable *p, int *argc, char *argv[]);
void portable_fini(core_portable *p);

#if !defined(PROFILE_RUN) && !defined(PERFORMANCE_RUN) \
    && !defined(VALIDATION_RUN)
#if (TOTAL_DATA_SIZE == 1200)
#define PROFILE_RUN 1
#elif (TOTAL_DATA_SIZE == 2000)
#define PERFORMANCE_RUN 1
#else
#define VALIDATION_RUN 1
#endif
#endif

int ee_printf(const char *fmt, ...);

#endif
