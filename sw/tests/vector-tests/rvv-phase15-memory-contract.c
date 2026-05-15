#include "rvv_test_helpers.h"

static unsigned src = 0x01020304u;
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
  if (rvv_vsetvli_e32(1) != 1) return 1;

  rvv_vle32_v1((unsigned)&src);
  rvv_vse32_v1((unsigned)&dst);
  if (dst != src) return 2;

  return 0;
}
