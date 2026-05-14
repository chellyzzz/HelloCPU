#include "rvv_test_helpers.h"

static inline void rvv_vsub_vv_v1_v0_v2(void) {
  asm volatile (".insn r 0x57, 0, 5, x1, x2, x0" ::: "memory");
}

static inline void rvv_vsub_vx_v1_v0(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 5, x1, %0, x0" :: "r"(scalar) : "memory");
}

static inline void rvv_vsll_vv_v1_v0_v2(void) {
  asm volatile (".insn r 0x57, 0, 75, x1, x2, x0" ::: "memory");
}

static inline void rvv_vsrl_vv_v1_v0_v2(void) {
  asm volatile (".insn r 0x57, 0, 81, x1, x2, x0" ::: "memory");
}

static inline void rvv_vsra_vv_v1_v0_v2(void) {
  asm volatile (".insn r 0x57, 0, 83, x1, x2, x0" ::: "memory");
}

static inline void rvv_vsll_vx_v1_v0(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 75, x1, %0, x0" :: "r"(scalar) : "memory");
}

static inline void rvv_vsrl_vx_v1_v0(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 81, x1, %0, x0" :: "r"(scalar) : "memory");
}

static inline void rvv_vsra_vx_v1_v0(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 83, x1, %0, x0" :: "r"(scalar) : "memory");
}

static inline void rvv_vand_vi_v1_v0_3(void) {
  asm volatile (".word 0x2601b0d7" ::: "memory");
}

static inline void rvv_vor_vi_v1_v0_3(void) {
  asm volatile (".word 0x2a01b0d7" ::: "memory");
}

static inline void rvv_vxor_vi_v1_v0_3(void) {
  asm volatile (".word 0x2e01b0d7" ::: "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;

  rvv_vmv_v_x_v0(0x10203040u);
  rvv_vmv_v_x_v2(0x01020304u);
  rvv_vsub_vv_v1_v0_v2();
  if (rvv_debug_vrf_read(1) != 0x0f1e2d3cu) return 2;

  rvv_vsub_vx_v1_v0(2);
  if (rvv_debug_vrf_read(1) != 0x0e1e2e3eu) return 3;

  rvv_vmv_v_x_v0(0x81820408u);
  rvv_vmv_v_x_v2(0x01010101u);
  rvv_vsll_vv_v1_v0_v2();
  if (rvv_debug_vrf_read(1) != 0x02040810u) return 4;
  rvv_vsrl_vv_v1_v0_v2();
  if (rvv_debug_vrf_read(1) != 0x40410204u) return 5;
  rvv_vsra_vv_v1_v0_v2();
  if (rvv_debug_vrf_read(1) != 0xc0c10204u) return 6;

  rvv_vsll_vx_v1_v0(1);
  if (rvv_debug_vrf_read(1) != 0x02040810u) return 7;
  rvv_vsrl_vx_v1_v0(1);
  if (rvv_debug_vrf_read(1) != 0x40410204u) return 8;
  rvv_vsra_vx_v1_v0(1);
  if (rvv_debug_vrf_read(1) != 0xc0c10204u) return 9;

  rvv_vmv_v_x_v0(0x0f0ff0f0u);
  rvv_vand_vi_v1_v0_3();
  if (rvv_debug_vrf_read(1) != 0x03030000u) return 10;
  rvv_vor_vi_v1_v0_3();
  if (rvv_debug_vrf_read(1) != 0x0f0ff3f3u) return 11;
  rvv_vxor_vi_v1_v0_3();
  if (rvv_debug_vrf_read(1) != 0x0c0cf3f3u) return 12;

  if (rvv_vsetivli_e32(1) != 1) return 13;
  rvv_vmv_v_x_v0(0x80000010u);
  rvv_vsra_vx_v1_v0(1);
  if (rvv_debug_vrf_read(1) != 0xc0000008u) return 14;

  return 0;
}
