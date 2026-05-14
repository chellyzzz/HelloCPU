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

static inline unsigned rvv_vadd_vx_v1_v0(unsigned scalar) {
  register unsigned result asm("t0") = 0x12345678u;
  asm volatile (".insn r 0x57, 4, 1, x5, %1, x0"
                : "+r"(result)
                : "r"(scalar)
                : "memory");
  return result;
}

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;
  cop_vrf_write(0x0102feffu, 0);
  if (rvv_vadd_vx_v1_v0(2) != 0x12345678u) return 2;
  if (cop_vrf_read(1) != 0x03040001u) return 3;

  if (rvv_vsetivli_e8(2) != 2) return 4;
  cop_vrf_write(0x11223344u, 0);
  if (rvv_vadd_vx_v1_v0(1) != 0x12345678u) return 5;
  if (cop_vrf_read(1) != 0x00003445u) return 6;

  if (rvv_vsetivli_e32(1) != 1) return 7;
  cop_vrf_write(0x10000000u, 0);
  if (rvv_vadd_vx_v1_v0(5) != 0x12345678u) return 8;
  if (cop_vrf_read(1) != 0x10000005u) return 9;

  return 0;
}
