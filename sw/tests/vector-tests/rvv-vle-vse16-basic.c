#include "rvv_test_helpers.h"

static unsigned src = 0x33441122u;
static unsigned dst;

static inline void rvv_vle16_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x02055087" :: "r"(base_reg) : "memory");
}

static inline void rvv_vse16_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x020550a7" :: "r"(base_reg) : "memory");
}

int main() {
  if (rvv_vsetivli_e16(2) != 2) return 1;
  rvv_vle16_v1((unsigned)&src);
  if (rvv_debug_vrf_read(1) != 0x33441122u) return 2;

  rvv_debug_vrf_write(0x77885566u, 1);
  rvv_vse16_v1((unsigned)&dst);
  if (dst != 0x77885566u) return 3;

  if (rvv_vsetivli_e16(4) != 2) return 4;
  if (rvv_vsetivli_e16(0) != 0) return 5;
  rvv_vle16_v1((unsigned)&src);
  if (rvv_debug_vrf_read(1) != 0) return 6;

  return 0;
}
