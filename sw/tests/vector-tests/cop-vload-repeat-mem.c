static inline unsigned cop_vload_mem(unsigned base) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 14, %0, %1, %2"
                : "=r"(result)
                : "r"(base), "r"(0)
                : "memory");
  return result;
}

static unsigned data = 0x55667788u;

int main() {
  unsigned loaded0 = cop_vload_mem((unsigned)&data);
  unsigned loaded1 = cop_vload_mem((unsigned)&data);

  if (loaded0 != 0x55667788u) return 1;
  if (loaded1 != 0x55667788u) return 2;
  return 0;
}
