#include "rvv_test_helpers.h"

static inline void rvv_vmseq_vv_v0_v1_v2(void) {
  asm volatile (".word 0x62110057" ::: "memory");
}

static inline void rvv_vmsne_vv_v0_v1_v2(void) {
  asm volatile (".word 0x66110057" ::: "memory");
}

static inline void rvv_vmsltu_vx_v0_v1(unsigned scalar) {
  register unsigned scalar_reg asm("x10") = scalar;
  asm volatile (".word 0x6a154057" :: "r"(scalar_reg) : "memory");
}

static inline void rvv_vmslt_vx_v0_v1(unsigned scalar) {
  register unsigned scalar_reg asm("x10") = scalar;
  asm volatile (".word 0x6e154057" :: "r"(scalar_reg) : "memory");
}

static inline void rvv_vmerge_vvm_v3_v1_v2(void) {
  asm volatile (".word 0x5c1101d7" ::: "memory");
}

static inline void rvv_vmerge_vxm_v3_v1(unsigned scalar) {
  register unsigned scalar_reg asm("x10") = scalar;
  asm volatile (".word 0x5c1541d7" :: "r"(scalar_reg) : "memory");
}

int main() {
  if (rvv_vsetvli_e8(4) != 4) return 1;
  rvv_debug_vrf_write(0x04030201u, 1);
  rvv_debug_vrf_write(0x04030001u, 2);

  rvv_vmseq_vv_v0_v1_v2();
  if (rvv_debug_vrf_read(0) != 0x0000000du) return 2;

  rvv_vmsne_vv_v0_v1_v2();
  if (rvv_debug_vrf_read(0) != 0x00000002u) return 3;

  rvv_vmsltu_vx_v0_v1(3u);
  if (rvv_debug_vrf_read(0) != 0x00000003u) return 4;

  rvv_debug_vrf_write(0x14131211u, 2);
  rvv_vmerge_vvm_v3_v1_v2();
  if (rvv_debug_vrf_read(3) != 0x04031211u) return 5;

  rvv_vmerge_vxm_v3_v1(0xaau);
  if (rvv_debug_vrf_read(3) != 0x0403aaaau) return 6;

  if (rvv_vsetvli_e16(2) != 2) return 7;
  rvv_debug_vrf_write(0x00020001u, 1);
  rvv_vmsltu_vx_v0_v1(2u);
  if (rvv_debug_vrf_read(0) != 0x00000001u) return 8;

  if (rvv_vsetvli_e32(1) != 1) return 9;
  rvv_debug_vrf_write(0xffffffffu, 1);
  rvv_vmslt_vx_v0_v1(0u);
  if (rvv_debug_vrf_read(0) != 0x00000001u) return 10;

  return 0;
}
