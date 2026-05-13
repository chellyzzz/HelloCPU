#include "Vcop_mem_pending_kill_top.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#define MEM_BASE 0x30000000u
#define MEM_SIZE (64u * 1024u * 1024u)
#define HALT_ADDR 0x10000004u

static uint8_t mem[MEM_SIZE];
static int exit_code = -1;
static bool finished = false;

extern "C" void pmem_read(int addr, int *data) {
  uint32_t uaddr = static_cast<uint32_t>(addr);
  if (uaddr == HALT_ADDR) {
    *data = 0;
    return;
  }
  if (uaddr < MEM_BASE || uaddr + 4 > MEM_BASE + MEM_SIZE) {
    *data = 0;
    return;
  }
  std::memcpy(data, &mem[uaddr - MEM_BASE], sizeof(uint32_t));
}

extern "C" void pmem_write(int addr, int data, int strb) {
  uint32_t uaddr = static_cast<uint32_t>(addr);
  if (uaddr == HALT_ADDR) {
    exit_code = data;
    finished = true;
    return;
  }
  if (uaddr < MEM_BASE || uaddr + 4 > MEM_BASE + MEM_SIZE) {
    return;
  }
  uint32_t offset = uaddr - MEM_BASE;
  for (int byte = 0; byte < 4; byte++) {
    if (strb & (1 << byte)) {
      mem[offset + byte] = (data >> (8 * byte)) & 0xff;
    }
  }
}

#define DPI_STUB0(name) extern "C" void name() {}
DPI_STUB0(csr_cnt_dpic)
DPI_STUB0(brch_cnt_dpic)
DPI_STUB0(jal_cnt_dpic)
DPI_STUB0(load_cnt_dpic)
DPI_STUB0(store_cnt_dpic)
DPI_STUB0(inst_cnt_dpic)
DPI_STUB0(ifu_start)
DPI_STUB0(ifu_end)
DPI_STUB0(icache_end)
DPI_STUB0(cache_miss)
DPI_STUB0(load_start)
DPI_STUB0(load_end)
DPI_STUB0(store_start)
DPI_STUB0(store_end)
DPI_STUB0(brch_tkn_dpic)
DPI_STUB0(load_dpic)
DPI_STUB0(store_dpic)
DPI_STUB0(mul_cnt_dpic)
DPI_STUB0(div_cnt_dpic)
DPI_STUB0(cop_cnt_dpic)
DPI_STUB0(alu_cnt_dpic)
DPI_STUB0(sys_cnt_dpic)
DPI_STUB0(fence_cnt_dpic)
DPI_STUB0(stall_cnt_dpic)
DPI_STUB0(stall_front_dpic)
DPI_STUB0(stall_ifu_held_dpic)
DPI_STUB0(stall_ifu_held_ctrl_dpic)
DPI_STUB0(stall_ifu_held_lsu_dpic)
DPI_STUB0(stall_ifu_held_mul_dpic)
DPI_STUB0(stall_ifu_held_mul_only_dpic)
DPI_STUB0(stall_ifu_held_div_dpic)
DPI_STUB0(stall_ifu_held_cop_dpic)
DPI_STUB0(stall_ifu_held_other_dpic)
DPI_STUB0(stall_lsu_dpic)
DPI_STUB0(stall_lsu_start_dpic)
DPI_STUB0(stall_lsu_start_load_dpic)
DPI_STUB0(stall_lsu_start_store_dpic)
DPI_STUB0(stall_lsu_hit_dpic)
DPI_STUB0(stall_lsu_refill_dpic)
DPI_STUB0(stall_lsu_refill_ar_dpic)
DPI_STUB0(stall_lsu_refill_r_dpic)
DPI_STUB0(stall_lsu_uncached_dpic)
DPI_STUB0(stall_lsu_wb_dpic)
DPI_STUB0(stall_mul_dpic)
DPI_STUB0(stall_mul_only_dpic)
DPI_STUB0(stall_div_dpic)
DPI_STUB0(stall_cop_dpic)
DPI_STUB0(stall_ctrl_dpic)
DPI_STUB0(stall_other_dpic)
DPI_STUB0(stall_other_blocked_dpic)
DPI_STUB0(stall_other_pipe_dpic)
DPI_STUB0(stall_other_pipe_alu_dpic)
DPI_STUB0(stall_other_pipe_brch_dpic)
DPI_STUB0(stall_other_pipe_jal_dpic)
DPI_STUB0(stall_other_pipe_jalr_dpic)
DPI_STUB0(stall_other_pipe_sys_dpic)
DPI_STUB0(backend_pipe_occ_dpic)
DPI_STUB0(btb_hit_dpic)
DPI_STUB0(btb_miss_dpic)
DPI_STUB0(btb_misp_dpic)
DPI_STUB0(ras_hit_dpic)
DPI_STUB0(ras_miss_dpic)
DPI_STUB0(jal_tgt_mismatch)
DPI_STUB0(ras_push_dpic)
DPI_STUB0(wbu_pcup_dpic)
DPI_STUB0(wbu_pcup_brch_dpic)
DPI_STUB0(wbu_pcup_jal_dpic)
DPI_STUB0(wbu_pcup_jalr_dpic)
DPI_STUB0(wbu_pcup_ecall_dpic)
DPI_STUB0(wbu_pcup_mret_dpic)
DPI_STUB0(br_misp_pred_nt_dpic)
DPI_STUB0(br_misp_pred_taken_nt_dpic)
DPI_STUB0(br_misp_target_bad_dpic)
DPI_STUB0(br_misp_pred_nt_btb_hit_dpic)
DPI_STUB0(br_misp_pred_nt_btb_miss_dpic)
DPI_STUB0(br_misp_pred_taken_nt_btb_hit_dpic)
DPI_STUB0(br_misp_pred_taken_nt_btb_miss_dpic)
#undef DPI_STUB0

extern "C" void commit_pc_dpic(int) {}
extern "C" void redirect_gap_dpic(int) {}
extern "C" void redirect_gap_brch_dpic(int) {}
extern "C" void redirect_gap_jal_dpic(int) {}
extern "C" void redirect_gap_jalr_dpic(int) {}
extern "C" void mergesort_loop_dpic(int, int, int, int, int) {}
extern "C" void branch_trace_dpic(int, int, int, int, int, int) {}
extern "C" void commit_trace_dpic(int, int, int, int, int, int, int, int, int,
                                  int, int, int, int, int) {}

static void tick(Vcop_mem_pending_kill_top *top) {
  top->clock = 0;
  top->eval();
  top->clock = 1;
  top->eval();
}

static bool load_image(const char *path) {
  FILE *fp = std::fopen(path, "rb");
  if (!fp) {
    std::perror(path);
    return false;
  }
  std::fseek(fp, 0, SEEK_END);
  long size = std::ftell(fp);
  std::fseek(fp, 0, SEEK_SET);
  if (size < 0 || static_cast<unsigned long>(size) > MEM_SIZE) {
    std::fclose(fp);
    return false;
  }
  size_t read_count = std::fread(mem, 1, static_cast<size_t>(size), fp);
  std::fclose(fp);
  return read_count == static_cast<size_t>(size);
}

static int fail(const char *message) {
  std::fprintf(stderr, "FAIL: %s\n", message);
  return 1;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  const char *image = argc > 1 ? argv[1] : "sw/build/vector/cop-vstore-mem.bin";
  if (!load_image(image)) {
    return fail("failed to load test image");
  }

  Vcop_mem_pending_kill_top *top = new Vcop_mem_pending_kill_top;
  top->reset = 1;
  top->tb_cop_kill = 0;
  top->tb_hold_read_resp = 0;
  top->tb_hold_write_req = 0;
  for (int i = 0; i < 4; i++) tick(top);
  top->reset = 0;

  bool observed_store_owner = false;
  bool observed_aw_fire = false;
  bool observed_w_fire = false;
  bool observed_b_fire = false;
  bool observed_store_response = false;
  int aw_fire_count = 0;
  int w_fire_count = 0;
  int b_fire_count = 0;

  for (int cycle = 0; cycle < 20000 && !finished; cycle++) {
    tick(top);

    if (top->tb_cop_mem_bus_active && top->tb_cop_mem_store) {
      observed_store_owner = true;
    }

    if (top->tb_cop_mem_aw_fire) {
      aw_fire_count++;
      observed_aw_fire = true;
      if (!top->tb_cop_mem_store) {
        return fail("COP AW fire was not tagged as store");
      }
      if (top->tb_awaddr != top->tb_cop_mem_addr) {
        return fail("COP AW fire did not match COP memory address");
      }
    }

    if (top->tb_cop_mem_w_fire) {
      w_fire_count++;
      observed_w_fire = true;
      if (!top->tb_cop_mem_store) {
        return fail("COP W fire was not tagged as store");
      }
    }

    if (top->tb_cop_mem_b_fire) {
      b_fire_count++;
      observed_b_fire = true;
      if (!top->tb_cop_mem_store) {
        return fail("COP B fire was not tagged as store");
      }
    }

    if (top->tb_cop_mem_resp_valid) {
      if (!observed_b_fire) {
        return fail("COP store response appeared before B completion");
      }
      observed_store_response = true;
    }
  }

  int result = 0;
  if (!observed_store_owner) result |= fail("did not observe COP store owner");
  if (!observed_aw_fire) result |= fail("did not observe COP AW fire");
  if (!observed_w_fire) result |= fail("did not observe COP W fire");
  if (!observed_b_fire) result |= fail("did not observe COP B fire");
  if (!observed_store_response) result |= fail("did not observe COP store response");
  if (!finished) result |= fail("program did not finish after COP store");
  if (finished && exit_code != 0) result |= fail("program failed after COP store");
  if (result) {
    std::fprintf(stderr,
                 "debug: aw_fire_count=%d w_fire_count=%d b_fire_count=%d exit_code=%d\n",
                 aw_fire_count, w_fire_count, b_fire_count, exit_code);
  }

  delete top;
  if (result) return 1;
  std::printf("PASS: COP store uses AW/W/B owner path and responds after B\n");
  return 0;
}
