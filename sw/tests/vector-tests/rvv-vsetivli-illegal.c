static inline unsigned rvv_vsetivli_e32(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 2"
                : "=r"(result)
                : "r"(avl));
  return result;
}

static inline unsigned rvv_vsetivli_bad_lmul(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 1"
                : "=r"(result)
                : "r"(avl));
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
  if (rvv_vsetivli_bad_lmul(3) != 3) return 1;
  if (cop_vtype_read() != 0x80000000u) return 2;
  if (cop_vstate_add(0x01020304u, 0x05060708u) != 0x80000000u) return 3;

  if (rvv_vsetivli_e32(4) != 4) return 4;
  if (cop_vtype_read() != 2) return 5;

  return 0;
}
