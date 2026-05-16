# HelloCPU

HelloCPU is a small RV32IM + Zicsr CPU project with a Verilator-based simulation and bare-metal software test environment. The current core is a five-stage in-order pipeline with instruction/data caches, AXI interconnect, performance counters, and a working BTB + RAS + static JAL branch prediction path.

## Current Status

| Item | Status |
|------|--------|
| ISA | RV32IM + Zicsr |
| Pipeline | IFU -> IDU -> EXU -> WBU -> Register File |
| Caches | 4 KB ICache + 4 KB DCache |
| Branch prediction | 128-entry BTB, 8-entry RAS, static JAL prediction |
| CPU tests | `48 passed, 0 failed` |
| CoreMark ITER=1 | Correct CRC, `2.046 CoreMark/MHz` |
| CoreMark ITER=100 | Correct CRC, `2.381 CoreMark/MHz` |

Latest validated commands:

```bash
make run
make -C sw benchmark ITER=1 -B
./build/Vsim_top sw/build/coremark.bin --max-cycles=100000000
```

Latest CoreMark ITER=100 result:

```text
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x988c
Correct operation validated.
Total cycles     : 41981715
CoreMark/MHz     : 2.381
[HelloCPU] PASS (cycles: 41986504)
```

## Repository Layout

| Path | Purpose |
|------|---------|
| `vsrc/cpu/` | CPU RTL source code |
| `vsrc/vector/` | Vector/COP backend RTL source code |
| `sim/` | Verilator top, AXI RAM model, C++ simulator |
| `sw/` | Bare-metal runtime, tests, CoreMark benchmark |
| `docs/` | Design notes, microarchitecture, benchmark records |
| `build/` | Generated Verilator build output |

## Build And Run

### Build Simulator And Tests

```bash
make all
```

### macOS Toolchain

On macOS, install Homebrew if needed and then install the simulator and bare-metal
RISC-V toolchain:

```bash
brew install verilator riscv64-elf-gcc
```

The software build defaults to the `riscv64-elf-` prefix on Darwin. Verify the
host and target toolchain with:

```bash
make toolchain-check
```

If Homebrew is not on your `PATH`, make sure `/opt/homebrew/bin` is available in
the shell you use for builds.

### Run All CPU Tests

```bash
make run
```

### Run One CPU Test

```bash
make run ALL=quick-sort
```

### Run CoreMark

```bash
make bench ITER=1
make bench ITER=100
```

For a forced CoreMark rebuild:

```bash
make -C sw benchmark ITER=1 -B
./build/Vsim_top sw/build/coremark.bin --max-cycles=100000000
```

### Debug Options

```bash
./build/Vsim_top sw/build/add.bin --wave
./build/Vsim_top sw/build/coremark.bin --commit-trace=commit.trace
./build/Vsim_top sw/build/coremark.bin --mem-trace=mem.trace
```

`--wave` writes `wave.vcd`. Trace options are intended for architectural debugging and are not required for normal runs.

## Simulation Environment

The simulator loads a raw binary into a 64 MB memory model at `0x30000000`. RTL accesses memory through the AXI RAM model, which calls C++ DPI-C memory helpers.

| Address | Purpose |
|---------|---------|
| `0x10000000` | UART TX byte output |
| `0x10000004` | Simulation halt MMIO |
| `0x30000000` to `0x33ffffff` | Main memory |

The software runtime starts in `sw/start.S`, uses `sw/link.ld`, and exits by writing an exit code to `0x10000004`.

## Performance Counters

Performance counters are controlled by Verilator defines in `Makefile`:

```makefile
+define+PERF_COUNTERS
+define+PERF_INST_MIX
+define+PERF_STALL
+define+PERF_BUS
+define+PERF_CACHE
+define+PERF_BRANCH_PRED
```

The simulator prints instruction mix, IPC, stalls, cache statistics, bus transactions, branch predictor statistics, and commit PC hotspots at the end of each run.

## Key Documents

| Document | Purpose |
|----------|---------|
| `docs/cpu/microarchitecture.md` | CPU pipeline, execution units, caches, buses, CSRs |
| `docs/cpu/cpu-evolution-roadmap.md` | CPU optimization roadmap toward cleaner execution and memory boundaries |
| `docs/cpu/cpu-design-plan.md` | CPU-focused design plan, priorities, and staged milestones |
| `docs/interface/vector-coprocessor-interface.md` | Current CPU/vector coprocessor interface and control semantics |
| `docs/interface/cpu-vector-development-plan.md` | Joint CPU/vector development plan and milestones |
| `docs/interface/cpu-vector-coproc-handoff.md` | Current CPU/vector handoff status |
| `docs/vector/vector-coprocessor-microarchitecture.md` | Current vector backend microarchitecture status |
| `docs/vector/vector-coprocessor-stages.md` | Vector-side staged implementation plan |
| `docs/cpu/branch-predictor-design.md` | BTB/RAS/JAL prediction design |
| `docs/cpu/branch-predictor-fixes.md` | Predictor correctness fixes and debug history |
| `docs/cpu/coremark-results.md` | CoreMark performance and CRC records |

## Known Warnings

Verilator currently reports width warnings in `sim/axi_ram.v` for address addition and `wstrb` DPI argument width. They are known simulator-model warnings and do not affect the validated CPU test or CoreMark results.
