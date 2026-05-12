static inline unsigned cop_vxor8(unsigned lhs, unsigned rhs) {
  unsigned result;
  asm volatile (".insn r 0x0b, 2, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

int main() {
  unsigned value = cop_vxor8(0x0f0ff0f0u, 0x00ff55aau);
  return value == 0x0ff0a55au ? 0 : 1;
}
