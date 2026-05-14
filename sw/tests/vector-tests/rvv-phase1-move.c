static inline unsigned rvv_vsetivli_e8(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 0"
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

static inline void rvv_vmv_v_v_v1_v2(void) {
  asm volatile (".word 0x5e0102d7" ::: "memory");
}

static inline void rvv_vmv_v_x_v1(unsigned scalar) {
  asm volatile (".insn r 0x57, 4, 47, x5, %0, x0" :: "r"(scalar) : "memory");
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;
  cop_vrf_write(0x11223344u, 2);
  rvv_vmv_v_v_v1_v2();
  if (cop_vrf_read(1) != 0x11223344u) return 2;

  rvv_vmv_v_x_v1(0xaabbccddu);
  if (cop_vrf_read(1) != 0xaabbccddu) return 3;

  if (rvv_vsetivli_e8(2) != 2) return 4;
  rvv_vmv_v_x_v1(0x55667788u);
  if (cop_vrf_read(1) != 0x00007788u) return 5;

  if (rvv_vsetivli_bad_lmul(4) != 4) return 6;
  cop_vrf_write(0x12345678u, 1);
  rvv_vmv_v_x_v1(0xffffffffu);
  if (cop_vrf_read(1) != 0x12345678u) return 7;

  return 0;
}
