#include "Vhcpu_ifu_idu_regs.h"
#include "verilated.h"
#include <cstdio>

static vluint64_t main_time = 0;

static void tick(Vhcpu_ifu_idu_regs *top) {
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
  Vhcpu_ifu_idu_regs *top = new Vhcpu_ifu_idu_regs;
  int fail = 0;

  top->reset = 1;
  top->flush = 0;
  top->icache_hit = 0;
  top->i_post_ready = 1;
  top->i_pre_valid = 0;
  top->i_pc = 0;
  top->i_ins = 0;
  top->i_predict_taken = 0;
  top->i_predict_target = 0;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->reset = 0;

  top->icache_hit = 1;
  top->i_post_ready = 1;
  top->i_pc = 0x30000010;
  top->i_ins = 0x11111113;
  top->i_predict_taken = 1;
  top->i_predict_target = 0x30000040 >> 2;
  top->i_predict_btb_hit = 1;
  tick(top);

  fail |= expect(top->o_post_valid == 1, "valid asserted after accepted fetch");
  fail |= expect(top->o_pc == 0x30000010, "pc captured on accepted fetch");
  fail |= expect(top->o_ins == 0x11111113, "instruction captured on accepted fetch");
  fail |= expect(top->o_predict_taken == 1, "predict_taken captured");
  fail |= expect(top->o_predict_target == (0x30000040 >> 2), "predict_target captured");
  fail |= expect(top->o_predict_btb_hit == 1, "predict_btb_hit captured");

  top->i_post_ready = 0;
  top->icache_hit = 0;
  top->i_pc = 0x30000020;
  top->i_ins = 0x22222213;
  top->i_predict_taken = 0;
  top->i_predict_target = 0x30000080 >> 2;
  top->i_predict_btb_hit = 0;
  tick(top);

  fail |= expect(top->o_post_valid == 1, "valid held during backpressure and icache miss");
  fail |= expect(top->o_pc == 0x30000010, "pc held during backpressure");
  fail |= expect(top->o_ins == 0x11111113, "instruction held during backpressure");
  fail |= expect(top->o_predict_taken == 1, "predict_taken held during backpressure");
  fail |= expect(top->o_predict_target == (0x30000040 >> 2), "predict_target held during backpressure");
  fail |= expect(top->o_predict_btb_hit == 1, "predict_btb_hit held during backpressure");

  top->icache_hit = 1;
  top->i_pc = 0x30000024;
  top->i_ins = 0x33333313;
  top->i_predict_taken = 0;
  top->i_predict_target = 0x30000084 >> 2;
  top->i_predict_btb_hit = 0;
  tick(top);

  fail |= expect(top->o_post_valid == 1, "valid held during backpressure and new icache hit");
  fail |= expect(top->o_pc == 0x30000010, "old pc not overwritten while stalled");
  fail |= expect(top->o_ins == 0x11111113, "old instruction not overwritten while stalled");
  fail |= expect(top->o_predict_taken == 1, "old predict_taken not overwritten while stalled");
  fail |= expect(top->o_predict_target == (0x30000040 >> 2), "old predict_target not overwritten while stalled");
  fail |= expect(top->o_predict_btb_hit == 1, "old predict_btb_hit not overwritten while stalled");

  top->flush = 1;
  tick(top);

  fail |= expect(top->o_post_valid == 0, "flush clears valid");
  fail |= expect(top->o_pc == 0, "flush clears pc");
  fail |= expect(top->o_ins == 0, "flush clears instruction");
  fail |= expect(top->o_predict_taken == 0, "flush clears predict_taken");
  fail |= expect(top->o_predict_target == 0, "flush clears predict_target");
  fail |= expect(top->o_predict_btb_hit == 0, "flush clears predict_btb_hit");

  delete top;
  if (fail) {
    return 1;
  }
  std::printf("PASS: IFU/IDU backpressure holds valid, payload, and predictor metadata\n");
  return 0;
}
