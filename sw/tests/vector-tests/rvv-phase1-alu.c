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

static inline unsigned cop_vrf_write(unsigned value, unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 3, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(idx));
  return result;
}

static inline unsigned cop_vrf_read(unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 4, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(idx));
  return result;
}

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
  cop_vrf_write(0x0102feffu, 0);
  rvv_vadd_vi_v1_v0_3();
  if (cop_vrf_read(1) != 0x04050102u) return 2;

  cop_vrf_write(0x0f0ff0f0u, 0);
  rvv_vand_vx_v1_v0(0x3333ccccu);
  if (cop_vrf_read(1) != 0x0303c0c0u) return 3;
  rvv_vor_vx_v1_v0(0x3333ccccu);
  if (cop_vrf_read(1) != 0x3f3ffcfcu) return 4;
  rvv_vxor_vx_v1_v0(0x3333ccccu);
  if (cop_vrf_read(1) != 0x3c3c3c3cu) return 5;

  if (rvv_vsetivli_e8(2) != 2) return 6;
  cop_vrf_write(0x11223344u, 0);
  rvv_vadd_vi_v1_v0_1();
  if (cop_vrf_read(1) != 0x00003445u) return 7;

  if (rvv_vsetivli_e32(1) != 1) return 8;
  cop_vrf_write(0x10000000u, 0);
  rvv_vadd_vi_v1_v0_3();
  if (cop_vrf_read(1) != 0x10000003u) return 9;

  return 0;
}
