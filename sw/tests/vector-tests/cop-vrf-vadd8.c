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

static inline unsigned cop_vrf_vadd8(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 5, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_vrf_vxor8(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 6, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_vrf_vand8(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 7, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_vrf_vsub8(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 8, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

int main() {
  cop_vload(0x01020304u, 0);
  cop_vload(0x05060708u, 1);
  unsigned add_res = cop_vrf_vadd8();
  unsigned add_rd = cop_vstore(0);
  if (add_rd != 0x06080a0cu) return 1;
  if (add_res != 0x06080a0cu) return 2;
  cop_vload(0x0f0f0f0fu, 0);
  unsigned xor_res = cop_vrf_vxor8();
  unsigned xor_rd = cop_vstore(0);
  if (xor_rd != 0x0a090807u) return 3;
  if (xor_res != 0x0a090807u) return 4;
  cop_vload(0xffffffffu, 0);
  unsigned and_res = cop_vrf_vand8();
  unsigned and_rd = cop_vstore(0);
  if (and_rd != 0x05060708u) return 5;
  if (and_res != 0x05060708u) return 6;
  cop_vload(0x10203040u, 0);
  unsigned sub_res = cop_vrf_vsub8();
  unsigned sub_rd = cop_vstore(0);
  if (sub_rd != 0x0b1a2938u) return 7;
  if (sub_res != 0x0b1a2938u) return 8;
  return 0;
}
