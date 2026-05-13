# Branch Predictor Design

HelloCPU uses a simple predictor in the IFU and verifies predictions in the EXU. The validated predictor configuration enables conditional-branch BTB prediction, static JAL prediction, and RAS return prediction.

This document records the predictor design and the historical validation point when the full predictor became correct. Current whole-CPU performance numbers are maintained in `coremark-results.md`.

## Predictor Validation Snapshot

| Test | Result |
|------|--------|
| `make run` | Historical snapshot: `40 passed, 0 failed` |
| `make run ALL=quick-sort` | Historical snapshot: PASS, `6750` cycles |
| CoreMark ITER=1 | Historical snapshot: correct CRC, `715631` simulator cycles |
| CoreMark/MHz | Historical predictor-only snapshot: `1.404`; current CPU reference: `2.381` |

## IFU Prediction

The IFU chooses the next PC from prediction logic when the current instruction is available and the next stage can accept it.

```text
if JAL:                 next_pc = jal_target
else if return + RAS:   next_pc = ras_target
else if BTB predicts:   next_pc = btb_target
else:                   next_pc = pc + 4
```

The IFU passes `predict_taken` and `predict_target` through IFU/IDU and IDU/EXU pipeline registers so EXU can verify the prediction against the actual result.

## BTB

| Field | Value |
|-------|-------|
| Entries | 64 |
| Mapping | Direct mapped |
| Index | `pc[7:2]` |
| Tag | upper PC bits |
| Counter | 2-bit saturating counter |

Prediction is taken when the entry hits and `counter[1] == 1`.

BTB updates happen in EXU for conditional branches only. Taken branches allocate/update targets; not-taken branches decay the counter when the entry exists.

## RAS

| Property | Value |
|----------|-------|
| Depth | 8 entries |
| Entry width | target address `[31:2]` |
| Push | `JAL/JALR` with `rd == x1` |
| Pop | `JALR` with `rd == x0` and `rs1 == x1` |
| Predict | return-like `JALR` when stack is non-empty |

The stack is updated in EXU, not speculatively in IFU, so wrong-path fetches do not corrupt RAS state.

## Static JAL Prediction

JAL is always taken. IFU extracts the J-immediate and computes the target directly:

```verilog
wire [31:0] jal_imm = {{12{icache_ins[31]}}, icache_ins[19:12],
                       icache_ins[20], icache_ins[30:21], 1'b0};
wire [31:0] jal_target = pc_next + jal_imm;
```

Target correctness is checked in EXU. The predictor bring-up validation reported `JAL tgt bad = 0` on CoreMark ITER=1.

## Misprediction Detection

EXU checks both direction and target:

```verilog
wire actual_taken = (i_brch && brch_res) || i_jal || i_jalr;
wire is_control   = i_brch || i_jal || i_jalr;

wire mispredict = (is_control && (i_predict_taken != actual_taken)) ||
                  ((i_jal || i_jalr || i_brch) && i_predict_taken &&
                   (pred_target_full != o_pc_next));
```

On mismatch, EXU produces a redirect PC. For taken control flow it redirects to the actual target; for not-taken branches it redirects to `pc + 4`.

## WBU Redirect Policy

WBU only redirects on unresolved or mispredicted control flow:

```verilog
o_pc_update <= i_pre_valid &&
               (i_ecall || i_mret ||
                ((i_jal || i_jalr || i_is_brch) && !i_predict_correct));
```

This avoids clearing correctly predicted JAL/JALR/branch paths and preserves the benefit of early fetch.

## Historical CoreMark Predictor Counters

```text
BTB hits          : 62766 (84.0%)
BTB misses        : 11950 (16.0%)
BTB mispredicts   : 8686 (11.6%)
RAS hits          : 2732 (98.0%)
RAS misses        : 55 (2.0%)
JAL tgt bad       : 0
WBU pcupdate      : 8909
```
