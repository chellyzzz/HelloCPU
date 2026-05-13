static inline unsigned cop_vload_mem(unsigned base) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 14, %0, %1, %2"
                : "=r"(result)
                : "r"(base), "r"(0)
                : "memory");
  return result;
}

static inline unsigned cop_vstore_mem(unsigned base) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 15, %0, %1, %2"
                : "=r"(result)
                : "r"(base), "r"(0)
                : "memory");
  return result;
}

static unsigned src = 0x1234abcdu;
static unsigned dst;

int main() {
  unsigned loaded = cop_vload_mem((unsigned)&src);
  unsigned stored = cop_vstore_mem((unsigned)&dst);

  if (loaded != 0x1234abcdu) return 1;
  if (stored != 0x1234abcdu) return 2;
  if (dst != 0x1234abcdu) return 3;
  return 0;
}
