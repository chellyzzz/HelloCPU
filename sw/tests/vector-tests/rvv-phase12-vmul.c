#include "rvv_test_helpers.h"

static inline void rvv_vmul_vv_v1_v1_v2(void) {
  asm volatile (".word 0x961120d7" ::: "memory");
}

static inline void rvv_vmul_vx_v1_v1(unsigned scalar) {
  asm volatile (".insn r 0x57, 6, 75, x1, %0, x1" :: "r"(scalar) : "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;
  rvv_debug_vrf_write(0x02030405u, 1);
  rvv_debug_vrf_write(0x04030201u, 2);
  rvv_vmul_vv_v1_v1_v2();
  if (rvv_debug_vrf_read(1) != 0x08090805u) return 2;

  if (rvv_vsetivli_e32(1) != 1) return 3;
  rvv_debug_vrf_write(7u, 1);
  rvv_vmul_vx_v1_v1(6u);
  if (rvv_debug_vrf_read(1) != 42u) return 4;

  return 0;
}
