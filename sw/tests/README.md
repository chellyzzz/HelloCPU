# Software Test Layout

- `tests/cpu-tests/`: scalar CPU tests
- `tests/vector-tests/`: COP/vector-facing tests

Build targets:
- `make scalar-tests`
- `make vector-tests`
- `make all`

Build outputs:
- scalar binaries in `build/scalar/`
- vector binaries in `build/vector/`
