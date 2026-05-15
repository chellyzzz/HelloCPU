#include "rvv_benchmark_helpers.h"

static unsigned lhs = 0x01020304u;
static unsigned dst;

int main() {
  if (rvv_vsetivli_e32(1) != 1) return 1;

  rvv_vle32_v1((unsigned)&lhs);
  rvv_debug_vrf_write(0x10101010u, 2);
  rvv_vadd_v1_v1_v2();
  rvv_vse32_v1((unsigned)&dst);

  if (dst != 0x11121314u) return 2;
  return 0;
}
