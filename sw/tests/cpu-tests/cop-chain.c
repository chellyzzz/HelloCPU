static inline int cop_add(int lhs, int rhs) {
  int result;
  asm volatile (".insn r 0x0b, 0, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

int main() {
  int first = cop_add(1, 2);
  int second = cop_add(first, 4);
  return second == 7 ? 0 : 1;
}
