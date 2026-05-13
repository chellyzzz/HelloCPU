static inline unsigned cop_vload_mem(unsigned base) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 14, %0, %1, %2"
                : "=r"(result)
                : "r"(base), "r"(0)
                : "memory");
  return result;
}

static unsigned data[2] = {0x11223344u, 0xaabbccddu};

int main() {
  unsigned loaded0 = cop_vload_mem((unsigned)&data[0]);
  unsigned loaded1 = cop_vload_mem((unsigned)&data[1]);

  if (loaded0 != 0x11223344u) return 1;
  if (loaded1 != 0xaabbccddu) return 2;
  return 0;
}
