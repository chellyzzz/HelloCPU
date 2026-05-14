static inline unsigned rvv_vsetivli_e8(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 0"
                : "=r"(result)
                : "r"(avl));
  return result;
}

static inline unsigned rvv_vsetivli_e32(unsigned avl) {
  unsigned result;
  asm volatile (".insn i 0x57, 7, %0, %1, 2"
                : "=r"(result)
                : "r"(avl));
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

int main() {
  if (rvv_vsetivli_e8(8) != 4) return 1;
  if (cop_vlen_read() != 4) return 2;
  if (cop_vtype_read() != 0) return 3;

  if (rvv_vsetivli_e32(1) != 1) return 4;
  if (cop_vlen_read() != 1) return 5;
  if (cop_vtype_read() != 2) return 6;

  return 0;
}
