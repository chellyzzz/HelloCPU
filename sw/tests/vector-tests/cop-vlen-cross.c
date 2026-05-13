static inline unsigned cop_vadd8(unsigned lhs, unsigned rhs) {
  unsigned result;
  asm volatile (".insn r 0x0b, 1, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

static inline unsigned cop_vxor8(unsigned lhs, unsigned rhs) {
  unsigned result;
  asm volatile (".insn r 0x0b, 2, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

static inline unsigned cop_vand8(unsigned lhs, unsigned rhs) {
  unsigned result;
  asm volatile (".insn r 0x0b, 3, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

static inline unsigned cop_vlen_write(unsigned value) {
  unsigned result;
  asm volatile (".insn r 0x0b, 5, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(0));
  return result;
}

static inline unsigned cop_vlen_read(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 6, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

int main() {
  cop_vlen_write(4);
  unsigned added = cop_vadd8(0x01020304u, 0x05060708u);
  unsigned vlen1 = cop_vlen_read();
  unsigned xored = cop_vxor8(added, 0xffffffffu);
  unsigned vlen2 = cop_vlen_read();
  unsigned masked = cop_vand8(xored, 0x0f0f0f0fu);
  unsigned vlen3 = cop_vlen_read();
  if (added != 0x06080a0cu) return 1;
  if (vlen1 != 4) return 2;
  if (xored != 0xf9f7f5f3u) return 3;
  if (vlen2 != 4) return 4;
  if (masked != 0x09070503u) return 5;
  if (vlen3 != 4) return 6;
  return 0;
}
