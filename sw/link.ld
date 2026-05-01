ENTRY(_start)

MEMORY {
    flash : ORIGIN = 0x30000000, LENGTH = 64M
}

SECTIONS {
    . = ORIGIN(flash);

    .text : {
        *(.entry)
        *(.text*)
    } > flash

    .rodata : { *(.rodata*) } > flash
    .data   : { *(.data*) }   > flash
    .bss    : { *(.bss*) *(COMMON) } > flash

    . = ALIGN(16);
    _stack_top = . + 0x8000;
}
