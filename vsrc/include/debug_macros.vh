// ============================================================================
// Debug Macros — Unified Switch Header for RTL Debug Prints
//
// Usage:
//   Un-comment any macro below to enable the corresponding debug output.
//   All prints are guarded by `ifdef so they compile away to zero-cost
//   when disabled.
//
//   `define DEBUG_ALL          → master switch, enables ALL debug groups
//   `define ICACHE_DEBUG       → ICache hit/miss/refill diagnostics
//   `define DCACHE_DEBUG       → DCache hit/miss/writeback/refill diagnostics
// ============================================================================

`ifndef DEBUG_MACROS_VH
`define DEBUG_MACROS_VH

// ---- master switch ----
// Un-comment to enable ALL debug prints at once.  Keep commented for zero-cost.
// `define DEBUG_ALL

// ---- per-module switches ----
`ifdef DEBUG_ALL
  `define ICACHE_DEBUG
  `define DCACHE_DEBUG
`endif

// ---- individual switches (override by un-commenting directly) ----
// `define ICACHE_DEBUG
// `define DCACHE_DEBUG

`endif // DEBUG_MACROS_VH
