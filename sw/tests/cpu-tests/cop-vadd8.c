static inline unsigned cop_vadd8(unsigned lhs, unsigned rhs) {
  unsigned result;
  asm volatile (".insn r 0x0b, 1, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

int main() {
  unsigned value = cop_vadd8(0x0102feffu, 0x02030502u);
  return value == 0x03050301u ? 0 : 1;
}
