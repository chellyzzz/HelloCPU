static inline unsigned cop_vload(unsigned value, unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 3, %0, %1, %2"
                : "=r"(result)
                : "r"(value), "r"(idx));
  return result;
}

static inline unsigned cop_vstore(unsigned idx) {
  unsigned result;
  asm volatile (".insn r 0x0b, 0, 4, %0, %1, %2"
                : "=r"(result)
                : "r"(0), "r"(idx));
  return result;
}

int main() {
  unsigned old0 = cop_vload(0x11223344u, 0);
  unsigned old1 = cop_vload(0xaabbccddu, 1);
  unsigned rd0 = cop_vstore(0);
  unsigned rd1 = cop_vstore(1);
  if (old0 != 0) return 1;
  if (old1 != 0) return 2;
  if (rd0 != 0x11223344u) return 3;
  if (rd1 != 0xaabbccddu) return 4;
  return 0;
}
