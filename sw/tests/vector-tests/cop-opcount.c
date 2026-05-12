static inline unsigned cop_opcount(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 7, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_add(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_vadd8(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 1, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

int main() {
  unsigned c0 = cop_opcount();
  unsigned r1 = cop_add(1, 2);
  unsigned c1 = cop_opcount();
  unsigned r2 = cop_vadd8(0x01020304u, 0x05060708u);
  unsigned c2 = cop_opcount();
  if (c0 != 0) return 1;
  if (r1 != 3) return 2;
  if (c1 != 2) return 3;
  if (r2 != 0x06080a0cu) return 4;
  if (c2 != 4) return 5;
  return 0;
}
