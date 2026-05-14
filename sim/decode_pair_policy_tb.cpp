#include "Vhcpu_decode_pair_policy.h"
#include "verilated.h"

#include <cstdio>

static int expect(bool condition, const char *message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    return 1;
  }
  return 0;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vhcpu_decode_pair_policy *top = new Vhcpu_decode_pair_policy;
  int fail = 0;

  top->i_pair_valid = 0;
  top->i_pair_candidate_alu_branch = 0;
  top->i_pair_has_raw = 0;
  top->i_pair_has_waw = 0;
  top->i_pair_has_dual_writeback = 0;
  top->i_pair_has_exclusive_backend = 0;
  top->i_pair_has_redirect_control = 0;
  top->i_downstream_ready = 1;
  top->i_cop_pipeline_active = 0;
  top->i_frontend_flush = 0;
  top->eval();

  fail |= expect(top->o_pair_visible == 0, "no pair means no visible policy state");
  fail |= expect(top->o_allow_second == 0, "no pair means no slot1 allowance");

  top->i_pair_valid = 1;
  top->i_pair_candidate_alu_branch = 1;
  top->eval();

  fail |= expect(top->o_pair_visible == 1, "valid pair becomes visible");
  fail |= expect(top->o_allow_second == 1, "clean ALU plus branch pair is allowed by skeleton");

  top->i_downstream_ready = 0;
  top->eval();

  fail |= expect(top->o_allow_second == 0, "downstream backpressure blocks slot1 allowance");
  fail |= expect(top->o_block_downstream_busy == 1, "downstream backpressure is observable");

  top->i_downstream_ready = 1;
  top->i_pair_has_raw = 1;
  top->eval();

  fail |= expect(top->o_allow_second == 0, "raw dependence blocks slot1 allowance");
  fail |= expect(top->o_block_raw == 1, "raw block reason is observable");

  top->i_pair_has_raw = 0;
  top->i_pair_has_waw = 1;
  top->eval();

  fail |= expect(top->o_allow_second == 0, "waw blocks slot1 allowance");
  fail |= expect(top->o_block_waw == 1, "waw block reason is observable");

  top->i_pair_has_waw = 0;
  top->i_pair_has_dual_writeback = 1;
  top->eval();

  fail |= expect(top->o_allow_second == 0, "dual writeback pressure blocks slot1 allowance");
  fail |= expect(top->o_block_dual_writeback == 1, "dual writeback block reason is observable");

  top->i_pair_has_dual_writeback = 0;
  top->i_pair_has_exclusive_backend = 1;
  top->eval();

  fail |= expect(top->o_allow_second == 0, "exclusive backend blocks slot1 allowance");
  fail |= expect(top->o_block_exclusive_backend == 1, "exclusive backend block reason is observable");

  top->i_pair_has_exclusive_backend = 0;
  top->i_pair_has_redirect_control = 1;
  top->eval();

  fail |= expect(top->o_allow_second == 0, "redirect control blocks slot1 allowance");
  fail |= expect(top->o_block_redirect_control == 1, "redirect control block reason is observable");

  top->i_pair_has_redirect_control = 0;
  top->i_cop_pipeline_active = 1;
  top->eval();

  fail |= expect(top->o_allow_second == 0, "cop pipeline activity blocks slot1 allowance");
  fail |= expect(top->o_block_cop_pipeline == 1, "cop pipeline block reason is observable");

  top->i_cop_pipeline_active = 0;
  top->i_frontend_flush = 1;
  top->eval();

  fail |= expect(top->o_allow_second == 0, "frontend flush blocks slot1 allowance");
  fail |= expect(top->o_block_frontend_flush == 1, "frontend flush block reason is observable");

  delete top;
  if (fail) {
    return 1;
  }

  std::printf("PASS: decode pair policy exposes conservative slot1 allowance and block reasons\n");
  return 0;
}
