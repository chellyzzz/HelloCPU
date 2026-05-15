#include "rvv_benchmark_helpers.h"

static unsigned src = 0x04030201u;
static unsigned dst;

int main() {
  if (rvv_vsetvli_e8(4) != 4) return 1;

  rvv_vle8_v1((unsigned)&src);
  rvv_vmsltu_vx_v0_v1(3u);
  rvv_vmerge_vxm_v1_v1_x0();
  rvv_vse8_v1((unsigned)&dst);

  if (dst != 0x04030000u) return 2;
  return 0;
}
