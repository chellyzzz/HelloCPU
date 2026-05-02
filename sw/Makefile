CROSS   ?= riscv64-linux-gnu-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy
OBJDUMP  = $(CROSS)objdump

CFLAGS   = -march=rv32im_zicsr -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding \
           -fno-pic -fno-pie -I include -O2
LDFLAGS  = -T link.ld -static -Wl,--build-id=none

BUILD_DIR = build
TESTS    := $(basename $(notdir $(wildcard tests/cpu-tests/*.c)))

all: $(addprefix $(BUILD_DIR)/,$(addsuffix .bin,$(TESTS)))

# CoreMark benchmark
CM_DIR   = benchmark/coremark
CM_PORT  = $(CM_DIR)/portme
CM_SRCS  = $(CM_DIR)/core_main.c $(CM_DIR)/core_list_join.c $(CM_DIR)/core_matrix.c \
           $(CM_DIR)/core_state.c $(CM_DIR)/core_util.c \
           $(CM_PORT)/core_portme.c $(CM_PORT)/ee_printf.c
ITER    ?= 1

CM_CFLAGS = $(CFLAGS) -I$(CM_DIR) -I$(CM_PORT) \
            -DPERFORMANCE_RUN=1 -DITERATIONS=$(ITER) \
            -DCOMPILER_FLAGS=\"rv32im_zicsr_-O2\"

benchmark: $(BUILD_DIR)/coremark.bin

$(BUILD_DIR)/coremark.bin: $(CM_SRCS) start.S lib/klib.c link.ld | $(BUILD_DIR)
	$(CC) $(CM_CFLAGS) $(LDFLAGS) start.S lib/klib.c $(CM_SRCS) -o $(BUILD_DIR)/coremark.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/coremark.elf $@
	$(OBJDUMP) -d $(BUILD_DIR)/coremark.elf > $(BUILD_DIR)/coremark.txt

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/%.bin: tests/cpu-tests/%.c start.S lib/klib.c link.ld | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) start.S lib/klib.c $< -o $(BUILD_DIR)/$*.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/$*.elf $@
	$(OBJDUMP) -d $(BUILD_DIR)/$*.elf > $(BUILD_DIR)/$*.txt

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean