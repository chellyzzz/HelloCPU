#include "rvv_test_helpers.h"

static inline unsigned read_vl(void) {
  unsigned value;
  asm volatile ("csrr %0, 0xc20" : "=r"(value));
  return value;
}

static inline unsigned read_vtype(void) {
  unsigned value;
  asm volatile ("csrr %0, 0xc21" : "=r"(value));
  return value;
}

static inline unsigned read_vstart(void) {
  unsigned value;
  asm volatile ("csrr %0, 0x008" : "=r"(value));
  return value;
}

int main() {
  if (read_vl() != 0) return 1;
  if (read_vtype() != 0x80000000u) return 2;
  if (read_vstart() != 0) return 3;

  if (rvv_vsetivli_e8(4) != 4) return 4;
  if (read_vl() != 4) return 5;
  if (read_vtype() != 0) return 6;
  if (read_vstart() != 0) return 7;

  if (rvv_vsetivli_e32(1) != 1) return 8;
  if (read_vl() != 1) return 9;
  if (read_vtype() != 2) return 10;

  if (rvv_vsetivli_bad_lmul(4) != 4) return 11;
  if (read_vl() != 4) return 12;
  if (read_vtype() != 0x80000000u) return 13;
  if (read_vstart() != 0) return 14;

  return 0;
}
