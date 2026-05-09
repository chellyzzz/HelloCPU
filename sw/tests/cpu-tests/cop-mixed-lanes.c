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

int main() {
  unsigned added = cop_vadd8(0x0102feffu, 0x02030502u);
  unsigned xored = cop_vxor8(added, 0x00ff55aau);
  unsigned masked = cop_vand8(xored, 0x0fff0ff0u);
  if (added != 0x03050301u) return 1;
  if (xored != 0x03fa56abu) return 2;
  if (masked != 0x03fa06a0u) return 3;
  return 0;
}
