.section .entry, "ax"
.globl _start
_start:
    la sp, _stack_top
    jal main
    # Write exit code (a0) to HALT_ADDR
    li t0, 0x10000004
    sw a0, 0(t0)
    # Fallback: ebreak
1:  ebreak
    j 1b
