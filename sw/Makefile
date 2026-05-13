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
EMBENCH_DIR      = benchmark/embench-iot
EMBENCH_BUILD_DIR = $(BUILD_DIR)/embench
EMBENCH_CONFIG_DIR = $(EMBENCH_DIR)/examples/riscv32/ri5cyverilator
EMBENCH_SUBSET   = crc32 matmult-int nettle-aes nettle-sha256 ud edn md5sum

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

EMBENCH_CFLAGS = $(CFLAGS) -I$(EMBENCH_DIR)/support -I$(EMBENCH_CONFIG_DIR) \
		 -DWARMUP_HEAT=1 -DGLOBAL_SCALE_FACTOR=1 -DHAVE_BOARDSUPPORT_H

EMBENCH_COMMON_SRCS = start.S lib/klib.c \
	$(EMBENCH_DIR)/support/main.c \
	$(EMBENCH_DIR)/support/beebsc.c \
	$(EMBENCH_CONFIG_DIR)/boardsupport.c

benchmark: | $(BUILD_DIR)
	$(CC) $(CM_CFLAGS) $(LDFLAGS) start.S lib/klib.c $(CM_SRCS) -o $(BUILD_DIR)/coremark.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/coremark.elf $(BUILD_DIR)/coremark.bin
	$(OBJDUMP) -d $(BUILD_DIR)/coremark.elf > $(BUILD_DIR)/coremark.txt

$(BUILD_DIR) $(SCALAR_BUILD_DIR) $(VECTOR_BUILD_DIR):
	mkdir -p $@

$(EMBENCH_BUILD_DIR):
	mkdir -p $@

print-embench-subset:
	@echo $(EMBENCH_SUBSET)

embench-build: | $(EMBENCH_BUILD_DIR)
	@set -e; \
	benchmarks="$(if $(ALL),$(ALL),$(EMBENCH_SUBSET))"; \
	for b in $$benchmarks; do \
		echo "[embench-build] $$b"; \
		srcs="$$(find $(EMBENCH_DIR)/src/$$b -maxdepth 1 -name '*.c' | sort)"; \
		if [ -z "$$srcs" ]; then echo "Missing Embench sources for $$b"; exit 1; fi; \
		$(CC) $(EMBENCH_CFLAGS) $(LDFLAGS) $(EMBENCH_COMMON_SRCS) $$srcs -o $(EMBENCH_BUILD_DIR)/$$b.elf; \
		$(OBJCOPY) -O binary $(EMBENCH_BUILD_DIR)/$$b.elf $(EMBENCH_BUILD_DIR)/$$b.bin; \
		$(OBJDUMP) -d $(EMBENCH_BUILD_DIR)/$$b.elf > $(EMBENCH_BUILD_DIR)/$$b.txt; \
	done

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

.PHONY: all clean scalar-tests vector-tests benchmark embench-build print-embench-subset
