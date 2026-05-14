#include "rvv_test_helpers.h"

static unsigned src32 = 0x76543210u;
static unsigned dst32;

static inline void rvv_vadd_v17_v18_v19(void) {
  asm volatile (".word 0x032988d7" ::: "memory");
}

static inline void rvv_vand_masked_v17_v18_v19(void) {
  asm volatile (".word 0x252988d7" ::: "memory");
}

static inline void rvv_vle32_v31(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x02056f87" :: "r"(base_reg) : "memory");
}

static inline void rvv_vse32_v31(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x02056fa7" :: "r"(base_reg) : "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;
  rvv_debug_vrf_write(0x01020304u, 18);
  rvv_debug_vrf_write(0x10101010u, 19);
  rvv_vadd_v17_v18_v19();
  if (rvv_debug_vrf_read(17) != 0x11121314u) return 2;

  rvv_debug_vrf_write(0x00000005u, 0);
  rvv_debug_vrf_write(0xaabbccddu, 17);
  rvv_debug_vrf_write(0x0f0ff0f0u, 18);
  rvv_debug_vrf_write(0x3333ccccu, 19);
  rvv_vand_masked_v17_v18_v19();
  if (rvv_debug_vrf_read(17) != 0xaa03ccc0u) return 3;

  if (rvv_vsetivli_e32(1) != 1) return 4;
  rvv_vle32_v31((unsigned)&src32);
  if (rvv_debug_vrf_read(31) != 0x76543210u) return 5;

  rvv_debug_vrf_write(0x89abcdefu, 31);
  rvv_vse32_v31((unsigned)&dst32);
  if (dst32 != 0x89abcdefu) return 6;

  return 0;
}
