static inline unsigned cop_add(unsigned lhs, unsigned rhs) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

static inline unsigned cop_vadd8(unsigned lhs, unsigned rhs) {
  unsigned result;
  asm volatile (".insn r 0x0b, 1, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

int main() {
  unsigned first = cop_add(1, 2);
  unsigned second = cop_vadd8(0x0102feffu, 0x02030502u);
  if (first != 3) return 1;
  if (second != 0x03050301u) return 2;
  return 0;
}
