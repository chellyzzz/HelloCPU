#include "rvv_test_helpers.h"

static inline void rvv_vadd_vv_masked_v1_v2_v3(void) {
  asm volatile (".word 0x002180d7" ::: "memory");
}

static inline void rvv_vsub_vv_masked_v1_v2_v3(void) {
  asm volatile (".word 0x082180d7" ::: "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;

  rvv_debug_vrf_write(0x00000005u, 0);
  rvv_debug_vrf_write(0xaabbccddu, 1);
  rvv_debug_vrf_write(0x10203040u, 2);
  rvv_debug_vrf_write(0x01020304u, 3);
  rvv_vadd_vv_masked_v1_v2_v3();
  if (rvv_debug_vrf_read(1) != 0xaa22cc44u) return 2;

  if (rvv_vsetivli_e8(2) != 2) return 3;
  rvv_debug_vrf_write(0x00000002u, 0);
  rvv_debug_vrf_write(0xaabbccddu, 1);
  rvv_debug_vrf_write(0x10203040u, 2);
  rvv_debug_vrf_write(0x01020304u, 3);
  rvv_vsub_vv_masked_v1_v2_v3();
  if (rvv_debug_vrf_read(1) != 0x00002dddu) return 4;

  if (rvv_vsetivli_e32(1) != 1) return 5;
  rvv_debug_vrf_write(0x00000000u, 0);
  rvv_debug_vrf_write(0x12345678u, 1);
  rvv_debug_vrf_write(0x00000010u, 2);
  rvv_debug_vrf_write(0x00000001u, 3);
  rvv_vadd_vv_masked_v1_v2_v3();
  if (rvv_debug_vrf_read(1) != 0x12345678u) return 6;

  rvv_debug_vrf_write(0x00000001u, 0);
  rvv_vadd_vv_masked_v1_v2_v3();
  if (rvv_debug_vrf_read(1) != 0x00000011u) return 7;

  return 0;
}
