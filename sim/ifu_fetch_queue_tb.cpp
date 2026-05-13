#include "Vhcpu_ifu_fetch_queue.h"
#include "verilated.h"

#include <cstdio>

static vluint64_t main_time = 0;

static void tick(Vhcpu_ifu_fetch_queue *top) {
  top->clock = 0;
  top->eval();
  main_time++;
  top->clock = 1;
  top->eval();
  main_time++;
}

static int expect(bool condition, const char *message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    return 1;
  }
  return 0;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vhcpu_ifu_fetch_queue *top = new Vhcpu_ifu_fetch_queue;
  int fail = 0;

  constexpr uint32_t pc_a = 0x30000010u;
  constexpr uint32_t ins_a = 0x11111113u;
  constexpr uint32_t target_a = 0x30000040u >> 2;

  constexpr uint32_t pc_b = 0x30000014u;
  constexpr uint32_t ins_b = 0x22222213u;
  constexpr uint32_t target_b = 0x30000080u >> 2;

  constexpr uint32_t pc_c = 0x30000018u;
  constexpr uint32_t ins_c = 0x33333313u;
  constexpr uint32_t target_c = 0x300000c0u >> 2;

  top->reset = 1;
  top->flush = 0;
  top->i_enq_valid = 0;
  top->i_deq_ready = 0;
  top->i_pc = 0;
  top->i_ins = 0;
  top->i_predict_taken = 0;
  top->i_predict_target = 0;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->reset = 0;
  top->eval();

  fail |= expect(top->o_deq_valid == 0, "reset clears queue valid");
  fail |= expect(top->o_enq_ready == 1, "reset leaves queue ready for enqueue");

  top->i_enq_valid = 1;
  top->i_deq_ready = 0;
  top->i_pc = pc_a;
  top->i_ins = ins_a;
  top->i_predict_taken = 1;
  top->i_predict_target = target_a;
  top->i_predict_btb_hit = 1;
  tick(top);

  fail |= expect(top->o_deq_valid == 1, "first enqueue creates a visible entry");
  fail |= expect(top->o_pc == pc_a, "first enqueue captures pc");
  fail |= expect(top->o_ins == ins_a, "first enqueue captures instruction");
  fail |= expect(top->o_predict_taken == 1, "first enqueue captures predict_taken");
  fail |= expect(top->o_predict_target == target_a, "first enqueue captures predict_target");
  fail |= expect(top->o_predict_btb_hit == 1, "first enqueue captures predict_btb_hit");

  top->i_pc = pc_b;
  top->i_ins = ins_b;
  top->i_predict_taken = 0;
  top->i_predict_target = target_b;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 1, "second enqueue keeps queue non-empty");
  fail |= expect(top->o_pc == pc_a, "oldest entry remains visible while second entry queues");
  fail |= expect(top->o_ins == ins_a, "oldest instruction remains visible while second entry queues");
  fail |= expect(top->o_enq_ready == 0, "queue reports full under backpressure after two entries");

  top->i_pc = pc_c;
  top->i_ins = ins_c;
  top->i_predict_taken = 1;
  top->i_predict_target = target_c;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->eval();

  fail |= expect(top->o_pc == pc_a, "full queue rejects overwrite without dequeue");
  fail |= expect(top->o_ins == ins_a, "full queue keeps oldest instruction without dequeue");

  top->i_pc = pc_c;
  top->i_ins = ins_c;
  top->i_predict_taken = 1;
  top->i_predict_target = target_c;
  top->i_predict_btb_hit = 0;
  top->i_deq_ready = 1;
  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 1, "simultaneous dequeue and enqueue keeps queue non-empty");
  fail |= expect(top->o_pc == pc_b, "second entry becomes visible after replacing oldest entry");
  fail |= expect(top->o_ins == ins_b, "second entry instruction becomes visible after replace");
  fail |= expect(top->o_predict_taken == 0, "second entry predict_taken preserved after replace");
  fail |= expect(top->o_predict_target == target_b, "second entry predict_target preserved after replace");
  fail |= expect(top->o_predict_btb_hit == 0, "second entry predict_btb_hit preserved after replace");

  top->i_enq_valid = 0;
  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 1, "third entry remains queued after draining second entry");
  fail |= expect(top->o_pc == pc_c, "third entry drains last");
  fail |= expect(top->o_ins == ins_c, "third instruction drains last");
  fail |= expect(top->o_predict_taken == 1, "third predict_taken drains last");
  fail |= expect(top->o_predict_target == target_c, "third predict_target drains last");
  fail |= expect(top->o_predict_btb_hit == 0, "third predict_btb_hit drains last");

  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 0, "queue empties after final dequeue");
  fail |= expect(top->o_enq_ready == 1, "queue is ready again after draining");

  top->i_deq_ready = 0;
  top->i_enq_valid = 1;
  top->i_pc = pc_a;
  top->i_ins = ins_a;
  top->i_predict_taken = 1;
  top->i_predict_target = target_a;
  top->i_predict_btb_hit = 1;
  tick(top);

  top->i_pc = pc_b;
  top->i_ins = ins_b;
  top->i_predict_taken = 0;
  top->i_predict_target = target_b;
  top->i_predict_btb_hit = 0;
  tick(top);

  top->flush = 1;
  top->i_enq_valid = 0;
  tick(top);
  top->flush = 0;
  top->eval();

  fail |= expect(top->o_deq_valid == 0, "flush drops all queued entries");
  fail |= expect(top->o_enq_ready == 1, "flush reopens enqueue path");

  top->i_enq_valid = 1;
  top->i_deq_ready = 1;
  top->i_pc = pc_a;
  top->i_ins = ins_a;
  top->i_predict_taken = 1;
  top->i_predict_target = target_a;
  top->i_predict_btb_hit = 1;
  tick(top);

  top->i_pc = pc_b;
  top->i_ins = ins_b;
  top->i_predict_taken = 0;
  top->i_predict_target = target_b;
  top->i_predict_btb_hit = 0;
  tick(top);

  top->flush = 1;
  top->i_pc = pc_c;
  top->i_ins = ins_c;
  top->i_predict_taken = 1;
  top->i_predict_target = target_c;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->flush = 0;
  top->eval();

  fail |= expect(top->o_deq_valid == 0, "flush dominates concurrent dequeue and enqueue");
  fail |= expect(top->o_enq_ready == 1, "flush leaves queue ready after concurrent activity");

  top->i_enq_valid = 0;
  top->i_deq_ready = 0;
  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 0, "no stale entry appears after flush-dominant cycle");

  delete top;
  if (fail) {
    return 1;
  }

  std::printf("PASS: IFU fetch queue preserves FIFO order, backpressure, replace-on-drain, and flush dominance\n");
  return 0;
}
