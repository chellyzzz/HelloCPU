#include "rvv_benchmark_helpers.h"

static unsigned lhs = 0x10203040u;
static unsigned dst;

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;

  rvv_vle8_v1((unsigned)&lhs);
  rvv_debug_vrf_write(0x01020304u, 2);
  rvv_vxor_v1_v1_v2();
  rvv_vse8_v1((unsigned)&dst);

  if (dst != 0x11223344u) return 2;
  return 0;
}
