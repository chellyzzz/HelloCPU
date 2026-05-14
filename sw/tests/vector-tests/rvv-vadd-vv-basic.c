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

static inline void rvv_vadd_vv_v1_v0_v2(void) {
  asm volatile (".word 0x020102d7" ::: "t0", "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;
  cop_vrf_write(0x0102feffu, 0);
  cop_vrf_write(0x02030502u, 2);
  rvv_vadd_vv_v1_v0_v2();
  if (cop_vrf_read(1) != 0x03050301u) return 2;

  if (rvv_vsetivli_e8(2) != 2) return 3;
  cop_vrf_write(0x11223344u, 0);
  cop_vrf_write(0x01010101u, 2);
  rvv_vadd_vv_v1_v0_v2();
  if (cop_vrf_read(1) != 0x00003445u) return 4;

  if (rvv_vsetivli_e32(1) != 1) return 5;
  cop_vrf_write(0x10000000u, 0);
  cop_vrf_write(0x00000005u, 2);
  rvv_vadd_vv_v1_v0_v2();
  if (cop_vrf_read(1) != 0x10000005u) return 6;

  return 0;
}
