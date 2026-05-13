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
