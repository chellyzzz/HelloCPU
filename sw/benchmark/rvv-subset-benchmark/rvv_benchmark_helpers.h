#ifndef RVV_BENCHMARK_HELPERS_H
#define RVV_BENCHMARK_HELPERS_H

static inline unsigned rvv_vsetvli_e8(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 0"
                : "=r"(result)
                : "r"(avl));
  return result;
}

static inline unsigned rvv_vsetivli_e8(unsigned avl) {
  return rvv_vsetvli_e8(avl);
}

static inline unsigned rvv_vsetvli_e32(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 2"
                : "=r"(result)
                : "r"(avl));
  return result;
}

static inline unsigned rvv_vsetivli_e32(unsigned avl) {
  return rvv_vsetvli_e32(avl);
}

static inline unsigned rvv_vsetvli_e16(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 1"
                : "=r"(result)
                : "r"(avl));
  return result;
}

static inline unsigned rvv_vsetivli_e16(unsigned avl) {
  return rvv_vsetvli_e16(avl);
}

static inline unsigned rvv_debug_vrf_write(unsigned value, unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 3, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(idx));
  return result;
}

static inline void rvv_vle8_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x02050087" :: "r"(base_reg) : "memory");
}

static inline void rvv_vse8_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x020500a7" :: "r"(base_reg) : "memory");
}

static inline void rvv_vle32_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x02056087" :: "r"(base_reg) : "memory");
}

static inline void rvv_vse32_v1(unsigned base) {
  register unsigned base_reg asm("x10") = base;
  asm volatile (".word 0x020560a7" :: "r"(base_reg) : "memory");
}

static inline void rvv_vadd_v1_v1_v2(void) {
  asm volatile (".word 0x022080d7" ::: "memory");
}

static inline void rvv_vxor_v1_v1_v2(void) {
  asm volatile (".word 0x2e2080d7" ::: "memory");
}

static inline void rvv_vmsltu_vx_v0_v1(unsigned scalar) {
  register unsigned scalar_reg asm("x10") = scalar;
  asm volatile (".word 0x6a154057" :: "r"(scalar_reg) : "memory");
}

static inline void rvv_vmerge_vxm_v1_v1_x0(void) {
  asm volatile (".word 0x5c1040d7" ::: "memory");
}

static inline void rvv_vredsum_vs_v1_v2_v3(void) {
  asm volatile (".word 0x0221a0d7" ::: "memory");
}

#endif
