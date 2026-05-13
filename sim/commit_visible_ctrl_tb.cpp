#include "Vhcpu_commit_visible_ctrl.h"
#include "verilated.h"
#include <cstdio>

static vluint64_t main_time = 0;

static void tick(Vhcpu_commit_visible_ctrl *top) {
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
  Vhcpu_commit_visible_ctrl *top = new Vhcpu_commit_visible_ctrl;
  int fail = 0;

  top->reset = 1;
  top->i_scalar_exu_mispredict_flush = 0;
  top->i_idu2exu_brch = 0;
  top->i_idu2exu_jal = 0;
  top->i_idu2exu_jalr = 0;
  top->i_commit_visible = 0;
  top->i_exu2wbu_ecall = 0;
  top->i_exu2wbu_mret = 0;
  top->i_pc_update_en = 0;
  top->i_exu_mispredict_flush_r = 0;
  tick(top);
  top->reset = 0;

  fail |= expect(top->o_wbu_pc_update_fire == 0, "pc update fire starts low");
  fail |= expect(top->o_redirect_recovery == 0, "redirect recovery starts low");

  top->i_exu2wbu_ecall = 1;
  top->eval();
  fail |= expect(top->o_wbu_pc_update_fire == 0, "ecall alone does not fire without commit visibility");

  top->i_commit_visible = 1;
  top->eval();
  fail |= expect(top->o_wbu_pc_update_fire == 1, "ecall fires only when commit visible");

  top->i_commit_visible = 0;
  top->i_exu2wbu_ecall = 0;
  top->i_scalar_exu_mispredict_flush = 1;
  top->i_idu2exu_brch = 1;
  top->i_exu_mispredict_flush_r = 1;
  tick(top);

  fail |= expect(top->o_redirect_recovery == 1, "redirect fire arms recovery state");
  fail |= expect(top->o_redirect_cause_brch == 1, "branch redirect cause is captured");
  fail |= expect(top->o_redirect_gap_cnt == 0, "redirect gap counter resets on redirect fire");

  top->i_scalar_exu_mispredict_flush = 0;
  top->i_idu2exu_brch = 0;
  top->i_exu_mispredict_flush_r = 0;
  tick(top);

  fail |= expect(top->o_redirect_recovery == 1, "redirect recovery waits without commit-visible completion");
  fail |= expect(top->o_redirect_gap_cnt == 1, "redirect gap counter increments while waiting");

  top->i_commit_visible = 1;
  top->eval();
  fail |= expect(top->o_redirect_complete == 1, "commit-visible completion closes redirect recovery");
  tick(top);

  fail |= expect(top->o_redirect_recovery == 0, "redirect recovery clears on commit-visible completion");

  top->i_commit_visible = 0;
  top->i_exu2wbu_mret = 1;
  top->eval();
  fail |= expect(top->o_wbu_pc_update_fire == 0, "mret alone does not fire without commit visibility");

  top->i_commit_visible = 1;
  top->eval();
  fail |= expect(top->o_wbu_pc_update_fire == 1, "mret also requires commit visibility");

  delete top;
  if (fail) {
    return 1;
  }
  std::printf("PASS: commit-visible control gates system pc_update and redirect recovery\n");
  return 0;
}
