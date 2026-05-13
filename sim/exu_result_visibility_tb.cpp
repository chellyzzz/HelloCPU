#include "Vhcpu_EXU.h"
#include "verilated.h"
#include <cstdio>

static vluint64_t main_time = 0;

static void tick(Vhcpu_EXU *top) {
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
  Vhcpu_EXU *top = new Vhcpu_EXU;
  int fail = 0;

  top->reset = 1;
  top->i_flush = 0;
  top->i_pre_valid = 0;
  top->i_post_ready = 1;
  top->i_src1 = 0;
  top->i_src2 = 0;
  top->i_pc = 0;
  top->i_imm = 0;
  top->i_src_sel1 = 0;
  top->i_src_sel2 = 0;
  top->i_load = 0;
  top->i_store = 0;
  top->i_brch = 0;
  top->i_jal = 0;
  top->i_jalr = 0;
  top->i_ecall = 0;
  top->i_mret = 0;
  top->i_alu_opt = 0;
  top->exu_opt = 0;
  top->i_muldiv = 0;
  top->i_is_cop_insn = 0;
  top->i_predict_taken = 0;
  top->i_predict_target = 0;
  top->i_predict_btb_hit = 0;
  top->i_rd_addr = 0;
  top->i_rs1_addr = 0;
  top->M_AXI_AWREADY = 0;
  top->M_AXI_WREADY = 0;
  top->M_AXI_RDATA = 0;
  top->M_AXI_RRESP = 0;
  top->M_AXI_RVALID = 0;
  top->M_AXI_RID = 0;
  top->M_AXI_RLAST = 0;
  top->M_AXI_ARREADY = 0;
  top->M_AXI_BRESP = 0;
  top->M_AXI_BVALID = 0;
  top->M_AXI_BID = 0;
  tick(top);
  top->reset = 0;

  top->i_pre_valid = 1;
  top->i_muldiv = 1;
  top->exu_opt = 0;
  top->i_src1 = 6;
  top->i_src2 = 7;
  top->i_flush = 0;
  top->eval();

  fail |= expect(top->o_post_valid == 1, "mul-low result is visible when not flushed");
  fail |= expect(top->o_pre_ready == 1, "mul-low stays ready when done immediately");
  fail |= expect(top->o_res == 42, "mul-low result is computed");

  top->i_flush = 1;
  top->eval();

  fail |= expect(top->o_post_valid == 0, "flush suppresses result visibility");
  fail |= expect(top->o_pre_ready == 1, "flush does not change functional done/ready");
  fail |= expect(top->o_res == 42, "flush filters visibility, not datapath result");

  delete top;
  if (fail) {
    return 1;
  }
  std::printf("PASS: EXU flush filters result visibility from functional completion\n");
  return 0;
}
