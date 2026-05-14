#include "rvv_test_helpers.h"

static inline void rvv_vadd_vi_v1_v0_3(void) {
  asm volatile (".word 0x0201b2d7" ::: "memory");
}

static inline void rvv_vadd_vi_v1_v0_1(void) {
  asm volatile (".word 0x0200b2d7" ::: "memory");
}

static inline void rvv_vand_vx_v1_v0(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 19, x5, %0, x0" :: "r"(scalar) : "memory");
}

static inline void rvv_vor_vx_v1_v0(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 21, x5, %0, x0" :: "r"(scalar) : "memory");
}

static inline void rvv_vxor_vx_v1_v0(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 23, x5, %0, x0" :: "r"(scalar) : "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;
  rvv_vmv_v_x_v0(0x0102feffu);
  rvv_vadd_vi_v1_v0_3();
  if (rvv_debug_vrf_read(1) != 0x04050102u) return 2;

  rvv_vmv_v_x_v0(0x0f0ff0f0u);
  rvv_vand_vx_v1_v0(0x3333ccccu);
  if (rvv_debug_vrf_read(1) != 0x0303c0c0u) return 3;
  rvv_vor_vx_v1_v0(0x3333ccccu);
  if (rvv_debug_vrf_read(1) != 0x3f3ffcfcu) return 4;
  rvv_vxor_vx_v1_v0(0x3333ccccu);
  if (rvv_debug_vrf_read(1) != 0x3c3c3c3cu) return 5;

  if (rvv_vsetivli_e8(2) != 2) return 6;
  rvv_vmv_v_x_v0(0x11223344u);
  rvv_vadd_vi_v1_v0_1();
  if (rvv_debug_vrf_read(1) != 0x00003445u) return 7;

  if (rvv_vsetivli_e32(1) != 1) return 8;
  rvv_vmv_v_x_v0(0x10000000u);
  rvv_vadd_vi_v1_v0_3();
  if (rvv_debug_vrf_read(1) != 0x10000003u) return 9;

  return 0;
}
