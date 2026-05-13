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

.PHONY: all sim sw clean run_% run_all bench bench_only branch_trace predictor_sim ifu_idu_backpressure exu_wbu_flush exu_result_visibility cop_backend_flush idu_cop_regs commit_visible_ctrl ifu_fetch_queue top_fetch_queue_flush top_pc_update_flush cop_mem_pending_kill cop_mem_store_directed cop_mem_store_kill cop_vtype_kill backend_contract_checks

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

exu_wbu_flush:
	$(VERILATOR) --top-module hcpu_exu_wbu_regs --cc --exe --build -Wno-fatal -Wno-style \
		vsrc/cpu/exu/exu_wbu_regs.v $(abspath $(SIM_DIR)/exu_wbu_flush_tb.cpp) \
		--Mdir $(BUILD_DIR)/exu_wbu_flush_tb \
		-o $(abspath $(BUILD_DIR)/Vexu_wbu_flush_tb)
	@$(BUILD_DIR)/Vexu_wbu_flush_tb

exu_result_visibility:
	$(VERILATOR) --top-module hcpu_EXU --cc --exe --build -Wno-fatal -Wno-style +incdir+vsrc/cpu/include \
		vsrc/vector/cop/dummy_coprocessor.v vsrc/vector/cop/vector_cop_decode.v vsrc/vector/cop/vector_lane_alu.v \
		vsrc/cpu/exu/divider.v vsrc/cpu/exu/multiplier.v vsrc/cpu/exu/alu.v vsrc/cpu/exu/lsu.v vsrc/cpu/exu/exu.v \
		$(abspath $(SIM_DIR)/exu_result_visibility_tb.cpp) \
		--Mdir $(BUILD_DIR)/exu_result_visibility_tb \
		-o $(abspath $(BUILD_DIR)/Vexu_result_visibility_tb)
	@$(BUILD_DIR)/Vexu_result_visibility_tb

cop_backend_flush:
	$(VERILATOR) --top-module hcpu_cop_backend --cc --exe --build -Wno-fatal -Wno-style \
		vsrc/vector/cop/cop_backend.v vsrc/vector/cop/dummy_coprocessor.v vsrc/vector/cop/vector_cop_decode.v vsrc/vector/cop/vector_lane_alu.v \
		$(abspath $(SIM_DIR)/cop_backend_flush_tb.cpp) \
		--Mdir $(BUILD_DIR)/cop_backend_flush_tb \
		-o $(abspath $(BUILD_DIR)/Vcop_backend_flush_tb)
	@$(BUILD_DIR)/Vcop_backend_flush_tb

idu_cop_regs:
	$(VERILATOR) --top-module hcpu_idu_cop_regs --cc --exe --build -Wno-fatal -Wno-style \
		vsrc/vector/cop/idu_cop_regs.v $(abspath $(SIM_DIR)/idu_cop_regs_tb.cpp) \
		--Mdir $(BUILD_DIR)/idu_cop_regs_tb \
		-o $(abspath $(BUILD_DIR)/Vidu_cop_regs_tb)
	@$(BUILD_DIR)/Vidu_cop_regs_tb

commit_visible_ctrl:
	$(VERILATOR) --top-module hcpu_commit_visible_ctrl --cc --exe --build -Wno-fatal -Wno-style \
		vsrc/cpu/top/commit_visible_ctrl.v $(abspath $(SIM_DIR)/commit_visible_ctrl_tb.cpp) \
		--Mdir $(BUILD_DIR)/commit_visible_ctrl_tb \
		-o $(abspath $(BUILD_DIR)/Vcommit_visible_ctrl_tb)
	@$(BUILD_DIR)/Vcommit_visible_ctrl_tb

ifu_fetch_queue:
	$(VERILATOR) --top-module hcpu_ifu_fetch_queue --cc --exe --build -Wno-fatal -Wno-style \
		vsrc/cpu/ifu/ifu_fetch_queue.v $(abspath $(SIM_DIR)/ifu_fetch_queue_tb.cpp) \
		--Mdir $(BUILD_DIR)/ifu_fetch_queue_tb \
		-o $(abspath $(BUILD_DIR)/Vifu_fetch_queue_tb)
	@$(BUILD_DIR)/Vifu_fetch_queue_tb

top_fetch_queue_flush: sim sw
	$(VERILATOR) --top-module $(TOPNAME) +incdir+vsrc/cpu/include --cc --exe --build -O3 -Wno-fatal -Wno-style --timescale "1ns/1ns" --no-timing -j 8 \
		$(VSRCS) $(abspath $(SIM_DIR)/top_fetch_queue_flush_tb.cpp) \
		--Mdir $(BUILD_DIR)/top_fetch_queue_flush_tb \
		-o $(abspath $(BUILD_DIR)/Vtop_fetch_queue_flush_tb)
	@$(BUILD_DIR)/Vtop_fetch_queue_flush_tb $(if $(IMG),$(IMG),$(SW_DIR)/build/scalar/btb-collision.bin)

top_pc_update_flush: sim sw
	$(VERILATOR) --top-module $(TOPNAME) +incdir+vsrc/cpu/include --cc --exe --build -O3 -Wno-fatal -Wno-style --timescale "1ns/1ns" --no-timing -j 8 \
		$(VSRCS) $(abspath $(SIM_DIR)/top_fetch_queue_flush_tb.cpp) \
		--Mdir $(BUILD_DIR)/top_pc_update_flush_tb \
		-o $(abspath $(BUILD_DIR)/Vtop_pc_update_flush_tb)
	@$(BUILD_DIR)/Vtop_pc_update_flush_tb $(if $(IMG),$(IMG),$(SW_DIR)/build/scalar/pc-update-ecall.bin) --pc-update

cop_mem_pending_kill: sw
	$(VERILATOR) --top-module cop_mem_pending_kill_top +incdir+vsrc/cpu/include --cc --exe --build -Wno-fatal -Wno-style \
		--timescale "1ns/1ns" --no-timing \
		"+define+COP_MEM_PENDING_KILL_TB" \
		$(EXTRA_VERILATOR_FLAGS) \
		$(SIM_DIR)/cop_mem_pending_kill_top.v $(SIM_DIR)/axi_ram.v $(shell find -L vsrc -name "*.v" -o -name "*.sv" 2>/dev/null) \
		$(abspath $(SIM_DIR)/cop_mem_pending_kill_tb.cpp) \
		--Mdir $(BUILD_DIR)/cop_mem_pending_kill_tb \
		-o $(abspath $(BUILD_DIR)/Vcop_mem_pending_kill_tb)
	@$(BUILD_DIR)/Vcop_mem_pending_kill_tb $(SW_DIR)/build/vector/cop-vload-repeat-mem.bin

cop_mem_store_directed: sw
	$(VERILATOR) --top-module cop_mem_pending_kill_top +incdir+vsrc/cpu/include --cc --exe --build -Wno-fatal -Wno-style \
		--timescale "1ns/1ns" --no-timing \
		"+define+COP_MEM_PENDING_KILL_TB" \
		$(EXTRA_VERILATOR_FLAGS) \
		$(SIM_DIR)/cop_mem_pending_kill_top.v $(SIM_DIR)/axi_ram.v $(shell find -L vsrc -name "*.v" -o -name "*.sv" 2>/dev/null) \
		$(abspath $(SIM_DIR)/cop_mem_store_tb.cpp) \
		--Mdir $(BUILD_DIR)/cop_mem_store_tb \
		-o $(abspath $(BUILD_DIR)/Vcop_mem_store_tb)
	@$(BUILD_DIR)/Vcop_mem_store_tb $(SW_DIR)/build/vector/cop-vstore-mem.bin

cop_mem_store_kill: sw
	$(VERILATOR) --top-module cop_mem_pending_kill_top +incdir+vsrc/cpu/include --cc --exe --build -Wno-fatal -Wno-style \
		--timescale "1ns/1ns" --no-timing \
		"+define+COP_MEM_PENDING_KILL_TB" \
		$(EXTRA_VERILATOR_FLAGS) \
		$(SIM_DIR)/cop_mem_pending_kill_top.v $(SIM_DIR)/axi_ram.v $(shell find -L vsrc -name "*.v" -o -name "*.sv" 2>/dev/null) \
		$(abspath $(SIM_DIR)/cop_mem_store_kill_tb.cpp) \
		--Mdir $(BUILD_DIR)/cop_mem_store_kill_tb \
		-o $(abspath $(BUILD_DIR)/Vcop_mem_store_kill_tb)
	@$(BUILD_DIR)/Vcop_mem_store_kill_tb $(SW_DIR)/build/vector/cop-vstore-repeat-mem.bin

cop_vtype_kill:
	$(VERILATOR) --top-module hcpu_cop_backend --cc --exe --build -Wno-fatal -Wno-style \
		$(EXTRA_VERILATOR_FLAGS) \
		vsrc/vector/cop/cop_backend.v vsrc/vector/cop/dummy_coprocessor.v vsrc/vector/cop/vector_cop_decode.v vsrc/vector/cop/vector_lane_alu.v \
		$(abspath $(SIM_DIR)/cop_backend_vtype_flush_tb.cpp) \
		--Mdir $(BUILD_DIR)/cop_backend_vtype_flush_tb \
		-o $(abspath $(BUILD_DIR)/Vcop_backend_vtype_flush_tb)
	@$(BUILD_DIR)/Vcop_backend_vtype_flush_tb

backend_contract_checks: exu_wbu_flush exu_result_visibility cop_backend_flush idu_cop_regs commit_visible_ctrl ifu_idu_backpressure

# Wave for debugging
wave:
	gtkwave wave.vcd

clean:
	rm -rf $(BUILD_DIR) wave.vcd
	$(MAKE) -C $(SW_DIR) clean
