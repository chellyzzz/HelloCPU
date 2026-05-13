#include "Vhcpu_cop_backend.h"
#include "verilated.h"
#include <cstdio>

static vluint64_t main_time = 0;

static void tick(Vhcpu_cop_backend *top) {
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

static void wait_ticks(Vhcpu_cop_backend *top, int cycles) {
  for (int index = 0; index < cycles; ++index) {
    tick(top);
  }
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vhcpu_cop_backend *top = new Vhcpu_cop_backend;
  int fail = 0;

  top->reset = 1;
  top->i_flush = 0;
  top->i_pre_valid = 0;
  top->i_post_ready = 0;
  top->i_src1 = 3;
  top->i_src2 = 4;
  top->i_ins = 0;
  top->i_cop_mem_resp_valid = 0;
  top->i_cop_mem_resp_rdata = 0;
  tick(top);
  top->reset = 0;

  top->i_pre_valid = 1;
  tick(top);
  top->i_pre_valid = 0;

  fail |= expect(top->o_busy == 1, "cop backend becomes busy after accept");
  fail |= expect(top->o_post_valid == 0, "no response visible immediately after accept");

  top->i_flush = 1;
  tick(top);
  top->i_flush = 0;

  fail |= expect(top->o_busy == 0, "flush clears cop busy state");
  fail |= expect(top->o_post_valid == 0, "flush clears pending response visibility");
  fail |= expect(top->o_pre_ready == 1, "backend ready again after flush");

  top->i_pre_valid = 1;
  tick(top);
  top->i_pre_valid = 0;

  wait_ticks(top, 4);

  fail |= expect(top->o_post_valid == 1, "response becomes visible without flush");
  fail |= expect(top->o_res == 7, "cop result is preserved until consume");

  top->i_post_ready = 0;
  top->i_flush = 1;
  tick(top);

  fail |= expect(top->o_post_valid == 0, "flush clears visible cop response even when post_ready is low");
  fail |= expect(top->o_busy == 0, "flush leaves backend idle after clearing response");

  delete top;
  if (fail) {
    return 1;
  }
  std::printf("PASS: COP backend flush clears pending and visible responses\n");
  return 0;
}
