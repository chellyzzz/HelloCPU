#include "Vhcpu_lane1_issue_scoreboard.h"
#include "verilated.h"

#include <cstdio>

static int expect(bool condition, const char *message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    return 1;
  }
  return 0;
}

static void set_clean_alu_branch_pair(Vhcpu_lane1_issue_scoreboard *top) {
  top->i_pair_valid = 1;
  top->i_slot0_valid = 1;
  top->i_slot1_valid = 1;
  top->i_slot0_rd = 5;
  top->i_slot1_rd = 0;
  top->i_slot1_rs1_addr = 1;
  top->i_slot1_rs2_addr = 2;
  top->i_slot0_wen = 1;
  top->i_slot1_wen = 0;
  top->i_slot0_csr_wen = 0;
  top->i_slot1_csr_wen = 0;
  top->i_slot0_brch = 0;
  top->i_slot0_jal = 0;
  top->i_slot0_jalr = 0;
  top->i_slot0_load = 0;
  top->i_slot0_store = 0;
  top->i_slot0_muldiv = 0;
  top->i_slot0_is_cop_insn = 0;
  top->i_slot0_ecall = 0;
  top->i_slot0_mret = 0;
  top->i_slot0_ebreak = 0;
  top->i_slot0_fence_i = 0;
  top->i_slot1_brch = 1;
  top->i_slot1_jal = 0;
  top->i_slot1_jalr = 0;
  top->i_slot1_load = 0;
  top->i_slot1_store = 0;
  top->i_slot1_muldiv = 0;
  top->i_slot1_is_cop_insn = 0;
  top->i_slot1_ecall = 0;
  top->i_slot1_mret = 0;
  top->i_slot1_ebreak = 0;
  top->i_slot1_fence_i = 0;
  top->i_downstream_ready = 1;
  top->i_cop_pipeline_active = 0;
  top->i_frontend_flush = 0;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vhcpu_lane1_issue_scoreboard *top = new Vhcpu_lane1_issue_scoreboard;
  int fail = 0;

  set_clean_alu_branch_pair(top);
  top->eval();

  fail |= expect(top->o_pair_candidate_alu_branch == 1,
                 "clean ALU plus branch payload remains the executable candidate");
  fail |= expect(top->o_pair_order_alu_then_branch == 1,
                 "clean ALU plus branch payload keeps alu-then-branch ordering");
  fail |= expect(top->o_allow_second == 1,
                 "clean ALU plus branch payload is executable when downstream is ready");

  top->i_slot1_rs1_addr = 5;
  top->eval();
  fail |= expect(top->o_allow_second == 0,
                 "slot-local RAW blocks executable second-lane allowance");
  fail |= expect(top->o_block_raw == 1,
                 "slot-local RAW block reason is observable");

  set_clean_alu_branch_pair(top);
  top->i_slot1_wen = 1;
  top->i_slot1_rd = 5;
  top->i_slot1_brch = 0;
  top->eval();
  fail |= expect(top->o_allow_second == 0,
                 "dual writers are rejected by the executable scoreboard");
  fail |= expect(top->o_block_waw == 1,
                 "same-rd WAW is observable");
  fail |= expect(top->o_block_dual_writeback == 1,
                 "dual-writeback pressure is observable");

  set_clean_alu_branch_pair(top);
  top->i_slot0_load = 1;
  top->eval();
  fail |= expect(top->o_allow_second == 0,
                 "exclusive backend ownership blocks executable pairing");
  fail |= expect(top->o_block_exclusive_backend == 1,
                 "exclusive backend block reason is observable");

  set_clean_alu_branch_pair(top);
  top->i_slot1_jal = 1;
  top->i_slot1_brch = 0;
  top->eval();
  fail |= expect(top->o_allow_second == 0,
                 "redirect-hostile younger control is rejected");
  fail |= expect(top->o_block_redirect_control == 1,
                 "redirect-control block reason is observable");

  set_clean_alu_branch_pair(top);
  top->i_downstream_ready = 0;
  top->eval();
  fail |= expect(top->o_allow_second == 0,
                 "downstream busy blocks executable pairing");
  fail |= expect(top->o_block_downstream_busy == 1,
                 "downstream busy is observable");

  set_clean_alu_branch_pair(top);
  top->i_cop_pipeline_active = 1;
  top->eval();
  fail |= expect(top->o_allow_second == 0,
                 "cop pipeline activity blocks executable pairing");
  fail |= expect(top->o_block_cop_pipeline == 1,
                 "cop pipeline block reason is observable");

  set_clean_alu_branch_pair(top);
  top->i_frontend_flush = 1;
  top->eval();
  fail |= expect(top->o_allow_second == 0,
                 "frontend flush blocks executable pairing");
  fail |= expect(top->o_block_frontend_flush == 1,
                 "frontend flush block reason is observable");

  set_clean_alu_branch_pair(top);
  top->i_slot0_wen = 0;
  top->i_slot0_brch = 1;
  top->i_slot1_brch = 0;
  top->i_slot1_wen = 1;
  top->eval();
  fail |= expect(top->o_allow_second == 0,
                 "older branch then younger ALU stays rejected");
  fail |= expect(top->o_pair_order_branch_then_alu == 1,
                 "older branch ordering remains observable");
  fail |= expect(top->o_block_older_branch_first == 1,
                 "older-branch-first block reason is observable");

  delete top;
  if (fail) {
    return 1;
  }

  std::printf("PASS: lane1 issue scoreboard enforces the first executable pairing policy\n");
  return 0;
}
