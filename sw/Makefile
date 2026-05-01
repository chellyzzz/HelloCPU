CROSS   ?= riscv64-linux-gnu-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy
OBJDUMP  = $(CROSS)objdump

CFLAGS   = -march=rv32im_zicsr -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding \
           -fno-pic -fno-pie -I include -O2
LDFLAGS  = -T link.ld -static -Wl,--build-id=none

BUILD_DIR = build
TESTS    := $(basename $(notdir $(wildcard tests/*.c)))

all: $(addprefix $(BUILD_DIR)/,$(addsuffix .bin,$(TESTS)))

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/%.bin: tests/%.c start.S lib/klib.c link.ld | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) start.S lib/klib.c $< -o $(BUILD_DIR)/$*.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/$*.elf $@
	$(OBJDUMP) -d $(BUILD_DIR)/$*.elf > $(BUILD_DIR)/$*.txt

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean