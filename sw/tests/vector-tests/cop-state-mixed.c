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

static inline unsigned cop_state(unsigned value) {
  unsigned result;
  asm volatile (".insn r 0x0b, 4, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(0));
  return result;
}

int main() {
  unsigned first = cop_state(0x0badc0deu);
  unsigned added = cop_vadd8(0x01020304u, 0x05060708u);
  unsigned second = cop_state(0xfeedfaceu);
  unsigned xored = cop_vxor8(added, 0xffffffffu);
  unsigned third = cop_state(0x13579bdfu);
  if (first != 0) return 1;
  if (added != 0x06080a0cu) return 2;
  if (second != 0x0badc0deu) return 3;
  if (xored != 0xf9f7f5f3u) return 4;
  if (third != 0xfeedfaceu) return 5;
  return 0;
}
