#include "Vhcpu_cop_backend.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>

static void tick(Vhcpu_cop_backend *top) {
  top->clock = 0;
  top->eval();
  top->clock = 1;
  top->eval();
}

static int expect(bool condition, const char *message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    return 1;
  }
  return 0;
}

static uint32_t cop_insn(uint32_t funct7, uint32_t funct3) {
  return (funct7 << 25) | (funct3 << 12) | 0x0b;
}

static void issue(Vhcpu_cop_backend *top, uint32_t src1, uint32_t insn) {
  top->i_src1 = src1;
  top->i_src2 = 0;
  top->i_ins = insn;
  top->i_pre_valid = 1;
  tick(top);
  top->i_pre_valid = 0;
}

static int wait_response(Vhcpu_cop_backend *top, uint32_t expected, const char *message) {
  for (int cycle = 0; cycle < 8; cycle++) {
    tick(top);
    if (top->o_post_valid) {
      int fail = expect(top->o_res == expected, message);
      top->i_post_ready = 1;
      tick(top);
      top->i_post_ready = 0;
      return fail;
    }
  }
  return expect(false, "timed out waiting for COP response");
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vhcpu_cop_backend *top = new Vhcpu_cop_backend;
  int fail = 0;

  top->reset = 1;
  top->i_flush = 0;
  top->i_pre_valid = 0;
  top->i_post_ready = 0;
  top->i_src1 = 0;
  top->i_src2 = 0;
  top->i_ins = 0;
  top->i_cop_mem_resp_valid = 0;
  top->i_cop_mem_resp_rdata = 0;
  tick(top);
  top->reset = 0;

  const uint32_t vtype_write = cop_insn(16, 0);
  const uint32_t vtype_read = cop_insn(17, 0);

  issue(top, 0, vtype_write);
  fail |= expect(top->o_busy == 1, "vtype write is pending before flush");
  top->i_flush = 1;
  tick(top);
  top->i_flush = 0;
  fail |= expect(top->o_busy == 0, "flush clears pending vtype write");
  fail |= expect(top->o_post_valid == 0, "flush does not expose killed vtype response");

  issue(top, 2, vtype_write);
  fail |= wait_response(top, 0x80000000u, "later vtype write sees reset vtype after killed write");

  issue(top, 0, vtype_read);
  fail |= wait_response(top, 2, "vtype read sees committed recovery write");

  delete top;
  if (fail) return 1;
  std::printf("PASS: COP backend flush cancels pending vtype write and recovers\n");
  return 0;
}
