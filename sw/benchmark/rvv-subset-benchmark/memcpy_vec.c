#include "rvv_benchmark_helpers.h"

static unsigned src = 0xa1b2c3d4u;
static unsigned dst;

int main() {
  if (rvv_vsetivli_e8(4) != 4) return 1;

  rvv_vle8_v1((unsigned)&src);
  rvv_vse8_v1((unsigned)&dst);

  if (dst != 0xa1b2c3d4u) return 2;
  return 0;
}
