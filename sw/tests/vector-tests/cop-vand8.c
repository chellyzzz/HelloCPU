static inline unsigned cop_vand8(unsigned lhs, unsigned rhs) {
  unsigned result;
  asm volatile (".insn r 0x0b, 3, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

int main() {
  unsigned value = cop_vand8(0xff00aa55u, 0x0f0ff0f0u);
  return value == 0x0f00a050u ? 0 : 1;
}
