static inline unsigned cop_vload_mem(unsigned base) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 14, %0, %1, %2"
                : "=r"(result)
                : "r"(base), "r"(0)
                : "memory");
  return result;
}

static unsigned data = 0x99aabbccu;

int main() {
  unsigned killed_result;

  asm volatile ("li %[result], 0\n"
                "j 1f\n"
                ".insn r 0x0b, 0, 14, %[result], %[base], x0\n"
                "1:\n"
                : [result] "=&r"(killed_result)
                : [base] "r"((unsigned)&data)
                : "memory");

  if (killed_result != 0) return 1;
  if (cop_vload_mem((unsigned)&data) != 0x99aabbccu) return 2;
  return 0;
}
