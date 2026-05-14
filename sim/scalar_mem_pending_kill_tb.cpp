#include "Vscalar_mem_pending_kill_top.h"
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
#define DPI_STUB1(name) extern "C" void name(int) {}
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
DPI_STUB0(mul_low_cnt_dpic)
DPI_STUB0(mul_high_cnt_dpic)
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
DPI_STUB1(redirect_gap_dpic)
DPI_STUB1(redirect_gap_brch_dpic)
DPI_STUB1(redirect_gap_jal_dpic)
DPI_STUB1(redirect_gap_jalr_dpic)
#undef DPI_STUB0
#undef DPI_STUB1

extern "C" void commit_pc_dpic(int) {}
extern "C" void mergesort_loop_dpic(int, int, int, int, int) {}
extern "C" void branch_trace_dpic(int, int, int, int, int, int) {}
extern "C" void commit_trace_dpic(int, int, int, int, int, int, int, int, int,
                                   int, int, int, int, int) {}

static void tick(Vscalar_mem_pending_kill_top *top) {
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
  const char *image = argc > 1 ? argv[1] : "sw/build/scalar/load-repeat.bin";
  if (!load_image(image)) {
    return fail("failed to load test image");
  }

  Vscalar_mem_pending_kill_top *top = new Vscalar_mem_pending_kill_top;
  top->reset = 1;
  top->tb_scalar_flush = 0;
  top->tb_hold_read_resp = 0;
  for (int i = 0; i < 4; i++) tick(top);
  top->reset = 0;

  bool killed_first_scalar_read = false;
  bool observed_kill_pending = false;
  bool observed_stale_r_fire = false;
  bool observed_later_scalar_response = false;

  for (int cycle = 0; cycle < 20000 && !finished; cycle++) {
    tick(top);

    if (!killed_first_scalar_read && top->tb_scalar_mem_ar_fire) {
      if (!top->tb_scalar_mem_req_valid || !top->tb_scalar_mem_service_req_valid) {
        return fail("scalar request did not remain visible at service boundary");
      }
      if (!top->tb_mem_owner_scalar_active || !top->tb_mem_service_req_valid) {
        return fail("scalar service owner boundary was not active on scalar request");
      }
      if (top->tb_mem_service_addr != top->tb_scalar_mem_addr) {
        return fail("scalar service request address did not match scalar request");
      }
      killed_first_scalar_read = true;
      top->tb_hold_read_resp = 1;
      top->tb_scalar_flush = 1;
      tick(top);
      top->tb_scalar_flush = 0;
    }

    if (killed_first_scalar_read && top->tb_scalar_mem_kill_pending) {
      observed_kill_pending = true;
      top->tb_hold_read_resp = 0;
    }

    if (observed_kill_pending && !observed_stale_r_fire && top->tb_scalar_mem_r_fire) {
      observed_stale_r_fire = true;
      if (top->tb_scalar_mem_resp_valid || top->tb_mem_service_resp_valid) {
        return fail("stale scalar completion reached visible response");
      }
    }

    if (observed_stale_r_fire && top->tb_scalar_mem_resp_valid) {
      if (!top->tb_mem_service_resp_valid) {
        return fail("scalar visible response did not reach service response boundary");
      }
      observed_later_scalar_response = true;
    }
  }

  int result = 0;
  if (!killed_first_scalar_read) result |= fail("did not observe first scalar read request");
  if (!observed_kill_pending) result |= fail("did not observe scalar kill-pending state");
  if (!observed_stale_r_fire) result |= fail("did not observe stale scalar read completion");
  if (!observed_later_scalar_response) result |= fail("did not observe later scalar visible response");
  if (!finished) result |= fail("program did not finish after scalar pending-kill scenario");
  if (finished && exit_code != 0) result |= fail("program failed after scalar pending-kill scenario");

  delete top;
  if (result) return 1;
  std::printf("PASS: scalar pending kill drains stale completion and recovers\n");
  return 0;
}
