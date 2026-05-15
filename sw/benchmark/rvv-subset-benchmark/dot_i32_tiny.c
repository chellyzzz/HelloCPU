#include "rvv_benchmark_helpers.h"

static unsigned lhs = 7u;
static unsigned dst;

static inline void rvv_vmul_vx_v1_v1(unsigned scalar) {
  asm volatile (".insn r 0x57, 6, 75, x1, %0, x1" :: "r"(scalar) : "memory");
}

int main() {
  if (rvv_vsetivli_e32(1) != 1) return 1;

  rvv_vle32_v1((unsigned)&lhs);
  rvv_vmul_vx_v1_v1(6u);
  rvv_vse32_v1((unsigned)&dst);

  if (dst != 42u) return 2;
  return 0;
}
