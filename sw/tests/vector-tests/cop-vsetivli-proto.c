static inline unsigned cop_vsetivli_proto(unsigned avl, unsigned vtypei) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 19, %0, %1, %2"
                : "=r"(result)
                : "r"(avl), "r"(vtypei));
  return result;
}

static inline unsigned cop_vlen_read(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 6, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_vtype_read(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 17, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
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
  if (cop_vsetivli_proto(8, 0) != 4) return 1;
  if (cop_vlen_read() != 4) return 2;
  if (cop_vtype_read() != 0) return 3;
  if (cop_vstate_add(0x01020304u, 0x05060708u) != 0x06080a0cu) return 4;

  if (cop_vsetivli_proto(1, 2) != 1) return 5;
  if (cop_vlen_read() != 1) return 6;
  if (cop_vtype_read() != 2) return 7;
  if (cop_vstate_add(0x12345678u, 0x11111111u) != 0x23456789u) return 8;

  if (cop_vsetivli_proto(3, 1) != 3) return 9;
  if (cop_vlen_read() != 3) return 10;
  if (cop_vtype_read() != 0x80000000u) return 11;
  if (cop_vstate_add(0x01020304u, 0x05060708u) != 0x80000000u) return 12;

  return 0;
}
