#include "Vhcpu_exu_wbu_regs.h"
#include "verilated.h"
#include <cstdio>

static vluint64_t main_time = 0;

static void tick(Vhcpu_exu_wbu_regs *top) {
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
  Vhcpu_exu_wbu_regs *top = new Vhcpu_exu_wbu_regs;
  int fail = 0;

  top->reset = 1;
  top->i_flush = 0;
  top->i_post_ready = 1;
  top->o_post_valid = 0;
  top->i_pc_next = 0;
  top->i_pc = 0;
  top->i_csr_addr = 0;
  top->i_rd_addr = 0;
  top->i_wen = 0;
  top->i_csr_wen = 0;
  top->i_brch = 0;
  top->i_jal = 0;
  top->i_jalr = 0;
  top->i_mret = 0;
  top->i_ecall = 0;
  top->i_predict_taken = 0;
  top->i_predict_correct = 0;
  top->i_res = 0;
  top->i_ebreak = 0;
  top->i_load = 0;
  top->i_store = 0;
  top->i_muldiv = 0;
  top->i_fence_i = 0;
  top->i_is_brch = 0;
  top->i_is_div = 0;
  tick(top);
  top->reset = 0;

  top->o_post_valid = 1;
  top->i_pc_next = 0x30000020;
  top->i_pc = 0x3000001c;
  top->i_rd_addr = 5;
  top->i_wen = 1;
  top->i_res = 0x12345678;
  top->i_jalr = 1;
  top->i_predict_taken = 1;
  top->i_predict_correct = 1;
  tick(top);

  fail |= expect(top->o_valid == 1, "register captures valid payload");
  fail |= expect(top->o_pc == 0x3000001c, "register captures pc");
  fail |= expect(top->o_pc_next == 0x30000020, "register captures next pc");
  fail |= expect(top->o_rd_addr == 5, "register captures rd");
  fail |= expect(top->o_res == 0x12345678, "register captures result");

  top->i_post_ready = 0;
  top->i_flush = 1;
  tick(top);

  fail |= expect(top->o_valid == 0, "flush clears valid even when post_ready is low");
  fail |= expect(top->o_pc == 0, "flush clears pc payload");
  fail |= expect(top->o_pc_next == 0, "flush clears next pc payload");
  fail |= expect(top->o_rd_addr == 0, "flush clears rd payload");
  fail |= expect(top->o_res == 0, "flush clears result payload");
  fail |= expect(top->o_jalr == 0, "flush clears control payload");

  delete top;
  if (fail) {
    return 1;
  }
  std::printf("PASS: EXU/WBU flush clears latched payload without ready\n");
  return 0;
}
