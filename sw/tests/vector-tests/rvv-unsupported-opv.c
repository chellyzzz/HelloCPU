static inline unsigned unsupported_opv_preserves(unsigned value) {
  register unsigned result asm("a0") = value;
  asm volatile (".word 0x00000557"
                : "+r"(result)
                :
                : "memory");
  return result;
}

int main() {
  if (unsupported_opv_preserves(0x12345678u) != 0x12345678u) return 1;
  return 0;
}
