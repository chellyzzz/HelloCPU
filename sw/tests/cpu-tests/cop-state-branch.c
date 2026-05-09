static inline unsigned cop_state(unsigned value) {
  unsigned result;
  asm volatile (".insn r 0x0b, 4, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(0));
  return result;
}

int main() {
  volatile unsigned take_branch = 1;
  unsigned first = cop_state(0x12345678u);
  if (!take_branch) return 1;
  unsigned second = cop_state(0x89abcdefu);
  if (first != 0) return 2;
  if (second != 0x12345678u) return 3;
  return 0;
}
