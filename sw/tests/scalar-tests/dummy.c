static inline int cop_add(int lhs, int rhs) {
  int result;
  asm volatile (".insn r 0x0b, 0, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

int main() {
  return cop_add(10, 20) == 30 ? 0 : 1;
}
