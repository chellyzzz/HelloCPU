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
  if (cop_vstate_add(0x01020304u, 0x05060708u) != 0x80000000u) return 1;

  cop_vtype_write(0);
  cop_vlen_write(2);
  if (cop_vstate_add(0x01020304u, 0x05060708u) != 0x00000a0cu) return 2;

  cop_vlen_write(4);
  if (cop_vstate_add(0x01020304u, 0x05060708u) != 0x06080a0cu) return 3;

  cop_vlen_write(0);
  if (cop_vstate_add(0x01020304u, 0x05060708u) != 0) return 4;

  return 0;
}
