#ifndef RVV_TEST_HELPERS_H
#define RVV_TEST_HELPERS_H

static inline unsigned rvv_vsetivli_e8(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 0"
                : "=r"(result)
                : "r"(avl));
  return result;
}

static inline unsigned rvv_vsetivli_e32(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 2"
                : "=r"(result)
                : "r"(avl));
  return result;
}

static inline unsigned rvv_vsetivli_bad_lmul(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 1"
                : "=r"(result)
                : "r"(avl));
  return result;
}

static inline void rvv_vmv_v_x_v0(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 47, x0, %0, x0" :: "r"(scalar) : "memory");
}

static inline void rvv_vmv_v_x_v1(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 47, x1, %0, x0" :: "r"(scalar) : "memory");
}

static inline void rvv_vmv_v_x_v2(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 47, x2, %0, x0" :: "r"(scalar) : "memory");
}

static inline unsigned rvv_debug_vrf_write(unsigned value, unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 3, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(idx));
  return result;
}

static inline unsigned rvv_debug_vrf_read(unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 4, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(idx));
  return result;
}

#endif
