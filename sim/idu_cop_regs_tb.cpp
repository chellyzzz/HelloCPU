#include "Vhcpu_idu_cop_regs.h"
#include "verilated.h"
#include <cstdio>

static vluint64_t main_time = 0;

static void tick(Vhcpu_idu_cop_regs *top) {
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
  Vhcpu_idu_cop_regs *top = new Vhcpu_idu_cop_regs;
  int fail = 0;

  top->reset = 1;
  top->i_issue_valid = 0;
  top->i_kill = 0;
  top->i_dequeue = 0;
  top->i_backend_busy = 0;
  top->i_pc = 0;
  top->i_ins = 0;
  top->i_src1 = 0;
  top->i_src2 = 0;
  top->i_rd = 0;
  top->i_wen = 0;
  tick(top);
  top->reset = 0;

  fail |= expect(top->o_inflight == 0, "reset clears inflight");
  fail |= expect(top->o_issue_ready == 1, "ready after reset");

  top->i_issue_valid = 1;
  top->i_pc = 0x30000100;
  top->i_ins = 0xdeadbeef;
  top->i_src1 = 11;
  top->i_src2 = 22;
  top->i_rd = 7;
  top->i_wen = 1;
  top->eval();
  fail |= expect(top->o_issue_fire == 1, "issue fires when ready");
  tick(top);
  top->i_issue_valid = 0;

  fail |= expect(top->o_inflight == 1, "entry becomes inflight after issue");
  fail |= expect(top->o_pc == 0x30000100, "entry captures pc");
  fail |= expect(top->o_ins == 0xdeadbeef, "entry captures ins");
  fail |= expect(top->o_rd == 7, "entry captures rd");
  fail |= expect(top->o_wen == 1, "entry captures wen");

  top->i_kill = 1;
  tick(top);
  top->i_kill = 0;

  fail |= expect(top->o_inflight == 0, "kill clears inflight entry");
  fail |= expect(top->o_pc == 0, "kill clears stored pc");
  fail |= expect(top->o_rd == 0, "kill clears stored rd");

  top->i_issue_valid = 1;
  top->i_pc = 0x30000200;
  top->i_ins = 0x11111111;
  top->i_src1 = 33;
  top->i_src2 = 44;
  top->i_rd = 9;
  top->i_wen = 1;
  tick(top);

  top->i_pc = 0x30000300;
  top->i_ins = 0x22222222;
  top->i_src1 = 55;
  top->i_src2 = 66;
  top->i_rd = 10;
  top->i_wen = 1;
  top->i_dequeue = 1;
  top->eval();
  fail |= expect(top->o_issue_fire == 1, "dequeue opens same-cycle replacement issue");
  tick(top);
  top->i_dequeue = 0;
  top->i_issue_valid = 0;

  fail |= expect(top->o_inflight == 1, "dequeue with simultaneous issue keeps inflight set");
  fail |= expect(top->o_pc == 0x30000300, "dequeue with simultaneous issue captures replacement pc");
  fail |= expect(top->o_ins == 0x22222222, "dequeue with simultaneous issue captures replacement ins");
  fail |= expect(top->o_rd == 10, "dequeue with simultaneous issue captures replacement rd");

  top->i_dequeue = 1;
  tick(top);
  top->i_dequeue = 0;

  fail |= expect(top->o_inflight == 0, "plain dequeue clears inflight when no replacement exists");

  delete top;
  if (fail) {
    return 1;
  }
  std::printf("PASS: IDU COP regs preserve ownership across kill and dequeue\n");
  return 0;
}
