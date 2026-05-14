#include "rvv_test_helpers.h"

static unsigned src = 0x44332211u;
static unsigned short_src = 0xddccbbaau;
static unsigned dst;
static unsigned zero_dst = 0x04030201u;

static inline void rvv_vle8_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x02050087" :: "r"(base_reg) : "memory");
}

static inline void rvv_vse8_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x020500a7" :: "r"(base_reg) : "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;
  rvv_vle8_v1((unsigned)&src);
  if (rvv_debug_vrf_read(1) != 0x44332211u) return 2;

  rvv_vmv_v_x_v1(0x55667788u);
  rvv_vse8_v1((unsigned)&dst);
  if (dst != 0x55667788u) return 3;

  if (rvv_vsetivli_e8(2) != 2) return 4;
  rvv_vle8_v1((unsigned)&short_src);
  if (rvv_debug_vrf_read(1) != 0x0000bbaau) return 5;

  rvv_vmv_v_x_v1(0xaabbccddu);
  rvv_vse8_v1((unsigned)&zero_dst);
  if (zero_dst != 0x0403ccddu) return 6;

  if (rvv_vsetivli_e8(0) != 0) return 7;
  rvv_vle8_v1((unsigned)&src);
  if (rvv_debug_vrf_read(1) != 0) return 8;

  return 0;
}
