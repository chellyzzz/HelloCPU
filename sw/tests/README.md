# Software Test Layout

- `tests/scalar-tests/`: scalar CPU tests
- `tests/vector-tests/`: COP/vector-facing tests

Build targets:
- `make scalar-tests`
- `make vector-tests`
- `make all`

Build outputs:
- scalar binaries in `build/scalar/`
- vector binaries in `build/vector/`

Directed simulation tests:
- `make cop_mem_pending_kill`: runs a Verilator-only COP memory pending-kill test. It delays a COP load response, injects a test-only COP kill, checks that the stale completion is absorbed, then verifies a later COP load can still complete.
- `make cop_mem_store_directed`: runs a Verilator-only COP memory store test. It checks that a COP store owns the AW/W/B path and only exposes a COP response after B completion.
- `make cop_mem_store_kill`: runs a Verilator-only COP memory pre-accept store-kill test. It holds AW/W acceptance, injects a test-only COP kill, checks that no store side effect reaches the bus, then verifies a later COP store can still complete.
- `make cop_vtype_kill`: runs a Verilator-only COP backend state flush test. It flushes a pending `vtype_write`, checks that the write does not commit, then verifies a later `vtype_write` can still complete.
