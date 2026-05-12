CROSS   ?= riscv64-linux-gnu-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy
OBJDUMP  = $(CROSS)objdump

CFLAGS   = -march=rv32im_zicsr -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding \
           -fno-pic -fno-pie -I include -O2
LDFLAGS  = -T link.ld -static -Wl,--build-id=none

BUILD_DIR        = build
SCALAR_TEST_DIR  = tests/scalar-tests
VECTOR_TEST_DIR  = tests/vector-tests
SCALAR_BUILD_DIR = $(BUILD_DIR)/scalar
VECTOR_BUILD_DIR = $(BUILD_DIR)/vector

SCALAR_TESTS := $(basename $(notdir $(wildcard $(SCALAR_TEST_DIR)/*.c)))
VECTOR_TESTS := $(basename $(notdir $(wildcard $(VECTOR_TEST_DIR)/*.c)))

SCALAR_BINS := $(addprefix $(SCALAR_BUILD_DIR)/,$(addsuffix .bin,$(SCALAR_TESTS)))
VECTOR_BINS := $(addprefix $(VECTOR_BUILD_DIR)/,$(addsuffix .bin,$(VECTOR_TESTS)))

all: scalar-tests vector-tests

scalar-tests: $(SCALAR_BINS)

vector-tests: $(VECTOR_BINS)

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

$(BUILD_DIR)/coremark_iter$(ITER).stamp: $(CM_SRCS) start.S lib/klib.c link.ld | $(BUILD_DIR)
	$(CC) $(CM_CFLAGS) $(LDFLAGS) start.S lib/klib.c $(CM_SRCS) -o $(BUILD_DIR)/coremark.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/coremark.elf $(BUILD_DIR)/coremark.bin
	$(OBJDUMP) -d $(BUILD_DIR)/coremark.elf > $(BUILD_DIR)/coremark.txt
	@touch $@

$(BUILD_DIR)/coremark.bin: $(BUILD_DIR)/coremark_iter$(ITER).stamp

.PRECIOUS: $(BUILD_DIR)/coremark_iter%.stamp
	$(CC) $(CM_CFLAGS) $(LDFLAGS) start.S lib/klib.c $(CM_SRCS) -o $(BUILD_DIR)/coremark.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/coremark.elf $@
	$(OBJDUMP) -d $(BUILD_DIR)/coremark.elf > $(BUILD_DIR)/coremark.txt

$(BUILD_DIR) $(SCALAR_BUILD_DIR) $(VECTOR_BUILD_DIR):
	mkdir -p $@


$(SCALAR_BUILD_DIR)/%.bin: $(SCALAR_TEST_DIR)/%.c start.S lib/klib.c link.ld | $(SCALAR_BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) start.S lib/klib.c $< -o $(SCALAR_BUILD_DIR)/$*.elf
	$(OBJCOPY) -O binary $(SCALAR_BUILD_DIR)/$*.elf $@
	$(OBJDUMP) -d $(SCALAR_BUILD_DIR)/$*.elf > $(SCALAR_BUILD_DIR)/$*.txt

$(VECTOR_BUILD_DIR)/%.bin: $(VECTOR_TEST_DIR)/%.c start.S lib/klib.c link.ld | $(VECTOR_BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) start.S lib/klib.c $< -o $(VECTOR_BUILD_DIR)/$*.elf
	$(OBJCOPY) -O binary $(VECTOR_BUILD_DIR)/$*.elf $@
	$(OBJDUMP) -d $(VECTOR_BUILD_DIR)/$*.elf > $(VECTOR_BUILD_DIR)/$*.txt

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean scalar-tests vector-tests
