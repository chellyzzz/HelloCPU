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
  unsigned reset_vtype = cop_vtype_read();
  if (reset_vtype != 0x80000000u) return 1;

  unsigned old8 = cop_vtype_write(0);
  if (old8 != 0x80000000u) return 2;
  if (cop_vtype_read() != 0) return 3;

  unsigned old32 = cop_vtype_write(2);
  if (old32 != 0) return 4;
  if (cop_vtype_read() != 2) return 5;

  return 0;
}
