#include "rvv_test_helpers.h"

static inline void rvv_vmv_v_v_v1_v2(void) {
  asm volatile (".word 0x5e0100d7" ::: "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;
  rvv_vmv_v_x_v2(0x11223344u);
  rvv_vmv_v_v_v1_v2();
  if (rvv_debug_vrf_read(1) != 0x11223344u) return 2;

  rvv_vmv_v_x_v1(0xaabbccddu);
  if (rvv_debug_vrf_read(1) != 0xaabbccddu) return 3;

  if (rvv_vsetivli_e8(2) != 2) return 4;
  rvv_vmv_v_x_v1(0x55667788u);
  if (rvv_debug_vrf_read(1) != 0x00007788u) return 5;

  if (rvv_vsetivli_bad_lmul(4) != 4) return 6;
  rvv_debug_vrf_write(0x12345678u, 1);
  rvv_vmv_v_x_v1(0xffffffffu);
  if (rvv_debug_vrf_read(1) != 0x12345678u) return 7;

  return 0;
}
