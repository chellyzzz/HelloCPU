static inline unsigned cop_state(unsigned value) {
  unsigned result;
  asm volatile (".insn r 0x0b, 4, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(0));
  return result;
}

int main() {
  unsigned first = cop_state(0x11223344u);
  unsigned second = cop_state(0xa5a55a5au);
  unsigned third = cop_state(0x01020304u);
  if (first != 0) return 1;
  if (second != 0x11223344u) return 2;
  if (third != 0xa5a55a5au) return 3;
  return 0;
}
