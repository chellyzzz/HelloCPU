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

static inline unsigned cop_vrf_mul8(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 9, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_vrf_sll8(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 10, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_vrf_srl8(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 11, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

int main() {
  cop_vload(0x02030405u, 0);
  cop_vload(0x03040506u, 1);
  unsigned mul_res = cop_vrf_mul8();
  unsigned mul_rd = cop_vstore(0);
  if (mul_rd != 0x060c141eu) return 1;
  if (mul_res != 0x060c141eu) return 2;
  cop_vload(0x01020304u, 0);
  cop_vload(0x01020304u, 1);
  unsigned sll_res = cop_vrf_sll8();
  unsigned sll_rd = cop_vstore(0);
  if (sll_rd != 0x02081840u) return 3;
  if (sll_res != 0x02081840u) return 4;
  cop_vload(0x80402010u, 0);
  cop_vload(0x01020304u, 1);
  unsigned srl_res = cop_vrf_srl8();
  unsigned srl_rd = cop_vstore(0);
  if (srl_rd != 0x40100401u) return 5;
  if (srl_res != 0x40100401u) return 6;
  return 0;
}
