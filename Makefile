# HelloCPU - Minimal CPU verification environment
SHELL = /bin/bash

# Directories
SIM_DIR  = sim
SW_DIR   = sw
BUILD_DIR = build

# Verilator
VERILATOR = verilator
TOPNAME   = sim_top

# Find all CPU verilog sources (via symlinks)
VSRCS  = $(SIM_DIR)/sim_top.v $(SIM_DIR)/axi_ram.v
VSRCS += $(shell find -L vsrc -name "*.v" -o -name "*.sv" 2>/dev/null)

VERILATOR_FLAGS  = --top-module $(TOPNAME)
VERILATOR_FLAGS += +incdir+vsrc/include
VERILATOR_FLAGS += --cc --exe --build --trace
VERILATOR_FLAGS += -O3 --x-assign fast --x-initial fast
VERILATOR_FLAGS += -Wno-fatal -Wno-style
VERILATOR_FLAGS += --timescale "1ns/1ns" --no-timing
VERILATOR_FLAGS += -j 8

# Tests
TESTS := $(basename $(notdir $(wildcard $(SW_DIR)/tests/cpu-tests/*.c)))

# === Targets ===

.PHONY: all sim sw clean run_% run_all

all: sim sw

# Build Verilator simulation
sim: $(BUILD_DIR)/V$(TOPNAME)

$(BUILD_DIR)/V$(TOPNAME): $(VSRCS) $(SIM_DIR)/sim_main.cpp
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) \
		$(VSRCS) $(abspath $(SIM_DIR)/sim_main.cpp) \
		--Mdir $(BUILD_DIR)/obj_dir \
		-o $(abspath $(BUILD_DIR)/V$(TOPNAME))

# Build all software tests
sw:
	$(MAKE) -C $(SW_DIR)

# Run tests
#   make run             → run all tests
#   make run ALL=<name>  → run single test (e.g. make run ALL=add)
ifeq ($(ALL),)
run: sim sw
	@pass=0; fail=0; \
	for t in $(TESTS); do \
		echo "=== $$t ==="; \
		$(BUILD_DIR)/V$(TOPNAME) $(SW_DIR)/build/$$t.bin; \
		if [ $$? -eq 0 ]; then pass=$$((pass+1)); else fail=$$((fail+1)); fi; \
	done; \
	echo ""; echo "Results: $$pass passed, $$fail failed"
else
run: sim sw
	@echo "=== Running test: $(ALL) ==="
	@$(BUILD_DIR)/V$(TOPNAME) $(SW_DIR)/build/$(ALL).bin
endif

# Wave for debugging
wave:
	gtkwave wave.vcd

clean:
	rm -rf $(BUILD_DIR) wave.vcd
	$(MAKE) -C $(SW_DIR) clean
