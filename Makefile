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
VERILATOR_FLAGS += +incdir+vsrc/cpu/include
VERILATOR_FLAGS += --cc --exe --build --trace
VERILATOR_FLAGS += -O3 --x-assign fast --x-initial fast
VERILATOR_FLAGS += -Wno-fatal -Wno-style
VERILATOR_FLAGS += --timescale "1ns/1ns" --no-timing
VERILATOR_FLAGS += -j 8
VERILATOR_FLAGS += "+define+PERF_COUNTERS"
VERILATOR_FLAGS += "+define+PERF_INST_MIX"
VERILATOR_FLAGS += "+define+PERF_STALL"
VERILATOR_FLAGS += "+define+PERF_BUS"
VERILATOR_FLAGS += "+define+PERF_CACHE"
VERILATOR_FLAGS += "+define+PERF_BRANCH_PRED"
VERILATOR_FLAGS += $(EXTRA_VERILATOR_FLAGS)

# Tests
SCALAR_TESTS := $(basename $(notdir $(wildcard $(SW_DIR)/tests/scalar-tests/*.c)))
VECTOR_TESTS := $(basename $(notdir $(wildcard $(SW_DIR)/tests/vector-tests/*.c)))

# === Targets ===

.PHONY: all sim sw clean run_% run_all bench bench_only branch_trace predictor_sim ifu_idu_backpressure cop_mem_pending_kill

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
	for t in $(SCALAR_TESTS); do \
		echo "=== scalar/$$t ==="; \
		$(BUILD_DIR)/V$(TOPNAME) $(SW_DIR)/build/scalar/$$t.bin; \
		if [ $$? -eq 0 ]; then pass=$$((pass+1)); else fail=$$((fail+1)); fi; \
	done; \
	for t in $(VECTOR_TESTS); do \
		echo "=== vector/$$t ==="; \
		$(BUILD_DIR)/V$(TOPNAME) $(SW_DIR)/build/vector/$$t.bin; \
		if [ $$? -eq 0 ]; then pass=$$((pass+1)); else fail=$$((fail+1)); fi; \
	done; \
	echo ""; echo "Results: $$pass passed, $$fail failed"
else
run: sim sw
	@echo "=== Running test: $(ALL) ==="
	@if [ -f "$(SW_DIR)/build/scalar/$(ALL).bin" ]; then \
		$(BUILD_DIR)/V$(TOPNAME) $(SW_DIR)/build/scalar/$(ALL).bin; \
	elif [ -f "$(SW_DIR)/build/vector/$(ALL).bin" ]; then \
		$(BUILD_DIR)/V$(TOPNAME) $(SW_DIR)/build/vector/$(ALL).bin; \
	else \
		echo "Unknown test: $(ALL)"; exit 1; \
	fi
endif

# Run benchmark
#   make bench               → ITERATIONS=1 (quick functional check)
#   make bench ITER=100       → standard performance run
#   make bench_only ITER=200   → without rebuilding all tests
ITER ?= 1
TRACE ?= branch_trace.log
POLICY ?= current

bench: sim sw
	$(MAKE) -C $(SW_DIR) benchmark ITER=$(ITER)
	@echo "=== CoreMark (ITER=$(ITER)) ==="
	@$(BUILD_DIR)/V$(TOPNAME) $(SW_DIR)/build/coremark.bin

# Run benchmark without rebuilding all tests
bench_only: sim
	$(MAKE) -C $(SW_DIR) benchmark ITER=$(ITER)
	@echo "=== CoreMark (ITER=$(ITER)) ==="
	@$(BUILD_DIR)/V$(TOPNAME) $(SW_DIR)/build/coremark.bin

branch_trace: sim
	$(MAKE) -C $(SW_DIR) benchmark ITER=$(ITER)
	@echo "=== Branch trace (ITER=$(ITER)) ==="
	@$(BUILD_DIR)/V$(TOPNAME) $(SW_DIR)/build/coremark.bin --branch-trace=$(TRACE)

predictor_sim:
	python3 tools/predictor_sim/predictor_sim.py --trace $(TRACE) --policy $(POLICY) $(ARGS)

ifu_idu_backpressure:
	$(VERILATOR) --top-module hcpu_ifu_idu_regs --cc --exe --build -Wno-fatal -Wno-style \
		vsrc/cpu/ifu/ifu_idu_regs.v $(abspath $(SIM_DIR)/ifu_idu_regs_backpressure_tb.cpp) \
		--Mdir $(BUILD_DIR)/ifu_idu_regs_tb \
		-o $(abspath $(BUILD_DIR)/Vifu_idu_regs_tb)
	@$(BUILD_DIR)/Vifu_idu_regs_tb

cop_mem_pending_kill: sw
	$(VERILATOR) --top-module cop_mem_pending_kill_top +incdir+vsrc/cpu/include --cc --exe --build -Wno-fatal -Wno-style \
		--timescale "1ns/1ns" --no-timing \
		"+define+COP_MEM_PENDING_KILL_TB" \
		$(SIM_DIR)/cop_mem_pending_kill_top.v $(SIM_DIR)/axi_ram.v $(shell find -L vsrc -name "*.v" -o -name "*.sv" 2>/dev/null) \
		$(abspath $(SIM_DIR)/cop_mem_pending_kill_tb.cpp) \
		--Mdir $(BUILD_DIR)/cop_mem_pending_kill_tb \
		-o $(abspath $(BUILD_DIR)/Vcop_mem_pending_kill_tb)
	@$(BUILD_DIR)/Vcop_mem_pending_kill_tb $(SW_DIR)/build/vector/cop-vload-repeat-mem.bin

# Wave for debugging
wave:
	gtkwave wave.vcd

clean:
	rm -rf $(BUILD_DIR) wave.vcd
	$(MAKE) -C $(SW_DIR) clean
