/*
 * hcpu CoreMark port — core_portme.c
 * Timer: mcycle CSR  |  UART: 0x10000000  |  Halt: 0x10000004
 */
#include "coremark.h"
#include "core_portme.h"

/* ----- Volatile seeds ----- */
#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

/* ----- Timer: read mcycle CSR ----- */
static inline ee_u32 read_mcycle(void) {
    ee_u32 val;
    asm volatile("csrr %0, mcycle" : "=r"(val));
    return val;
}

CORETIMETYPE barebones_clock(void) {
    return read_mcycle();
}

/* Every cycle counts as 1 tick — CoreMark/MHz = (iters * 1e6) / total_cycles */
#define CLOCKS_PER_SEC 1
#define GETMYTIME(_t)              (*_t = barebones_clock())
#define MYTIMEDIFF(fin, ini)       ((fin) - (ini))
#define TIMER_RES_DIVIDER          1
#define SAMPLE_TIME_IMPLEMENTATION 1
#define EE_TICKS_PER_SEC           1

static CORETIMETYPE start_time_val, stop_time_val;

void start_time(void) { GETMYTIME(&start_time_val); }
void stop_time(void)  { GETMYTIME(&stop_time_val);  }

CORE_TICKS get_time(void) {
    return (CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
}

secs_ret time_in_secs(CORE_TICKS ticks) {
    return ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
}

ee_u32 default_num_contexts = 1;

/* ----- UART output for ee_printf ----- */
void uart_send_char(char c) {
    *(volatile char *)0x10000000 = c;
}

/* ----- Init / Fini ----- */
void portable_init(core_portable *p, int *argc, char *argv[]) {
    (void)argc;
    (void)argv;

    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *)) {
        ee_printf("ERROR! ee_ptr_int size mismatch!\n");
    }
    if (sizeof(ee_u32) != 4) {
        ee_printf("ERROR! ee_u32 not 32b!\n");
    }
    p->portable_id = 1;
}

void portable_fini(core_portable *p) {
    ee_u32 total_cycles = barebones_clock();
    ee_printf("Total cycles     : %lu\n", (long unsigned)total_cycles);
    if (total_cycles > 0) {
        ee_u32 score = (ee_u32)((unsigned long long)ITERATIONS * 1000000ULL * 1000ULL / total_cycles);
        ee_printf("CoreMark/MHz     : %lu.%03lu\n",
                  (long unsigned)(score / 1000), (long unsigned)(score % 1000));
    }
    /* Signal testbench: halt(0) = PASS */
    *(volatile unsigned int *)0x10000004 = 0;
    while (1) asm volatile("" ::: "memory");
}
