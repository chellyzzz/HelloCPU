ENTRY(_start)

MEMORY {
    dram : ORIGIN = 0x30000000, LENGTH = 64M
}

SECTIONS {
    . = ORIGIN(dram);

    .text : {
        *(.entry)
        *(.text*)
    } > dram

    .rodata : { *(.rodata*) } > dram
    .data   : { *(.data*) }   > dram
    .bss    : { *(.bss*) *(COMMON) } > dram

    . = ALIGN(16);
    _stack_top = . + 0x8000;
}
