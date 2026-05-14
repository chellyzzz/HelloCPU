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

static inline unsigned rvv_vadd_vx_v1_v0(unsigned scalar) {
  register unsigned result asm("t0") = 0xabcdef01u;
  asm volatile (".insn r 0x57, 4, 1, x1, %1, x0"
                : "+r"(result)
                : "r"(scalar)
                : "memory");
  return result;
}

int main() {
  if (rvv_vsetivli_e8(0) != 0) return 1;
  cop_vrf_write(0x11111111u, 0);
  cop_vrf_write(0xaaaaaaaau, 1);
  if (rvv_vadd_vx_v1_v0(1) != 0xabcdef01u) return 2;
  if (cop_vrf_read(1) != 0) return 3;

  if (rvv_vsetivli_bad_lmul(4) != 4) return 4;
  cop_vrf_write(0x22222222u, 1);
  if (rvv_vadd_vx_v1_v0(2) != 0xabcdef01u) return 5;
  if (cop_vrf_read(1) != 0x22222222u) return 6;

  if (rvv_vsetivli_e8(1) != 1) return 7;
  if (rvv_vadd_vx_v1_v0(1) != 0xabcdef01u) return 8;
  if (cop_vrf_read(1) != 0x12u) return 9;

  return 0;
}
