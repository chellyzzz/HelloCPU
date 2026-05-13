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

static inline unsigned cop_vtype_write(unsigned value) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 16, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(0));
  return result;
}

static inline unsigned cop_vtype_read(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 17, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

int main() {
  cop_vlen_write(8);
  if (cop_vlen_read() != 4) return 1;

  if (cop_vtype_write(2) != 0x80000000u) return 2;
  if (cop_vtype_read() != 2) return 3;
  if (cop_vlen_read() != 4) return 4;

  cop_vlen_write(0);
  if (cop_vlen_read() != 0) return 5;
  if (cop_vtype_read() != 2) return 6;

  if (cop_vtype_write(1) != 2) return 7;
  if (cop_vtype_read() != 0x80000000u) return 8;
  if (cop_vlen_read() != 0) return 9;

  return 0;
}
