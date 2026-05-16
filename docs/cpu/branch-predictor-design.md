# Branch Predictor Design

HelloCPU predicts control flow in the IFU and verifies predictions in the EXU. The current validated configuration combines a tagged BTB target cache, tournament direction prediction, a loop-exit override, static JAL prediction, and RAS return prediction.

This document records the current predictor design and the historical validation point when the full predictor became correct. Current whole-CPU performance numbers are maintained in `coremark-results.md`.

## Predictor Validation Snapshot

| Test | Result |
|------|--------|
| `make bench_only ITER=100` | Current snapshot on `master`: PASS, `3.098 CoreMark/MHz`, `32,279,748` simulator cycles |
| CoreMark ITER=100 predictor counters | `271,994` BTB mispredicts, `5.1%` mispredict rate, `0` target-bad events |
| `make run` | Historical snapshot: `40 passed, 0 failed` |
| `make run ALL=quick-sort` | Historical snapshot: PASS, `6750` cycles |
| CoreMark ITER=1 | Historical snapshot: correct CRC, `715631` simulator cycles |
| CoreMark/MHz | Historical predictor-only snapshot: `1.404`; current CPU reference: `3.098` |

## IFU Prediction

The IFU chooses the next PC from prediction logic when the current instruction is available and the next stage can accept it.

```text
if JAL:                         next_pc = jal_target
else if return + RAS:           next_pc = ras_target
else if branch predictor taken: next_pc = predictor_target
else:                           next_pc = pc + 4
```

For conditional branches, a BTB hit supplies the cached target. A predicted-taken BTB miss uses the branch immediate target decoded in IFU, so direction fallback can still redirect fetch even when the target cache misses.

The IFU passes `predict_taken`, `predict_target`, and `predict_btb_hit` through IFU/IDU and IDU/EXU pipeline registers so EXU can verify direction, target, and predictor subtype counters against the actual result.

## BTB

| Field | Value |
|-------|-------|
| Entries | 128 |
| Mapping | Direct mapped |
| Index | `pc[8:2]` |
| Tag | upper PC bits |
| Counter | 2-bit saturating counter |

The BTB is now a target cache plus one input to direction prediction. On a BTB hit, strongly taken/strongly not-taken BTB counters decide direction directly; weak BTB states defer to the global BHT counter. On a BTB miss, the BHT can still predict taken and IFU uses the decoded branch target.

BTB updates happen in EXU for conditional branches only. Taken branches allocate/update targets; not-taken branches decay the counter when the entry exists.

## Direction Predictor

| Component | Configuration | Role |
|-----------|---------------|------|
| Global BHT | 512 2-bit counters, indexed by `pc[10:2]` | Direction fallback and weak-BTB direction input |
| Local history table | 1024 entries, 8-bit local history | Per-PC local branch behavior |
| Local PHT | 256 2-bit counters | Predicts from local history pattern |
| Chooser | 1024 2-bit counters | Selects local predictor or BTB/BHT path |

The tournament result is selected by the chooser. The chooser only changes when the local predictor and BTB/BHT path disagree and one side is correct.

## Loop-Exit Override

| Field | Value |
|-------|-------|
| Entries | 128 |
| Index | `pc[8:2]` |
| Tag | upper PC bits |
| Trip counter | 16 bits |
| Confidence | 2-bit saturating counter |

The loop predictor only overrides to not-taken at a confident loop exit. It does not force steady-state taken predictions, which avoids regressing tight loops where the tournament predictor is already correct.

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

## CoreMark Predictor Counters

Current CoreMark `ITER=100` predictor counters:

```text
BTB hits          : 4518469 (84.8%)
BTB misses        : 807477 (15.2%)
BTB mispredicts   : 271994 (5.1%)
  pred NT,taken   : 116970
  pred T,NT       : 122698
  target bad      : 0
RAS hits          : 183025 (100.0%)
RAS misses        : 4
WBU pcupdate      : 0
Redirect cost     : 2 avg cycles (268639 events)
```

Historical ITER=1 predictor bring-up counters:

```text
BTB hits          : 62766 (84.0%)
BTB misses        : 11950 (16.0%)
BTB mispredicts   : 8686 (11.6%)
RAS hits          : 2732 (98.0%)
RAS misses        : 55 (2.0%)
JAL tgt bad       : 0
WBU pcupdate      : 8909
```
