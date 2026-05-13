static inline unsigned cop_opcount(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 7, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_vadd8(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 1, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_vxor8(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 2, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_vand8(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 3, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_vlen_write(unsigned v) {
  unsigned result;
  asm volatile (".insn r 0x0b, 5, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(v), "r"(0));
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
  unsigned c0 = cop_opcount();
  unsigned a  = cop_vadd8(0x01020304u, 0x05060708u);
  unsigned c1 = cop_opcount();
  unsigned x  = cop_vxor8(a, 0xffffffffu);
  unsigned c2 = cop_opcount();
  unsigned m  = cop_vand8(x, 0x0f0f0f0fu);
  unsigned c3 = cop_opcount();
  unsigned vl = cop_vlen_read();
  unsigned c4 = cop_opcount();
  if (c0 != 1) return 1;
  if (a  != 0x06080a0cu) return 2;
  if (c1 != 3) return 3;
  if (x  != 0xf9f7f5f3u) return 4;
  if (c2 != 5) return 5;
  if (m  != 0x09070503u) return 6;
  if (c3 != 7) return 7;
  if (vl != 4) return 8;
  if (c4 != 9) return 9;
  return 0;
}
