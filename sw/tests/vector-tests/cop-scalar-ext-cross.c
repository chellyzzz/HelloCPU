static inline unsigned cop_add(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_sub(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 1, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_mul(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 2, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_vadd8(unsigned a, unsigned b) {
  unsigned result;
  asm volatile (".insn r 0x0b, 1, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(a), "r"(b));
  return result;
}

static inline unsigned cop_vlen_write(unsigned v) {
  unsigned result;
  asm volatile (".insn r 0x0b, 5, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(v), "r"(0));
  return result;
}

static inline unsigned cop_vlen_read(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 6, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

static inline unsigned cop_opcount(void) {
  unsigned result;
  asm volatile (".insn r 0x0b, 7, 0, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(0));
  return result;
}

int main() {
  cop_vlen_write(4);
  unsigned a = cop_add(100, 200);
  unsigned b = cop_sub(a, 50);
  unsigned c = cop_mul(b, 3);
  unsigned d = cop_vadd8(0x01020304u, 0x05060708u);
  unsigned vl = cop_vlen_read();
  unsigned oc = cop_opcount();
  if (a != 300) return 1;
  if (b != 250) return 2;
  if (c != 750) return 3;
  if (d != 0x06080a0cu) return 4;
  if (vl != 4) return 5;
  if (oc != 6) return 6;
  return 0;
}
