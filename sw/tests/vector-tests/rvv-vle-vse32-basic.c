#include "rvv_test_helpers.h"

static unsigned src = 0x89abcdefu;
static unsigned dst;

static inline void rvv_vle32_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x02056087" :: "r"(base_reg) : "memory");
}

static inline void rvv_vse32_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x020560a7" :: "r"(base_reg) : "memory");
}

int main() {
  if (rvv_vsetivli_e32(1) != 1) return 1;
  rvv_vle32_v1((unsigned)&src);
  if (rvv_debug_vrf_read(1) != 0x89abcdefu) return 2;

  rvv_vmv_v_x_v1(0x12345678u);
  rvv_vse32_v1((unsigned)&dst);
  if (dst != 0x12345678u) return 3;

  if (rvv_vsetivli_e32(0) != 0) return 4;
  rvv_vle32_v1((unsigned)&src);
  if (rvv_debug_vrf_read(1) != 0) return 5;

  return 0;
}
