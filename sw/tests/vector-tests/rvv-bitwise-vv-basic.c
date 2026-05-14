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

static inline void rvv_vand_vv_v1_v0_v2(void) {
  asm volatile (".word 0x262000d7" ::: "memory");
}

static inline void rvv_vor_vv_v1_v0_v2(void) {
  asm volatile (".word 0x2a2000d7" ::: "memory");
}

static inline void rvv_vxor_vv_v1_v0_v2(void) {
  asm volatile (".word 0x2e2000d7" ::: "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;
  cop_vrf_write(0x0f0ff0f0u, 0);
  cop_vrf_write(0x3333ccccu, 2);
  rvv_vand_vv_v1_v0_v2();
  if (cop_vrf_read(1) != 0x0303c0c0u) return 2;
  rvv_vor_vv_v1_v0_v2();
  if (cop_vrf_read(1) != 0x3f3ffcfcu) return 3;
  rvv_vxor_vv_v1_v0_v2();
  if (cop_vrf_read(1) != 0x3c3c3c3cu) return 4;

  if (rvv_vsetivli_e8(2) != 2) return 5;
  cop_vrf_write(0x11223344u, 0);
  cop_vrf_write(0xff00ff00u, 2);
  rvv_vor_vv_v1_v0_v2();
  if (cop_vrf_read(1) != 0x0000ff44u) return 6;

  if (rvv_vsetivli_e32(1) != 1) return 7;
  cop_vrf_write(0xaaaa5555u, 0);
  cop_vrf_write(0x0f0ff0f0u, 2);
  rvv_vand_vv_v1_v0_v2();
  if (cop_vrf_read(1) != 0x0a0a5050u) return 8;

  return 0;
}
