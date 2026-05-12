static inline unsigned cop_scratch(unsigned value) {
  unsigned result;
  asm volatile (".insn r 0x0b, 4, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(0));
  return result;
}

static inline unsigned cop_vlen_write(unsigned value) {
  unsigned result;
  asm volatile (".insn r 0x0b, 5, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(0));
  return result;
}

static inline unsigned cop_vlen_read(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 6, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

int main() {
  cop_scratch(0xaaaa);
  cop_vlen_write(4);
  unsigned s1 = cop_scratch(0xbbbb);
  unsigned v1 = cop_vlen_read();
  unsigned s2 = cop_scratch(0xcccc);
  unsigned v2 = cop_vlen_read();
  if (s1 != 0xaaaa) return 1;
  if (v1 != 4) return 2;
  if (s2 != 0xbbbb) return 3;
  if (v2 != 4) return 4;
  return 0;
}
