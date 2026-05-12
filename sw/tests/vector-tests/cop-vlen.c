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
  unsigned old = cop_vlen_write(4);
  if (old != 0) return 1;
  unsigned val = cop_vlen_read();
  if (val != 4) return 2;
  unsigned old2 = cop_vlen_write(8);
  if (old2 != 4) return 3;
  unsigned val2 = cop_vlen_read();
  if (val2 != 8) return 4;
  return 0;
}
