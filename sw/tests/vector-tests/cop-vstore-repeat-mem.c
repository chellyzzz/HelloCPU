static inline unsigned cop_vload(unsigned value, unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 3, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(idx));
  return result;
}

static inline unsigned cop_vstore_mem(unsigned base) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 15, %0, %1, %2"
                : "=r"(result)
                : "r"(base), "r"(0)
                : "memory");
  return result;
}

static unsigned data;

int main() {
  cop_vload(0x11223344u, 0);
  unsigned stored0 = cop_vstore_mem((unsigned)&data);

  cop_vload(0x55667788u, 0);
  unsigned stored1 = cop_vstore_mem((unsigned)&data);

  if (stored0 != 0x11223344u) return 1;
  if (stored1 != 0x55667788u) return 2;
  if (data != 0x55667788u) return 3;
  return 0;
}
