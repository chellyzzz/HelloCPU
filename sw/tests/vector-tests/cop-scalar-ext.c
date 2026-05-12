static inline unsigned cop_add(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_sub(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 1, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_mul(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 2, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

int main() {
  unsigned a = cop_add(10, 20);
  unsigned b = cop_sub(50, 18);
  unsigned c = cop_mul(7, 6);
  unsigned d = cop_sub(0, 5);
  if (a != 30) return 1;
  if (b != 32) return 2;
  if (c != 42) return 3;
  if (d != 0xfffffffbu) return 4;
  return 0;
}
