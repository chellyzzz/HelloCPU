#include "trap.h"

#include <stdint.h>

static inline uint32_t mulh_u32(int32_t lhs, int32_t rhs) {
  uint32_t result;
  asm volatile("mulh %0, %1, %2" : "=r"(result) : "r"(lhs), "r"(rhs));
  return result;
}

static inline uint32_t mulhu_u32(uint32_t lhs, uint32_t rhs) {
  uint32_t result;
  asm volatile("mulhu %0, %1, %2" : "=r"(result) : "r"(lhs), "r"(rhs));
  return result;
}

static inline uint32_t mulhsu_u32(int32_t lhs, uint32_t rhs) {
  uint32_t result;
  asm volatile("mulhsu %0, %1, %2" : "=r"(result) : "r"(lhs), "r"(rhs));
  return result;
}

int main() {
  if (mulhu_u32(0x80000000u, 0x00000002u) != 0x00000001u)
    return 11;
  if (mulhu_u32(0xffffffffu, 0xffffffffu) != 0xfffffffeu)
    return 12;
  if (mulhu_u32(0x12345678u, 0x9abcdef0u) != 0x0b00ea4eu)
    return 13;

  if (mulh_u32((int32_t)0x80000000u, 2) != 0xffffffffu)
    return 21;
  if (mulh_u32(-1, -1) != 0x00000000u)
    return 22;
  if (mulh_u32(0x7fffffff, 0x7fffffff) != 0x3fffffffu)
    return 23;

  if (mulhsu_u32(-1, 0xffffffffu) != 0xffffffffu)
    return 31;
  if (mulhsu_u32((int32_t)0x80000000u, 2u) != 0xffffffffu)
    return 32;
  if (mulhsu_u32(0x7fffffff, 0xffffffffu) != 0x7ffffffeu)
    return 33;

  return 0;
}
