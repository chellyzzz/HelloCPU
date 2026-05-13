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
  if (cop_vtype_write(0) != 0x80000000u) return 1;
  if (cop_vtype_read() != 0) return 2;

  if (cop_vtype_write(1) != 0) return 3;
  if (cop_vtype_read() != 0x80000000u) return 4;

  if (cop_vtype_write(8) != 0x80000000u) return 5;
  if (cop_vtype_read() != 0x80000000u) return 6;

  if (cop_vtype_write(2) != 0x80000000u) return 7;
  if (cop_vtype_read() != 2) return 8;

  return 0;
}
