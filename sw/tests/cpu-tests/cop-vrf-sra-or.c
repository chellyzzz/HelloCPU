static inline unsigned cop_vload(unsigned value, unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 3, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(idx));
  return result;
}

static inline unsigned cop_vstore(unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 4, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(idx));
  return result;
}

static inline unsigned cop_vrf_sra8(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 12, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_vrf_or8(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 13, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

int main() {
  cop_vload(0x80402010u, 0);
  cop_vload(0x01020304u, 1);
  unsigned sra_res = cop_vrf_sra8();
  unsigned sra_rd = cop_vstore(0);
  if (sra_rd != 0xc0100401u) return 1;
  if (sra_res != 0xc0100401u) return 2;
  cop_vload(0x0f0f0f0fu, 0);
  cop_vload(0xf0f0f0f0u, 1);
  unsigned or_res = cop_vrf_or8();
  unsigned or_rd = cop_vstore(0);
  if (or_rd != 0xffffffffu) return 3;
  if (or_res != 0xffffffffu) return 4;
  return 0;
}
