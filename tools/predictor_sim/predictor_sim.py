#!/usr/bin/env python3

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional


ENTRIES = 128
INDEX_W = 7
TAG_SHIFT = INDEX_W + 2
BHT_ENTRIES = 512


@dataclass
class BranchEvent:
    pc: int
    btb_hit: bool
    pred_taken: bool
    pred_target: int
    actual_taken: bool
    actual_target: int


@dataclass
class PcStats:
    total: int = 0
    mispredict: int = 0
    pred_nt_taken: int = 0
    pred_taken_nt: int = 0


@dataclass
class LoopEntry:
    trip_count: int = 0
    current_iter: int = 0
    confidence: int = 0


def parse_trace_line(line: str) -> Optional[BranchEvent]:
    fields = {}
    for token in line.strip().split():
        if "=" not in token:
            return None
        key, value = token.split("=", 1)
        fields[key] = value
    required = {"pc", "btb_hit", "pred", "pred_target", "actual", "target"}
    if not required.issubset(fields):
        return None
    return BranchEvent(
        pc=int(fields["pc"], 16),
        btb_hit=bool(int(fields["btb_hit"])),
        pred_taken=bool(int(fields["pred"])),
        pred_target=int(fields["pred_target"], 16),
        actual_taken=bool(int(fields["actual"])),
        actual_target=int(fields["target"], 16),
    )


def load_trace(path: Path) -> List[BranchEvent]:
    with path.open("r", encoding="utf-8") as handle:
        return [event for line in handle if line.strip() for event in [parse_trace_line(line)] if event is not None]


def sat_inc(value: int) -> int:
    return 3 if value >= 3 else value + 1


def sat_dec(value: int) -> int:
    return 0 if value <= 0 else value - 1


def lookup_idx(pc: int) -> int:
    return (pc >> 2) & (ENTRIES - 1)


def lookup_tag(pc: int) -> int:
    return pc >> TAG_SHIFT


def bht_idx(pc: int) -> int:
    return (pc >> 2) & (BHT_ENTRIES - 1)


class CurrentPredictor:
    def __init__(self) -> None:
        self.valid = [False] * ENTRIES
        self.tag = [0] * ENTRIES
        self.target = [0] * ENTRIES
        self.btb_counter = [1] * ENTRIES
        self.bht_counter = [1] * BHT_ENTRIES

    def predict(self, pc: int) -> tuple[bool, int, bool]:
        idx = lookup_idx(pc)
        hit = self.valid[idx] and self.tag[idx] == lookup_tag(pc)
        bht = self.bht_counter[bht_idx(pc)]
        if hit:
            btb = self.btb_counter[idx]
            taken = True if btb == 3 else False if btb == 0 else bool(bht >> 1)
            return taken, self.target[idx], True
        return bool(bht >> 1), 0, False

    def update(self, event: BranchEvent) -> None:
        idx = lookup_idx(event.pc)
        hit = self.valid[idx] and self.tag[idx] == lookup_tag(event.pc)
        bh_idx = bht_idx(event.pc)
        self.bht_counter[bh_idx] = sat_inc(self.bht_counter[bh_idx]) if event.actual_taken else sat_dec(self.bht_counter[bh_idx])
        if event.actual_taken:
            if hit:
                self.btb_counter[idx] = sat_inc(self.btb_counter[idx])
            else:
                self.valid[idx] = True
                self.tag[idx] = lookup_tag(event.pc)
                self.btb_counter[idx] = 2
            self.target[idx] = event.actual_target
        elif hit:
            self.btb_counter[idx] = 0 if self.btb_counter[idx] <= 1 else self.btb_counter[idx] - 2


class BimodalPredictor:
    def __init__(self, table_bits: int) -> None:
        self.mask = (1 << table_bits) - 1
        self.table = [1] * (1 << table_bits)

    def predict(self, pc: int) -> tuple[bool, int, bool]:
        return bool(self.table[(pc >> 2) & self.mask] >> 1), 0, False

    def update(self, event: BranchEvent) -> None:
        idx = (event.pc >> 2) & self.mask
        self.table[idx] = sat_inc(self.table[idx]) if event.actual_taken else sat_dec(self.table[idx])


class GsharePredictor:
    def __init__(self, ghr_bits: int, pht_bits: int) -> None:
        self.ghr_mask = (1 << ghr_bits) - 1
        self.pht_mask = (1 << pht_bits) - 1
        self.ghr = 0
        self.table = [1] * (1 << pht_bits)

    def _idx(self, pc: int) -> int:
        return ((pc >> 2) & self.pht_mask) ^ (self.ghr & self.pht_mask)

    def predict(self, pc: int) -> tuple[bool, int, bool]:
        return bool(self.table[self._idx(pc)] >> 1), 0, False

    def update(self, event: BranchEvent) -> None:
        idx = self._idx(event.pc)
        self.table[idx] = sat_inc(self.table[idx]) if event.actual_taken else sat_dec(self.table[idx])
        self.ghr = ((self.ghr << 1) | int(event.actual_taken)) & self.ghr_mask


class LocalHistoryPredictor:
    def __init__(self, lht_bits: int, history_bits: int) -> None:
        self.lht_mask = (1 << lht_bits) - 1
        self.history_mask = (1 << history_bits) - 1
        self.local_history = [0] * (1 << lht_bits)
        self.table = [1] * (1 << history_bits)

    def _history_idx(self, pc: int) -> int:
        return (pc >> 2) & self.lht_mask

    def predict(self, pc: int) -> tuple[bool, int, bool]:
        return bool(self.table[self.local_history[self._history_idx(pc)]] >> 1), 0, False

    def update(self, event: BranchEvent) -> None:
        history_idx = self._history_idx(event.pc)
        history = self.local_history[history_idx]
        self.table[history] = sat_inc(self.table[history]) if event.actual_taken else sat_dec(self.table[history])
        self.local_history[history_idx] = ((history << 1) | int(event.actual_taken)) & self.history_mask


class CurrentLocalPredictor:
    def __init__(self, lht_bits: int, history_bits: int) -> None:
        self.valid = [False] * ENTRIES
        self.tag = [0] * ENTRIES
        self.target = [0] * ENTRIES
        self.btb_counter = [1] * ENTRIES
        self.local = LocalHistoryPredictor(lht_bits, history_bits)

    def predict(self, pc: int) -> tuple[bool, int, bool]:
        idx = lookup_idx(pc)
        hit = self.valid[idx] and self.tag[idx] == lookup_tag(pc)
        local_taken, _, _ = self.local.predict(pc)
        if hit:
            btb = self.btb_counter[idx]
            return True if btb == 3 else False if btb == 0 else local_taken, self.target[idx], True
        return local_taken, 0, False

    def update(self, event: BranchEvent) -> None:
        idx = lookup_idx(event.pc)
        hit = self.valid[idx] and self.tag[idx] == lookup_tag(event.pc)
        self.local.update(event)
        if event.actual_taken:
            if hit:
                self.btb_counter[idx] = sat_inc(self.btb_counter[idx])
            else:
                self.valid[idx] = True
                self.tag[idx] = lookup_tag(event.pc)
                self.btb_counter[idx] = 2
            self.target[idx] = event.actual_target
        elif hit:
            self.btb_counter[idx] = 0 if self.btb_counter[idx] <= 1 else self.btb_counter[idx] - 2


class TournamentPredictor:
    def __init__(self, chooser_bits: int, lht_bits: int, history_bits: int) -> None:
        self.current = CurrentPredictor()
        self.local = LocalHistoryPredictor(lht_bits, history_bits)
        self.chooser_mask = (1 << chooser_bits) - 1
        self.chooser = [1] * (1 << chooser_bits)

    def _chooser_idx(self, pc: int) -> int:
        return (pc >> 2) & self.chooser_mask

    def predict(self, pc: int) -> tuple[bool, int, bool]:
        current_pred = self.current.predict(pc)
        local_pred = self.local.predict(pc)
        return local_pred if self.chooser[self._chooser_idx(pc)] >= 2 else current_pred

    def update(self, event: BranchEvent) -> None:
        current_taken, _, _ = self.current.predict(event.pc)
        local_taken, _, _ = self.local.predict(event.pc)
        chooser_idx = self._chooser_idx(event.pc)
        self.current.update(event)
        self.local.update(event)
        if (current_taken == event.actual_taken) != (local_taken == event.actual_taken):
            self.chooser[chooser_idx] = sat_inc(self.chooser[chooser_idx]) if local_taken == event.actual_taken else sat_dec(self.chooser[chooser_idx])


class LoopPredictor:
    def __init__(self, confidence_threshold: int) -> None:
        self.confidence_threshold = confidence_threshold
        self.entries: Dict[int, LoopEntry] = {}

    def predict(self, pc: int) -> Optional[bool]:
        entry = self.entries.get(pc)
        if entry is None or entry.confidence < self.confidence_threshold or entry.trip_count == 0:
            return None
        return False if entry.current_iter >= entry.trip_count else None

    def update(self, event: BranchEvent) -> None:
        if event.actual_target >= event.pc:
            return
        entry = self.entries.setdefault(event.pc, LoopEntry())
        if event.actual_taken:
            entry.current_iter += 1
            return
        if entry.current_iter > 0:
            if entry.trip_count == entry.current_iter:
                entry.confidence = sat_inc(entry.confidence)
            else:
                entry.trip_count = entry.current_iter
                entry.confidence = sat_dec(entry.confidence)
        entry.current_iter = 0


class LoopOverridePredictor:
    def __init__(self, base_predictor, confidence_threshold: int) -> None:
        self.base = base_predictor
        self.loop = LoopPredictor(confidence_threshold)

    def predict(self, pc: int) -> tuple[bool, int, bool]:
        base_taken, base_target, base_hit = self.base.predict(pc)
        loop_taken = self.loop.predict(pc)
        return (loop_taken, base_target, base_hit) if loop_taken is not None else (base_taken, base_target, base_hit)

    def update(self, event: BranchEvent) -> None:
        self.base.update(event)
        self.loop.update(event)


def simulate(events: Iterable[BranchEvent], predictor) -> dict:
    total = mispredict = pred_nt_taken = pred_taken_nt = target_bad = 0
    pc_stats: Dict[int, PcStats] = {}
    for event in events:
        total += 1
        pred_taken, _, _ = predictor.predict(event.pc)
        stats = pc_stats.setdefault(event.pc, PcStats())
        stats.total += 1
        if pred_taken != event.actual_taken:
            mispredict += 1
            stats.mispredict += 1
            if not pred_taken and event.actual_taken:
                pred_nt_taken += 1
                stats.pred_nt_taken += 1
            elif pred_taken and not event.actual_taken:
                pred_taken_nt += 1
                stats.pred_taken_nt += 1
        predictor.update(event)
    return {
        "total": total,
        "mispredict": mispredict,
        "pred_nt_taken": pred_nt_taken,
        "pred_taken_nt": pred_taken_nt,
        "target_bad": target_bad,
        "accuracy": 0.0 if total == 0 else 100.0 * (total - mispredict) / total,
        "pc_stats": pc_stats,
    }


def build_predictor(args):
    if args.policy == "current":
        return CurrentPredictor()
    if args.policy == "bimodal":
        return BimodalPredictor(args.pht_bits)
    if args.policy == "gshare":
        return GsharePredictor(args.ghr_bits, args.pht_bits)
    if args.policy == "local":
        return LocalHistoryPredictor(args.lht_bits, args.history_bits)
    if args.policy == "current_local":
        return CurrentLocalPredictor(args.lht_bits, args.history_bits)
    if args.policy == "tournament":
        return TournamentPredictor(args.chooser_bits, args.lht_bits, args.history_bits)
    if args.policy == "loop":
        return LoopOverridePredictor(CurrentPredictor(), args.loop_confidence)
    if args.policy == "tournament_loop":
        return LoopOverridePredictor(TournamentPredictor(args.chooser_bits, args.lht_bits, args.history_bits), args.loop_confidence)
    raise ValueError(f"unsupported policy: {args.policy}")


def print_top_pcs(pc_stats: Dict[int, PcStats], limit: int) -> None:
    ranked = sorted(pc_stats.items(), key=lambda item: (-item[1].mispredict, -item[1].total, item[0]))
    if limit <= 0:
        return
    print("top miss PCs :")
    for pc, stats in ranked[:limit]:
        accuracy = 100.0 * (stats.total - stats.mispredict) / stats.total if stats.total else 0.0
        print(f"  pc=0x{pc:08x} branches={stats.total} mispredict={stats.mispredict} accuracy={accuracy:.2f}% nt->t={stats.pred_nt_taken} t->nt={stats.pred_taken_nt}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Offline branch predictor simulator")
    parser.add_argument("--trace", required=True, type=Path, help="Path to branch trace log")
    parser.add_argument("--policy", choices=["current", "bimodal", "gshare", "local", "current_local", "tournament", "loop", "tournament_loop"], default="current")
    parser.add_argument("--ghr-bits", type=int, default=8)
    parser.add_argument("--pht-bits", type=int, default=10)
    parser.add_argument("--lht-bits", type=int, default=10)
    parser.add_argument("--history-bits", type=int, default=8)
    parser.add_argument("--chooser-bits", type=int, default=10)
    parser.add_argument("--loop-confidence", type=int, default=2)
    parser.add_argument("--top-pcs", type=int, default=0)
    args = parser.parse_args()

    events = load_trace(args.trace)
    result = simulate(events, build_predictor(args))
    print(f"policy       : {args.policy}")
    print(f"trace        : {args.trace}")
    print(f"branches     : {result['total']}")
    print(f"mispredict   : {result['mispredict']}")
    print(f"accuracy     : {result['accuracy']:.3f}%")
    print(f"pred NT->T   : {result['pred_nt_taken']}")
    print(f"pred T->NT   : {result['pred_taken_nt']}")
    print(f"target bad   : {result['target_bad']}")
    print_top_pcs(result["pc_stats"], args.top_pcs)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
