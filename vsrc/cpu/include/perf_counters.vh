// ============================================================================
// Performance Counters — Macro Switch Header
//
// Usage:
//   Define any of these macros before building to enable the corresponding
//   counter group.  All groups are guarded by `ifdef so they compile away to
//   zero-cost when disabled.
//
//   -DPERF_COUNTERS   → master switch (enabled by default via Makefile)
//   -DPERF_INST_MIX   → instruction-type breakdown
//   -DPERF_STALL      → pipeline stall tracing
//   -DPERF_CACHE      → ICache / DCache hit & miss counters
//   -DPERF_BUS        → AXI bus transaction latency
// ============================================================================

`ifndef PERF_COUNTERS_VH
`define PERF_COUNTERS_VH

// ---- master switch ----
// Comment out the line below to disable ALL performance counters at once.
`define PERF_COUNTERS

// ---- sub-switches (only meaningful when PERF_COUNTERS is defined) ----
`ifdef PERF_COUNTERS
  `define PERF_INST_MIX
  `define PERF_STALL
  `define PERF_CACHE
  `define PERF_BUS
  `define PERF_BRANCH_PRED
`endif

`endif // PERF_COUNTERS_VH
