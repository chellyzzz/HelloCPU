#include "trap.h"

#include <stdint.h>

volatile int trap_counter = 0;

void trap_handler(void) __attribute__((naked));

void trap_handler(void) {
  asm volatile(
      "csrr t0, mepc\n"
      "addi t0, t0, 4\n"
      "csrw mepc, t0\n"
      "la t0, trap_counter\n"
      "lw t1, 0(t0)\n"
      "addi t1, t1, 1\n"
      "sw t1, 0(t0)\n"
      "mret\n");
}

int main(void) {
  uintptr_t handler = (uintptr_t)trap_handler;
  asm volatile("csrw mtvec, %0" : : "r"(handler) : "memory");

  for (volatile int i = 0; i < 8; ++i) {
    asm volatile(
        "ecall\n"
        "addi zero, zero, 0\n"
        "addi zero, zero, 0\n"
        "addi zero, zero, 0\n"
        :
        :
        : "memory");
  }

  check(trap_counter == 8);
  return 0;
}
