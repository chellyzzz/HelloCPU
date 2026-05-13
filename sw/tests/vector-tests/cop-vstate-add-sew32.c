static inline unsigned cop_vlen_write(unsigned value) {
  unsigned result;
  asm volatile (".insn r 0x0b, 5, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(0));
  return result;
}

static inline unsigned cop_vtype_write(unsigned value) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 16, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(0));
  return result;
}

static inline unsigned cop_vstate_add(unsigned lhs, unsigned rhs) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 18, %0, %1, %2"
                : "=r"(result)
                : "r"(lhs), "r"(rhs));
  return result;
}

int main() {
  cop_vtype_write(2);
  cop_vlen_write(1);
  if (cop_vstate_add(0x12345678u, 0x11111111u) != 0x23456789u) return 1;

  cop_vlen_write(0);
  if (cop_vstate_add(0x12345678u, 0x11111111u) != 0) return 2;

  cop_vtype_write(1);
  cop_vlen_write(1);
  if (cop_vstate_add(0x12345678u, 0x11111111u) != 0x80000000u) return 3;

  return 0;
}
