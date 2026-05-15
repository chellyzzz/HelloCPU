#include "rvv_test_helpers.h"

static inline void rvv_vredsum_vs_v1_v2_v3(void) {
  asm volatile (".word 0x0221a0d7" ::: "memory");
}

int main() {
  if (rvv_vsetvli_e8(4) != 4) return 1;
  rvv_debug_vrf_write(0x04030201u, 2);
  rvv_debug_vrf_write(0x00000005u, 3);
  rvv_vredsum_vs_v1_v2_v3();
  if (rvv_debug_vrf_read(1) != 0x0000000fu) return 2;

  if (rvv_vsetvli_e16(2) != 2) return 3;
  rvv_debug_vrf_write(0x00020001u, 2);
  rvv_debug_vrf_write(0x00000003u, 3);
  rvv_vredsum_vs_v1_v2_v3();
  if (rvv_debug_vrf_read(1) != 0x00000006u) return 4;

  if (rvv_vsetvli_e32(1) != 1) return 5;
  rvv_debug_vrf_write(7u, 2);
  rvv_debug_vrf_write(5u, 3);
  rvv_vredsum_vs_v1_v2_v3();
  if (rvv_debug_vrf_read(1) != 12u) return 6;

  return 0;
}
