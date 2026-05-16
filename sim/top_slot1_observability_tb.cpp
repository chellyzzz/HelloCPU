#include "Vsim_top.h"
#include "Vsim_top___024root.h"
#include "verilated.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

#define MEM_BASE 0x30000000u
#define MEM_SIZE (64 * 1024 * 1024)
#define UART_ADDR 0x10000000u
#define HALT_ADDR 0x10000004u

static uint8_t mem[MEM_SIZE];
static bool finished = false;
static int exit_code = -1;
static uint64_t main_time = 0;
static uint64_t max_cycles = 2000000;

#define EMPTY_DPI0(name) extern "C" void name() {}
#define EMPTY_DPI1(name) extern "C" void name(int) {}

EMPTY_DPI0(csr_cnt_dpic)
EMPTY_DPI0(brch_cnt_dpic)
EMPTY_DPI0(jal_cnt_dpic)
EMPTY_DPI0(load_cnt_dpic)
EMPTY_DPI0(store_cnt_dpic)
EMPTY_DPI0(inst_cnt_dpic)
EMPTY_DPI0(ifu_start)
EMPTY_DPI0(ifu_end)
EMPTY_DPI0(icache_end)
EMPTY_DPI0(cache_miss)
EMPTY_DPI0(load_start)
EMPTY_DPI0(load_end)
EMPTY_DPI0(store_start)
EMPTY_DPI0(store_end)
EMPTY_DPI0(brch_tkn_dpic)
EMPTY_DPI0(load_dpic)
EMPTY_DPI0(store_dpic)
EMPTY_DPI0(mul_cnt_dpic)
EMPTY_DPI0(mul_low_cnt_dpic)
EMPTY_DPI0(mul_high_cnt_dpic)
EMPTY_DPI0(div_cnt_dpic)
EMPTY_DPI0(cop_cnt_dpic)
EMPTY_DPI0(alu_cnt_dpic)
EMPTY_DPI0(sys_cnt_dpic)
EMPTY_DPI0(fence_cnt_dpic)
EMPTY_DPI0(stall_cnt_dpic)
EMPTY_DPI0(stall_front_dpic)
EMPTY_DPI0(stall_ifu_held_dpic)
EMPTY_DPI0(stall_ifu_held_ctrl_dpic)
EMPTY_DPI0(stall_ifu_held_lsu_dpic)
EMPTY_DPI0(stall_ifu_held_mul_dpic)
EMPTY_DPI0(stall_ifu_held_mul_only_dpic)
EMPTY_DPI0(stall_ifu_held_div_dpic)
EMPTY_DPI0(stall_ifu_held_cop_dpic)
EMPTY_DPI0(stall_ifu_held_other_dpic)
EMPTY_DPI0(stall_lsu_dpic)
EMPTY_DPI0(stall_lsu_start_dpic)
EMPTY_DPI0(stall_lsu_start_load_dpic)
EMPTY_DPI0(stall_lsu_start_store_dpic)
EMPTY_DPI0(stall_lsu_hit_dpic)
EMPTY_DPI0(stall_lsu_refill_dpic)
EMPTY_DPI0(stall_lsu_refill_ar_dpic)
EMPTY_DPI0(stall_lsu_refill_r_dpic)
EMPTY_DPI0(stall_lsu_uncached_dpic)
EMPTY_DPI0(stall_lsu_wb_dpic)
EMPTY_DPI0(stall_mul_dpic)
EMPTY_DPI0(stall_mul_only_dpic)
EMPTY_DPI0(stall_div_dpic)
EMPTY_DPI0(stall_cop_dpic)
EMPTY_DPI0(stall_ctrl_dpic)
EMPTY_DPI0(stall_other_dpic)
EMPTY_DPI0(stall_other_blocked_dpic)
EMPTY_DPI0(stall_other_pipe_dpic)
EMPTY_DPI0(stall_other_pipe_alu_dpic)
EMPTY_DPI0(stall_other_pipe_brch_dpic)
EMPTY_DPI0(stall_other_pipe_jal_dpic)
EMPTY_DPI0(stall_other_pipe_jalr_dpic)
EMPTY_DPI0(stall_other_pipe_sys_dpic)
EMPTY_DPI0(backend_pipe_occ_dpic)
EMPTY_DPI0(btb_hit_dpic)
EMPTY_DPI0(btb_miss_dpic)
EMPTY_DPI0(btb_misp_dpic)
EMPTY_DPI0(ras_hit_dpic)
EMPTY_DPI0(ras_miss_dpic)
EMPTY_DPI0(jal_tgt_mismatch)
EMPTY_DPI0(ras_push_dpic)
EMPTY_DPI0(wbu_pcup_dpic)
EMPTY_DPI0(wbu_pcup_brch_dpic)
EMPTY_DPI0(wbu_pcup_jal_dpic)
EMPTY_DPI0(wbu_pcup_jalr_dpic)
EMPTY_DPI0(wbu_pcup_ecall_dpic)
EMPTY_DPI0(wbu_pcup_mret_dpic)
EMPTY_DPI1(redirect_gap_dpic)
EMPTY_DPI1(redirect_gap_brch_dpic)
EMPTY_DPI1(redirect_gap_jal_dpic)
EMPTY_DPI1(redirect_gap_jalr_dpic)

extern "C" void commit_pc_dpic(int) {}
extern "C" void commit_trace_dpic(int, int, int, int, int, int, int, int, int,
                                   int, int, int, int, int) {}
extern "C" void mergesort_loop_dpic(int, int, int, int, int) {}

extern "C" void pmem_read(int addr, int *data) {
  const uint32_t offset = static_cast<uint32_t>(addr) - MEM_BASE;
  if (offset < MEM_SIZE) {
    *data = *reinterpret_cast<int *>(mem + offset);
  } else {
    *data = 0;
  }
}

extern "C" void pmem_write(int addr, int data, int strb) {
  const uint32_t uaddr = static_cast<uint32_t>(addr);
  if (uaddr == UART_ADDR) {
    std::putchar(data & 0xff);
    std::fflush(stdout);
    return;
  }
  if (uaddr == HALT_ADDR) {
    finished = true;
    exit_code = data;
    return;
  }

  const uint32_t offset = uaddr - MEM_BASE;
  if (offset >= MEM_SIZE) {
    return;
  }

  uint8_t *ptr = mem + offset;
  for (int byte = 0; byte < 4; ++byte) {
    if (strb & (1 << byte)) {
      ptr[byte] = (data >> (byte * 8)) & 0xff;
    }
  }
}

static int expect(bool condition, const char *message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    return 1;
  }
  return 0;
}

static void load_image(const char *file) {
  FILE *fp = std::fopen(file, "rb");
  if (!fp) {
    std::fprintf(stderr, "Error: cannot open image '%s'\n", file);
    std::exit(1);
  }

  std::fseek(fp, 0, SEEK_END);
  const long size = std::ftell(fp);
  std::fseek(fp, 0, SEEK_SET);
  if (size < 0 || size > MEM_SIZE) {
    std::fprintf(stderr, "Error: image too large (%ld > %d)\n", size, MEM_SIZE);
    std::exit(1);
  }

  std::memset(mem, 0, sizeof(mem));
  const size_t nread = std::fread(mem, 1, static_cast<size_t>(size), fp);
  std::fclose(fp);
  if (nread != static_cast<size_t>(size)) {
    std::fprintf(stderr, "Error: short read for image '%s'\n", file);
    std::exit(1);
  }
}

struct Slot1Coverage {
  uint64_t slot1_visible_events = 0;
  uint64_t slot1_fireable_events = 0;
  uint64_t slot1_blocked_events = 0;
  uint64_t slot1_blocked_nonflush_events = 0;
  uint64_t slot1_flushed_events = 0;
  uint64_t shadow_capture_events = 0;
  uint64_t shadow_capture_fireable_events = 0;
  uint64_t shadow_capture_blocked_events = 0;
  uint64_t shadow_hold_cycles = 0;
  uint64_t shadow_flush_clear_events = 0;
  uint64_t endpoint_capture_events = 0;
  uint64_t endpoint_capture_fireable_events = 0;
  uint64_t endpoint_capture_blocked_events = 0;
  uint64_t endpoint_hold_cycles = 0;
  uint64_t endpoint_flush_clear_events = 0;
  uint64_t pair_bundle_capture_events = 0;
  uint64_t pair_bundle_capture_fireable_events = 0;
  uint64_t pair_bundle_capture_blocked_events = 0;
  uint64_t pair_bundle_hold_cycles = 0;
  uint64_t pair_bundle_flush_clear_events = 0;
  uint64_t pair_handoff_capture_events = 0;
  uint64_t pair_handoff_capture_fireable_events = 0;
  uint64_t pair_handoff_capture_blocked_events = 0;
  uint64_t pair_handoff_hold_cycles = 0;
  uint64_t pair_handoff_flush_clear_events = 0;
  uint64_t pair_dispatch_capture_events = 0;
  uint64_t pair_dispatch_capture_fireable_events = 0;
  uint64_t pair_dispatch_hold_cycles = 0;
  uint64_t pair_dispatch_flush_clear_events = 0;
  uint64_t lane1_issue_accept_events = 0;
  uint64_t lane1_issue_hold_cycles = 0;
  uint64_t lane1_issue_kill_events = 0;
  uint64_t lane1_issue_flush_clear_events = 0;
};

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  if (argc < 2) {
    std::fprintf(stderr, "Usage: %s <image.bin> [--max-cycles=N]\n", argv[0]);
    return 1;
  }

  for (int i = 2; i < argc; ++i) {
    if (std::strncmp(argv[i], "--max-cycles=", 13) == 0) {
      max_cycles = std::strtoull(argv[i] + 13, nullptr, 10);
    }
  }

  load_image(argv[1]);

  Vsim_top *top = new Vsim_top;
  Vsim_top___024root *root = top->rootp;
  int fail = 0;
  Slot1Coverage coverage;

  top->reset = 1;
  top->clock = 0;
  top->eval();
  for (int i = 0; i < 10; ++i) {
    top->clock = !top->clock;
    top->eval();
    main_time++;
  }

  top->reset = 0;
  top->clock = 0;
  top->eval();

  while (!finished && main_time < max_cycles && !Verilated::gotFinish()) {
    const bool pre_slot1_valid = root->sim_top__DOT__cpu__DOT__decode_slot1_valid;
    const bool pre_frontend_flush = root->sim_top__DOT__cpu__DOT__frontend_flush;
    const bool pre_allow_second = root->sim_top__DOT__cpu__DOT__decode_pair_allow_second;
    const bool pre_frontend_pair_capture = root->sim_top__DOT__cpu__DOT__frontend_pair_capture;
    const bool pre_slot1_endpoint_accept = root->sim_top__DOT__cpu__DOT__slot1_endpoint_accept;
    const uint32_t pre_slot0_pc = root->sim_top__DOT__cpu__DOT__ifu2idu_pc;
    const uint32_t pre_slot0_ins = root->sim_top__DOT__cpu__DOT__ifu2idu_ins;
    const bool pre_slot0_predict_taken = root->sim_top__DOT__cpu__DOT__ifu2idu_predict_taken;
    const uint32_t pre_slot0_predict_target = root->sim_top__DOT__cpu__DOT__ifu2idu_predict_target;
    const bool pre_slot0_predict_btb_hit = root->sim_top__DOT__cpu__DOT__ifu2idu_predict_btb_hit;
    const uint32_t pre_slot0_rd = root->sim_top__DOT__cpu__DOT__ifu2idu_predecode_rd;
    const uint32_t pre_slot0_rs1 = root->sim_top__DOT__cpu__DOT__ifu2idu_predecode_rs1_addr;
    const uint32_t pre_slot0_rs2 = root->sim_top__DOT__cpu__DOT__ifu2idu_predecode_rs2_addr;
    const bool pre_slot0_wen = root->sim_top__DOT__cpu__DOT__ifu2idu_predecode_wen;
    const bool pre_slot0_brch = root->sim_top__DOT__cpu__DOT__ifu2idu_predecode_brch;
    const uint32_t pre_slot0_imm = root->sim_top__DOT__cpu__DOT__imm;
    const uint32_t pre_slot0_csr_addr = root->sim_top__DOT__cpu__DOT__idu_csr_raddr;
    const uint32_t pre_slot0_exu_opt = root->sim_top__DOT__cpu__DOT__exu_opt;
    const uint32_t pre_slot0_alu_opt = root->sim_top__DOT__cpu__DOT__alu_opt;
    const uint32_t pre_slot0_src_sel1 = root->sim_top__DOT__cpu__DOT__i_src_sel1;
    const uint32_t pre_slot0_src_sel2 = root->sim_top__DOT__cpu__DOT__i_src_sel2;
    const bool pre_slot0_csr_wen = root->sim_top__DOT__cpu__DOT__csr_wen;
    const bool pre_slot0_load = root->sim_top__DOT__cpu__DOT__if_load;
    const bool pre_slot0_store = root->sim_top__DOT__cpu__DOT__if_store;
    const bool pre_slot0_jal = root->sim_top__DOT__cpu__DOT__jal;
    const bool pre_slot0_jalr = root->sim_top__DOT__cpu__DOT__jalr;
    const bool pre_slot0_fence_i = root->sim_top__DOT__cpu__DOT__fence_i;
    const bool pre_slot0_muldiv = root->sim_top__DOT__cpu__DOT__muldiv;
    const bool pre_slot0_is_cop_insn = root->sim_top__DOT__cpu__DOT__is_cop_insn;
    const bool pre_slot0_ecall = root->sim_top__DOT__cpu__DOT__ecall;
    const bool pre_slot0_mret = root->sim_top__DOT__cpu__DOT__mret;
    const bool pre_slot0_ebreak = root->sim_top__DOT__cpu__DOT__ebreak;
    const uint32_t pre_pair_slot0_src1_data = root->sim_top__DOT__cpu__DOT__pair_slot0_src1_data;
    const uint32_t pre_pair_slot0_src2_data = root->sim_top__DOT__cpu__DOT__pair_slot0_src2_data;
    const bool pre_pair_candidate_alu_branch = root->sim_top__DOT__cpu__DOT__ifu_pair_candidate_alu_branch;
    const bool pre_pair_order_alu_then_branch = root->sim_top__DOT__cpu__DOT__ifu_pair_order_alu_then_branch;
    const bool pre_pair_order_branch_then_alu = root->sim_top__DOT__cpu__DOT__ifu_pair_order_branch_then_alu;
    const bool pre_pair_block_raw = root->sim_top__DOT__cpu__DOT__decode_pair_block_raw;
    const bool pre_pair_block_waw = root->sim_top__DOT__cpu__DOT__decode_pair_block_waw;
    const bool pre_pair_block_dual_writeback = root->sim_top__DOT__cpu__DOT__decode_pair_block_dual_writeback;
    const bool pre_pair_block_exclusive_backend = root->sim_top__DOT__cpu__DOT__decode_pair_block_exclusive_backend;
    const bool pre_pair_block_redirect_control = root->sim_top__DOT__cpu__DOT__decode_pair_block_redirect_control;
    const bool pre_pair_block_older_branch_first = root->sim_top__DOT__cpu__DOT__decode_pair_block_older_branch_first;
    const bool pre_pair_block_downstream_busy = root->sim_top__DOT__cpu__DOT__decode_pair_block_downstream_busy;
    const bool pre_pair_block_cop_pipeline = root->sim_top__DOT__cpu__DOT__decode_pair_block_cop_pipeline;
    const bool pre_pair_block_frontend_flush = root->sim_top__DOT__cpu__DOT__decode_pair_block_frontend_flush;
    const uint32_t pre_slot1_pc = root->sim_top__DOT__cpu__DOT__decode_slot1_pc;
    const uint32_t pre_slot1_ins = root->sim_top__DOT__cpu__DOT__decode_slot1_ins;
    const uint32_t pre_slot1_imm = root->sim_top__DOT__cpu__DOT__decode_slot1_imm;
    const uint32_t pre_slot1_rd = root->sim_top__DOT__cpu__DOT__decode_slot1_rd;
    const uint32_t pre_slot1_rs1 = root->sim_top__DOT__cpu__DOT__decode_slot1_rs1;
    const uint32_t pre_slot1_rs2 = root->sim_top__DOT__cpu__DOT__decode_slot1_rs2;
    const uint32_t pre_slot1_csr_addr = root->sim_top__DOT__cpu__DOT__decode_slot1_csr_addr;
    const uint32_t pre_slot1_exu_opt = root->sim_top__DOT__cpu__DOT__decode_slot1_exu_opt;
    const uint32_t pre_slot1_alu_opt = root->sim_top__DOT__cpu__DOT__decode_slot1_alu_opt;
    const uint32_t pre_slot1_src_sel1 = root->sim_top__DOT__cpu__DOT__decode_slot1_src_sel1;
    const uint32_t pre_slot1_src_sel2 = root->sim_top__DOT__cpu__DOT__decode_slot1_src_sel2;
    const bool pre_slot1_wen = root->sim_top__DOT__cpu__DOT__decode_slot1_wen;
    const bool pre_slot1_brch = root->sim_top__DOT__cpu__DOT__decode_slot1_brch;
    const bool pre_slot1_csr_wen = root->sim_top__DOT__cpu__DOT__decode_slot1_csr_wen;
    const bool pre_slot1_load = root->sim_top__DOT__cpu__DOT__decode_slot1_load;
    const bool pre_slot1_store = root->sim_top__DOT__cpu__DOT__decode_slot1_store;
    const bool pre_slot1_jal = root->sim_top__DOT__cpu__DOT__decode_slot1_jal;
    const bool pre_slot1_jalr = root->sim_top__DOT__cpu__DOT__decode_slot1_jalr;
    const bool pre_slot1_fence_i = root->sim_top__DOT__cpu__DOT__decode_slot1_fence_i;
    const bool pre_slot1_muldiv = root->sim_top__DOT__cpu__DOT__decode_slot1_muldiv;
    const bool pre_slot1_is_cop_insn = root->sim_top__DOT__cpu__DOT__decode_slot1_is_cop_insn;
    const bool pre_slot1_ecall = root->sim_top__DOT__cpu__DOT__decode_slot1_ecall;
    const bool pre_slot1_mret = root->sim_top__DOT__cpu__DOT__decode_slot1_mret;
    const bool pre_slot1_ebreak = root->sim_top__DOT__cpu__DOT__decode_slot1_ebreak;
    const uint32_t pre_pair_younger_pc = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_pc;
    const uint32_t pre_pair_younger_ins = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_ins;
    const uint32_t pre_pair_younger_rd = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_rd;
    const uint32_t pre_pair_younger_rs1 = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_rs1_addr;
    const uint32_t pre_pair_younger_rs2 = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_rs2_addr;
    const bool pre_pair_younger_wen = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_wen;
    const bool pre_pair_younger_brch = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_brch;
    const bool pre_pair_younger_predict_taken = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predict_taken;
    const uint32_t pre_pair_younger_predict_target = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predict_target;
    const bool pre_pair_younger_predict_btb_hit = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predict_btb_hit;
    const uint32_t pre_pair_slot1_imm = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_imm;
    const uint32_t pre_pair_slot1_rd = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_rd;
    const uint32_t pre_pair_slot1_rs1 = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_rs1;
    const uint32_t pre_pair_slot1_rs2 = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_rs2;
    const uint32_t pre_pair_slot1_csr_addr = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_csr_addr;
    const uint32_t pre_pair_slot1_exu_opt = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_exu_opt;
    const uint32_t pre_pair_slot1_alu_opt = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_alu_opt;
    const uint32_t pre_pair_slot1_src_sel1 = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_src_sel1;
    const uint32_t pre_pair_slot1_src_sel2 = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_src_sel2;
    const bool pre_pair_slot1_wen = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_wen;
    const bool pre_pair_slot1_brch = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_brch;
    const bool pre_pair_slot1_csr_wen = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_csr_wen;
    const bool pre_pair_slot1_load = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_load;
    const bool pre_pair_slot1_store = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_store;
    const bool pre_pair_slot1_jal = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_jal;
    const bool pre_pair_slot1_jalr = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_jalr;
    const bool pre_pair_slot1_fence_i = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_fence_i;
    const bool pre_pair_slot1_muldiv = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_muldiv;
    const bool pre_pair_slot1_is_cop_insn = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_is_cop_insn;
    const bool pre_pair_slot1_ecall = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_ecall;
    const bool pre_pair_slot1_mret = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_mret;
    const bool pre_pair_slot1_ebreak = root->sim_top__DOT__cpu__DOT__pair_slot1_decode_ebreak;
    const uint32_t pre_pair_slot1_src1_data = root->sim_top__DOT__cpu__DOT__pair_slot1_src1_data;
    const uint32_t pre_pair_slot1_src2_data = root->sim_top__DOT__cpu__DOT__pair_slot1_src2_data;
    const bool pre_shadow_valid = root->sim_top__DOT__cpu__DOT__slot1_shadow_valid;
    const uint32_t pre_shadow_pc = root->sim_top__DOT__cpu__DOT__slot1_shadow_pc;
    const uint32_t pre_shadow_ins = root->sim_top__DOT__cpu__DOT__slot1_shadow_ins;
    const uint32_t pre_shadow_imm = root->sim_top__DOT__cpu__DOT__slot1_shadow_imm;
    const uint32_t pre_shadow_rd = root->sim_top__DOT__cpu__DOT__slot1_shadow_rd;
    const uint32_t pre_shadow_rs1 = root->sim_top__DOT__cpu__DOT__slot1_shadow_rs1;
    const uint32_t pre_shadow_rs2 = root->sim_top__DOT__cpu__DOT__slot1_shadow_rs2;
    const uint32_t pre_shadow_csr_addr = root->sim_top__DOT__cpu__DOT__slot1_shadow_csr_addr;
    const uint32_t pre_shadow_exu_opt = root->sim_top__DOT__cpu__DOT__slot1_shadow_exu_opt;
    const uint32_t pre_shadow_alu_opt = root->sim_top__DOT__cpu__DOT__slot1_shadow_alu_opt;
    const uint32_t pre_shadow_src_sel1 = root->sim_top__DOT__cpu__DOT__slot1_shadow_src_sel1;
    const uint32_t pre_shadow_src_sel2 = root->sim_top__DOT__cpu__DOT__slot1_shadow_src_sel2;
    const bool pre_shadow_wen = root->sim_top__DOT__cpu__DOT__slot1_shadow_wen;
    const bool pre_shadow_brch = root->sim_top__DOT__cpu__DOT__slot1_shadow_brch;
    const bool pre_shadow_csr_wen = root->sim_top__DOT__cpu__DOT__slot1_shadow_csr_wen;
    const bool pre_shadow_load = root->sim_top__DOT__cpu__DOT__slot1_shadow_load;
    const bool pre_shadow_store = root->sim_top__DOT__cpu__DOT__slot1_shadow_store;
    const bool pre_shadow_jal = root->sim_top__DOT__cpu__DOT__slot1_shadow_jal;
    const bool pre_shadow_jalr = root->sim_top__DOT__cpu__DOT__slot1_shadow_jalr;
    const bool pre_shadow_fence_i = root->sim_top__DOT__cpu__DOT__slot1_shadow_fence_i;
    const bool pre_shadow_muldiv = root->sim_top__DOT__cpu__DOT__slot1_shadow_muldiv;
    const bool pre_shadow_is_cop_insn = root->sim_top__DOT__cpu__DOT__slot1_shadow_is_cop_insn;
    const bool pre_shadow_ecall = root->sim_top__DOT__cpu__DOT__slot1_shadow_ecall;
    const bool pre_shadow_mret = root->sim_top__DOT__cpu__DOT__slot1_shadow_mret;
    const bool pre_shadow_ebreak = root->sim_top__DOT__cpu__DOT__slot1_shadow_ebreak;
    const bool pre_shadow_fireable = root->sim_top__DOT__cpu__DOT__slot1_shadow_fireable;
    const bool pre_shadow_predict_taken = root->sim_top__DOT__cpu__DOT__slot1_shadow_predict_taken;
    const uint32_t pre_shadow_predict_target = root->sim_top__DOT__cpu__DOT__slot1_shadow_predict_target;
    const bool pre_shadow_predict_btb_hit = root->sim_top__DOT__cpu__DOT__slot1_shadow_predict_btb_hit;
    const bool pre_endpoint_valid = root->sim_top__DOT__cpu__DOT__slot1_endpoint_valid;
    const uint32_t pre_endpoint_pc = root->sim_top__DOT__cpu__DOT__slot1_endpoint_pc;
    const uint32_t pre_endpoint_ins = root->sim_top__DOT__cpu__DOT__slot1_endpoint_ins;
    const uint32_t pre_endpoint_imm = root->sim_top__DOT__cpu__DOT__slot1_endpoint_imm;
    const uint32_t pre_endpoint_rd = root->sim_top__DOT__cpu__DOT__slot1_endpoint_rd;
    const uint32_t pre_endpoint_rs1 = root->sim_top__DOT__cpu__DOT__slot1_endpoint_rs1;
    const uint32_t pre_endpoint_rs2 = root->sim_top__DOT__cpu__DOT__slot1_endpoint_rs2;
    const uint32_t pre_endpoint_csr_addr = root->sim_top__DOT__cpu__DOT__slot1_endpoint_csr_addr;
    const uint32_t pre_endpoint_exu_opt = root->sim_top__DOT__cpu__DOT__slot1_endpoint_exu_opt;
    const uint32_t pre_endpoint_alu_opt = root->sim_top__DOT__cpu__DOT__slot1_endpoint_alu_opt;
    const uint32_t pre_endpoint_src_sel1 = root->sim_top__DOT__cpu__DOT__slot1_endpoint_src_sel1;
    const uint32_t pre_endpoint_src_sel2 = root->sim_top__DOT__cpu__DOT__slot1_endpoint_src_sel2;
    const bool pre_endpoint_wen = root->sim_top__DOT__cpu__DOT__slot1_endpoint_wen;
    const bool pre_endpoint_brch = root->sim_top__DOT__cpu__DOT__slot1_endpoint_brch;
    const bool pre_endpoint_csr_wen = root->sim_top__DOT__cpu__DOT__slot1_endpoint_csr_wen;
    const bool pre_endpoint_load = root->sim_top__DOT__cpu__DOT__slot1_endpoint_load;
    const bool pre_endpoint_store = root->sim_top__DOT__cpu__DOT__slot1_endpoint_store;
    const bool pre_endpoint_jal = root->sim_top__DOT__cpu__DOT__slot1_endpoint_jal;
    const bool pre_endpoint_jalr = root->sim_top__DOT__cpu__DOT__slot1_endpoint_jalr;
    const bool pre_endpoint_fence_i = root->sim_top__DOT__cpu__DOT__slot1_endpoint_fence_i;
    const bool pre_endpoint_muldiv = root->sim_top__DOT__cpu__DOT__slot1_endpoint_muldiv;
    const bool pre_endpoint_is_cop_insn = root->sim_top__DOT__cpu__DOT__slot1_endpoint_is_cop_insn;
    const bool pre_endpoint_ecall = root->sim_top__DOT__cpu__DOT__slot1_endpoint_ecall;
    const bool pre_endpoint_mret = root->sim_top__DOT__cpu__DOT__slot1_endpoint_mret;
    const bool pre_endpoint_ebreak = root->sim_top__DOT__cpu__DOT__slot1_endpoint_ebreak;
    const bool pre_endpoint_fireable = root->sim_top__DOT__cpu__DOT__slot1_endpoint_fireable;
    const bool pre_endpoint_predict_taken = root->sim_top__DOT__cpu__DOT__slot1_endpoint_predict_taken;
    const uint32_t pre_endpoint_predict_target = root->sim_top__DOT__cpu__DOT__slot1_endpoint_predict_target;
    const bool pre_endpoint_predict_btb_hit = root->sim_top__DOT__cpu__DOT__slot1_endpoint_predict_btb_hit;
    const bool pre_pair_bundle_valid = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_valid;
    const bool pre_pair_bundle_slot0_valid = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_valid;
    const uint32_t pre_pair_bundle_slot0_pc = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_pc;
    const uint32_t pre_pair_bundle_slot0_ins = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_ins;
    const bool pre_pair_bundle_slot0_predict_taken = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_predict_taken;
    const uint32_t pre_pair_bundle_slot0_predict_target = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_predict_target;
    const bool pre_pair_bundle_slot0_predict_btb_hit = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_predict_btb_hit;
    const uint32_t pre_pair_bundle_slot0_rd = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rd;
    const uint32_t pre_pair_bundle_slot0_rs1 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rs1;
    const uint32_t pre_pair_bundle_slot0_rs2 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rs2;
    const uint32_t pre_pair_bundle_slot0_rs1_addr = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rs1_addr;
    const bool pre_pair_bundle_slot0_wen = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_wen;
    const bool pre_pair_bundle_slot0_brch = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_brch;
    const uint32_t pre_pair_bundle_slot0_src1 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_src1;
    const uint32_t pre_pair_bundle_slot0_src2 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_src2;
    const uint32_t pre_pair_bundle_slot0_imm = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_imm;
    const uint32_t pre_pair_bundle_slot0_csr_addr = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_csr_addr;
    const uint32_t pre_pair_bundle_slot0_exu_opt = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_exu_opt;
    const uint32_t pre_pair_bundle_slot0_alu_opt = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_alu_opt;
    const uint32_t pre_pair_bundle_slot0_src_sel1 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_src_sel1;
    const uint32_t pre_pair_bundle_slot0_src_sel2 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_src_sel2;
    const bool pre_pair_bundle_slot0_csr_wen = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_csr_wen;
    const bool pre_pair_bundle_slot0_load = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_load;
    const bool pre_pair_bundle_slot0_store = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_store;
    const bool pre_pair_bundle_slot0_jal = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_jal;
    const bool pre_pair_bundle_slot0_jalr = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_jalr;
    const bool pre_pair_bundle_slot0_fence_i = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_fence_i;
    const bool pre_pair_bundle_slot0_muldiv = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_muldiv;
    const bool pre_pair_bundle_slot0_is_cop_insn = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_is_cop_insn;
    const bool pre_pair_bundle_slot0_ecall = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_ecall;
    const bool pre_pair_bundle_slot0_mret = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_mret;
    const bool pre_pair_bundle_slot0_ebreak = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_ebreak;
    const bool pre_pair_bundle_slot1_valid = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_valid;
    const uint32_t pre_pair_bundle_slot1_pc = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_pc;
    const uint32_t pre_pair_bundle_slot1_ins = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_ins;
    const bool pre_pair_bundle_slot1_predict_taken = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_predict_taken;
    const uint32_t pre_pair_bundle_slot1_predict_target = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_predict_target;
    const bool pre_pair_bundle_slot1_predict_btb_hit = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_predict_btb_hit;
    const uint32_t pre_pair_bundle_slot1_rd = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rd;
    const uint32_t pre_pair_bundle_slot1_rs1 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rs1;
    const uint32_t pre_pair_bundle_slot1_rs2 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rs2;
    const uint32_t pre_pair_bundle_slot1_rs1_addr = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rs1_addr;
    const bool pre_pair_bundle_slot1_wen = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_wen;
    const bool pre_pair_bundle_slot1_brch = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_brch;
    const uint32_t pre_pair_bundle_slot1_src1 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_src1;
    const uint32_t pre_pair_bundle_slot1_src2 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_src2;
    const uint32_t pre_pair_bundle_slot1_imm = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_imm;
    const uint32_t pre_pair_bundle_slot1_csr_addr = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_csr_addr;
    const uint32_t pre_pair_bundle_slot1_exu_opt = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_exu_opt;
    const uint32_t pre_pair_bundle_slot1_alu_opt = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_alu_opt;
    const uint32_t pre_pair_bundle_slot1_src_sel1 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_src_sel1;
    const uint32_t pre_pair_bundle_slot1_src_sel2 = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_src_sel2;
    const bool pre_pair_bundle_slot1_csr_wen = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_csr_wen;
    const bool pre_pair_bundle_slot1_load = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_load;
    const bool pre_pair_bundle_slot1_store = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_store;
    const bool pre_pair_bundle_slot1_jal = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_jal;
    const bool pre_pair_bundle_slot1_jalr = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_jalr;
    const bool pre_pair_bundle_slot1_fence_i = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_fence_i;
    const bool pre_pair_bundle_slot1_muldiv = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_muldiv;
    const bool pre_pair_bundle_slot1_is_cop_insn = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_is_cop_insn;
    const bool pre_pair_bundle_slot1_ecall = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_ecall;
    const bool pre_pair_bundle_slot1_mret = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_mret;
    const bool pre_pair_bundle_slot1_ebreak = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_ebreak;
    const bool pre_pair_bundle_candidate_alu_branch = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_candidate_alu_branch;
    const bool pre_pair_bundle_allow_second = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_allow_second;
    const bool pre_pair_bundle_order_alu_then_branch = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_order_alu_then_branch;
    const bool pre_pair_bundle_order_branch_then_alu = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_order_branch_then_alu;
    const bool pre_pair_bundle_block_raw = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_raw;
    const bool pre_pair_bundle_block_waw = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_waw;
    const bool pre_pair_bundle_block_dual_writeback = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_dual_writeback;
    const bool pre_pair_bundle_block_exclusive_backend = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_exclusive_backend;
    const bool pre_pair_bundle_block_redirect_control = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_redirect_control;
    const bool pre_pair_bundle_block_older_branch_first = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_older_branch_first;
    const bool pre_pair_bundle_block_downstream_busy = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_downstream_busy;
    const bool pre_pair_bundle_block_cop_pipeline = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_cop_pipeline;
    const bool pre_pair_bundle_block_frontend_flush = root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_frontend_flush;
    const bool pre_pair_handoff_valid = root->sim_top__DOT__cpu__DOT__pair_handoff_valid;
    const bool pre_pair_handoff_slot0_valid = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_valid;
    const uint32_t pre_pair_handoff_slot0_pc = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_pc;
    const uint32_t pre_pair_handoff_slot0_ins = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_ins;
    const uint32_t pre_pair_handoff_slot0_src1 = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src1;
    const uint32_t pre_pair_handoff_slot0_src2 = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src2;
    const uint32_t pre_pair_handoff_slot0_imm = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_imm;
    const uint32_t pre_pair_handoff_slot0_src_sel1 = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src_sel1;
    const uint32_t pre_pair_handoff_slot0_src_sel2 = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src_sel2;
    const uint32_t pre_pair_handoff_slot0_rd = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_rd;
    const uint32_t pre_pair_handoff_slot0_csr_addr = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_csr_addr;
    const uint32_t pre_pair_handoff_slot0_exu_opt = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_exu_opt;
    const uint32_t pre_pair_handoff_slot0_alu_opt = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_alu_opt;
    const bool pre_pair_handoff_slot0_wen = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_wen;
    const bool pre_pair_handoff_slot0_csr_wen = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_csr_wen;
    const bool pre_pair_handoff_slot0_mret = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_mret;
    const bool pre_pair_handoff_slot0_ecall = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_ecall;
    const bool pre_pair_handoff_slot0_load = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_load;
    const bool pre_pair_handoff_slot0_store = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_store;
    const bool pre_pair_handoff_slot0_brch = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_brch;
    const bool pre_pair_handoff_slot0_jal = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_jal;
    const bool pre_pair_handoff_slot0_jalr = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_jalr;
    const bool pre_pair_handoff_slot0_ebreak = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_ebreak;
    const bool pre_pair_handoff_slot0_fence_i = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_fence_i;
    const bool pre_pair_handoff_slot0_muldiv = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_muldiv;
    const bool pre_pair_handoff_slot0_is_cop_insn = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_is_cop_insn;
    const bool pre_pair_handoff_slot0_predict_taken = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_predict_taken;
    const uint32_t pre_pair_handoff_slot0_predict_target = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_predict_target;
    const bool pre_pair_handoff_slot0_predict_btb_hit = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_predict_btb_hit;
    const uint32_t pre_pair_handoff_slot0_rs1_addr = root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_rs1_addr;
    const bool pre_pair_handoff_slot1_valid = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_valid;
    const uint32_t pre_pair_handoff_slot1_pc = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_pc;
    const uint32_t pre_pair_handoff_slot1_ins = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_ins;
    const uint32_t pre_pair_handoff_slot1_src1 = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src1;
    const uint32_t pre_pair_handoff_slot1_src2 = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src2;
    const uint32_t pre_pair_handoff_slot1_imm = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_imm;
    const uint32_t pre_pair_handoff_slot1_src_sel1 = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src_sel1;
    const uint32_t pre_pair_handoff_slot1_src_sel2 = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src_sel2;
    const uint32_t pre_pair_handoff_slot1_rd = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_rd;
    const uint32_t pre_pair_handoff_slot1_csr_addr = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_csr_addr;
    const uint32_t pre_pair_handoff_slot1_exu_opt = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_exu_opt;
    const uint32_t pre_pair_handoff_slot1_alu_opt = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_alu_opt;
    const bool pre_pair_handoff_slot1_wen = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_wen;
    const bool pre_pair_handoff_slot1_csr_wen = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_csr_wen;
    const bool pre_pair_handoff_slot1_mret = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_mret;
    const bool pre_pair_handoff_slot1_ecall = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_ecall;
    const bool pre_pair_handoff_slot1_load = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_load;
    const bool pre_pair_handoff_slot1_store = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_store;
    const bool pre_pair_handoff_slot1_brch = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_brch;
    const bool pre_pair_handoff_slot1_jal = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_jal;
    const bool pre_pair_handoff_slot1_jalr = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_jalr;
    const bool pre_pair_handoff_slot1_ebreak = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_ebreak;
    const bool pre_pair_handoff_slot1_fence_i = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_fence_i;
    const bool pre_pair_handoff_slot1_muldiv = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_muldiv;
    const bool pre_pair_handoff_slot1_is_cop_insn = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_is_cop_insn;
    const bool pre_pair_handoff_slot1_predict_taken = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_predict_taken;
    const uint32_t pre_pair_handoff_slot1_predict_target = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_predict_target;
    const bool pre_pair_handoff_slot1_predict_btb_hit = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_predict_btb_hit;
    const uint32_t pre_pair_handoff_slot1_rs1_addr = root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_rs1_addr;
    const bool pre_pair_handoff_candidate_alu_branch = root->sim_top__DOT__cpu__DOT__pair_handoff_candidate_alu_branch;
    const bool pre_pair_handoff_allow_second = root->sim_top__DOT__cpu__DOT__pair_handoff_allow_second;
    const bool pre_pair_handoff_order_alu_then_branch = root->sim_top__DOT__cpu__DOT__pair_handoff_order_alu_then_branch;
    const bool pre_pair_handoff_order_branch_then_alu = root->sim_top__DOT__cpu__DOT__pair_handoff_order_branch_then_alu;
    const bool pre_pair_handoff_block_raw = root->sim_top__DOT__cpu__DOT__pair_handoff_block_raw;
    const bool pre_pair_handoff_block_waw = root->sim_top__DOT__cpu__DOT__pair_handoff_block_waw;
    const bool pre_pair_handoff_block_dual_writeback = root->sim_top__DOT__cpu__DOT__pair_handoff_block_dual_writeback;
    const bool pre_pair_handoff_block_exclusive_backend = root->sim_top__DOT__cpu__DOT__pair_handoff_block_exclusive_backend;
    const bool pre_pair_handoff_block_redirect_control = root->sim_top__DOT__cpu__DOT__pair_handoff_block_redirect_control;
    const bool pre_pair_handoff_block_older_branch_first = root->sim_top__DOT__cpu__DOT__pair_handoff_block_older_branch_first;
    const bool pre_pair_handoff_block_downstream_busy = root->sim_top__DOT__cpu__DOT__pair_handoff_block_downstream_busy;
    const bool pre_pair_handoff_block_cop_pipeline = root->sim_top__DOT__cpu__DOT__pair_handoff_block_cop_pipeline;
    const bool pre_pair_handoff_block_frontend_flush = root->sim_top__DOT__cpu__DOT__pair_handoff_block_frontend_flush;
    const bool pre_handoff_scoreboard_allow_second = root->sim_top__DOT__cpu__DOT__handoff_scoreboard_allow_second;
    const bool pre_pair_dispatch_valid = root->sim_top__DOT__cpu__DOT__pair_dispatch_valid;
    const bool pre_pair_dispatch_slot0_valid = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_valid;
    const uint32_t pre_pair_dispatch_slot0_pc = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_pc;
    const uint32_t pre_pair_dispatch_slot0_ins = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_ins;
    const uint32_t pre_pair_dispatch_slot0_src1 = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src1;
    const uint32_t pre_pair_dispatch_slot0_src2 = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src2;
    const uint32_t pre_pair_dispatch_slot0_imm = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_imm;
    const uint32_t pre_pair_dispatch_slot0_src_sel1 = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src_sel1;
    const uint32_t pre_pair_dispatch_slot0_src_sel2 = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src_sel2;
    const uint32_t pre_pair_dispatch_slot0_rd = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_rd;
    const uint32_t pre_pair_dispatch_slot0_csr_addr = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_csr_addr;
    const uint32_t pre_pair_dispatch_slot0_exu_opt = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_exu_opt;
    const uint32_t pre_pair_dispatch_slot0_alu_opt = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_alu_opt;
    const bool pre_pair_dispatch_slot0_wen = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_wen;
    const bool pre_pair_dispatch_slot0_csr_wen = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_csr_wen;
    const bool pre_pair_dispatch_slot0_mret = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_mret;
    const bool pre_pair_dispatch_slot0_ecall = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_ecall;
    const bool pre_pair_dispatch_slot0_load = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_load;
    const bool pre_pair_dispatch_slot0_store = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_store;
    const bool pre_pair_dispatch_slot0_brch = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_brch;
    const bool pre_pair_dispatch_slot0_jal = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_jal;
    const bool pre_pair_dispatch_slot0_jalr = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_jalr;
    const bool pre_pair_dispatch_slot0_ebreak = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_ebreak;
    const bool pre_pair_dispatch_slot0_fence_i = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_fence_i;
    const bool pre_pair_dispatch_slot0_muldiv = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_muldiv;
    const bool pre_pair_dispatch_slot0_is_cop_insn = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_is_cop_insn;
    const bool pre_pair_dispatch_slot0_predict_taken = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_predict_taken;
    const uint32_t pre_pair_dispatch_slot0_predict_target = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_predict_target;
    const bool pre_pair_dispatch_slot0_predict_btb_hit = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_predict_btb_hit;
    const uint32_t pre_pair_dispatch_slot0_rs1_addr = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_rs1_addr;
    const bool pre_pair_dispatch_slot1_valid = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_valid;
    const uint32_t pre_pair_dispatch_slot1_pc = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_pc;
    const uint32_t pre_pair_dispatch_slot1_ins = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_ins;
    const uint32_t pre_pair_dispatch_slot1_src1 = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src1;
    const uint32_t pre_pair_dispatch_slot1_src2 = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src2;
    const uint32_t pre_pair_dispatch_slot1_imm = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_imm;
    const uint32_t pre_pair_dispatch_slot1_src_sel1 = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src_sel1;
    const uint32_t pre_pair_dispatch_slot1_src_sel2 = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src_sel2;
    const uint32_t pre_pair_dispatch_slot1_rd = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_rd;
    const uint32_t pre_pair_dispatch_slot1_csr_addr = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_csr_addr;
    const uint32_t pre_pair_dispatch_slot1_exu_opt = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_exu_opt;
    const uint32_t pre_pair_dispatch_slot1_alu_opt = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_alu_opt;
    const bool pre_pair_dispatch_slot1_wen = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_wen;
    const bool pre_pair_dispatch_slot1_csr_wen = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_csr_wen;
    const bool pre_pair_dispatch_slot1_mret = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_mret;
    const bool pre_pair_dispatch_slot1_ecall = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_ecall;
    const bool pre_pair_dispatch_slot1_load = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_load;
    const bool pre_pair_dispatch_slot1_store = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_store;
    const bool pre_pair_dispatch_slot1_brch = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_brch;
    const bool pre_pair_dispatch_slot1_jal = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_jal;
    const bool pre_pair_dispatch_slot1_jalr = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_jalr;
    const bool pre_pair_dispatch_slot1_ebreak = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_ebreak;
    const bool pre_pair_dispatch_slot1_fence_i = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_fence_i;
    const bool pre_pair_dispatch_slot1_muldiv = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_muldiv;
    const bool pre_pair_dispatch_slot1_is_cop_insn = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_is_cop_insn;
    const bool pre_pair_dispatch_slot1_predict_taken = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_predict_taken;
    const uint32_t pre_pair_dispatch_slot1_predict_target = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_predict_target;
    const bool pre_pair_dispatch_slot1_predict_btb_hit = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_predict_btb_hit;
    const uint32_t pre_pair_dispatch_slot1_rs1_addr = root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_rs1_addr;
    const bool pre_pair_dispatch_candidate_alu_branch = root->sim_top__DOT__cpu__DOT__pair_dispatch_candidate_alu_branch;
    const bool pre_pair_dispatch_allow_second = root->sim_top__DOT__cpu__DOT__pair_dispatch_allow_second;
    const bool pre_pair_dispatch_order_alu_then_branch = root->sim_top__DOT__cpu__DOT__pair_dispatch_order_alu_then_branch;
    const bool pre_pair_dispatch_order_branch_then_alu = root->sim_top__DOT__cpu__DOT__pair_dispatch_order_branch_then_alu;
    const bool pre_lane1_issue_valid = root->sim_top__DOT__cpu__DOT__lane1_issue_valid;
    const bool pre_lane1_issue_accept = root->sim_top__DOT__cpu__DOT__lane1_issue_accept;
    const bool pre_lane1_issue_kill = root->sim_top__DOT__cpu__DOT__lane1_issue_kill;

    top->clock = 1;
    top->eval();
    main_time++;

    const bool slot1_valid = root->sim_top__DOT__cpu__DOT__decode_slot1_valid;
    const bool frontend_flush = root->sim_top__DOT__cpu__DOT__frontend_flush;

    if (slot1_valid) {
      coverage.slot1_visible_events++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot0_valid == 1,
                     "slot1 observability requires slot0 to remain visible");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_is_branch == 1,
                     "slot1 observability keeps younger branch classification");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_brch == 1,
                     "slot1 decode surface sees branch control class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_wen == 0,
                     "slot1 decode surface remains non-writing");
      fail |= expect(root->sim_top__DOT__cpu__DOT__ifu_pair_younger_valid == 1,
                     "slot1 observability requires a younger queue entry");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_pc ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_pc,
                     "slot1 pc tracks the younger queued entry");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_ins ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_ins,
                     "slot1 instruction tracks the younger queued entry");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_rd ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_rd,
                     "slot1 rd metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_rs1 ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_rs1_addr,
                     "slot1 rs1 metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_rs2 ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_rs2_addr,
                     "slot1 rs2 metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_wen ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_wen,
                     "slot1 wen metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_csr_wen ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_csr_wen,
                     "slot1 csr_wen metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_load ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_load,
                     "slot1 load metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_store ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_store,
                     "slot1 store metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_jal ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_jal,
                     "slot1 jal metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_jalr ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_jalr,
                     "slot1 jalr metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_fence_i ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_fence_i,
                     "slot1 fence_i metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_muldiv ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_muldiv,
                     "slot1 muldiv metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_is_cop_insn ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_is_cop_insn,
                     "slot1 cop metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_ecall ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_ecall,
                     "slot1 ecall metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_mret ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_mret,
                     "slot1 mret metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_ebreak ==
                         root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predecode_ebreak,
                     "slot1 ebreak metadata matches the younger sidecar");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_csr_addr == 0,
                     "slot1 branch decode keeps csr_addr clear");
      fail |= expect((root->sim_top__DOT__cpu__DOT__decode_slot1_imm & 1u) == 0,
                     "slot1 branch immediate remains instruction-aligned");
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_slot1_pc !=
                         root->sim_top__DOT__cpu__DOT__decode_slot0_pc,
                     "slot1 pc stays distinct from slot0 pc");

      if (root->sim_top__DOT__cpu__DOT__decode_pair_allow_second) {
        coverage.slot1_fireable_events++;
      } else {
        coverage.slot1_blocked_events++;
        if (frontend_flush) {
          coverage.slot1_flushed_events++;
        } else {
          coverage.slot1_blocked_nonflush_events++;
        }
      }
    }

    if (frontend_flush) {
      fail |= expect(root->sim_top__DOT__cpu__DOT__decode_pair_allow_second == 0,
                     "frontend flush still blocks any real second-slot allowance");
    }

    if (pre_frontend_flush) {
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_valid == 0,
                     "frontend flush clears the slot1 shadow transport surface");
      if (pre_shadow_valid || pre_slot1_valid) {
        coverage.shadow_flush_clear_events++;
      }
    } else if (pre_slot1_valid) {
      coverage.shadow_capture_events++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_valid == 1,
                     "visible slot1 captures into shadow transport");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_pc == pre_slot1_pc,
                     "shadow transport captures slot1 pc");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_ins == pre_slot1_ins,
                     "shadow transport captures slot1 instruction");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_imm == pre_slot1_imm,
                     "shadow transport captures slot1 immediate");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_rd == pre_slot1_rd,
                     "shadow transport captures slot1 rd");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_rs1 == pre_slot1_rs1,
                     "shadow transport captures slot1 rs1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_rs2 == pre_slot1_rs2,
                     "shadow transport captures slot1 rs2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_csr_addr == pre_slot1_csr_addr,
                     "shadow transport captures slot1 csr_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_exu_opt == pre_slot1_exu_opt,
                     "shadow transport captures slot1 exu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_alu_opt == pre_slot1_alu_opt,
                     "shadow transport captures slot1 alu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_src_sel1 == pre_slot1_src_sel1,
                     "shadow transport captures slot1 src_sel1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_src_sel2 == pre_slot1_src_sel2,
                     "shadow transport captures slot1 src_sel2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_wen == pre_slot1_wen,
                     "shadow transport captures slot1 wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_brch == pre_slot1_brch,
                     "shadow transport captures slot1 branch class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_csr_wen == pre_slot1_csr_wen,
                     "shadow transport captures slot1 csr_wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_load == pre_slot1_load,
                     "shadow transport captures slot1 load class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_store == pre_slot1_store,
                     "shadow transport captures slot1 store class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_jal == pre_slot1_jal,
                     "shadow transport captures slot1 jal class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_jalr == pre_slot1_jalr,
                     "shadow transport captures slot1 jalr class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_fence_i == pre_slot1_fence_i,
                     "shadow transport captures slot1 fence_i class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_muldiv == pre_slot1_muldiv,
                     "shadow transport captures slot1 muldiv class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_is_cop_insn == pre_slot1_is_cop_insn,
                     "shadow transport captures slot1 cop class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_ecall == pre_slot1_ecall,
                     "shadow transport captures slot1 ecall class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_mret == pre_slot1_mret,
                     "shadow transport captures slot1 mret class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_ebreak == pre_slot1_ebreak,
                     "shadow transport captures slot1 ebreak class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_fireable == pre_allow_second,
                     "shadow transport captures slot1 fireable state");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_predict_taken == pre_pair_younger_predict_taken,
                     "shadow transport captures younger predict_taken");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_predict_target == pre_pair_younger_predict_target,
                     "shadow transport captures younger predict_target");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_predict_btb_hit == pre_pair_younger_predict_btb_hit,
                     "shadow transport captures younger btb_hit");
      if (pre_allow_second) {
        coverage.shadow_capture_fireable_events++;
      } else {
        coverage.shadow_capture_blocked_events++;
      }
    } else if (pre_shadow_valid) {
      coverage.shadow_hold_cycles++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_valid == 1,
                     "shadow transport holds valid without flush");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_pc == pre_shadow_pc,
                     "shadow transport holds pc stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_ins == pre_shadow_ins,
                     "shadow transport holds instruction stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_imm == pre_shadow_imm,
                     "shadow transport holds immediate stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_rd == pre_shadow_rd,
                     "shadow transport holds rd stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_rs1 == pre_shadow_rs1,
                     "shadow transport holds rs1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_rs2 == pre_shadow_rs2,
                     "shadow transport holds rs2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_csr_addr == pre_shadow_csr_addr,
                     "shadow transport holds csr_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_exu_opt == pre_shadow_exu_opt,
                     "shadow transport holds exu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_alu_opt == pre_shadow_alu_opt,
                     "shadow transport holds alu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_src_sel1 == pre_shadow_src_sel1,
                     "shadow transport holds src_sel1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_src_sel2 == pre_shadow_src_sel2,
                     "shadow transport holds src_sel2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_wen == pre_shadow_wen,
                     "shadow transport holds wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_brch == pre_shadow_brch,
                     "shadow transport holds branch class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_csr_wen == pre_shadow_csr_wen,
                     "shadow transport holds csr_wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_load == pre_shadow_load,
                     "shadow transport holds load class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_store == pre_shadow_store,
                     "shadow transport holds store class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_jal == pre_shadow_jal,
                     "shadow transport holds jal class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_jalr == pre_shadow_jalr,
                     "shadow transport holds jalr class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_fence_i == pre_shadow_fence_i,
                     "shadow transport holds fence_i class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_muldiv == pre_shadow_muldiv,
                     "shadow transport holds muldiv class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_is_cop_insn == pre_shadow_is_cop_insn,
                     "shadow transport holds cop class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_ecall == pre_shadow_ecall,
                     "shadow transport holds ecall class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_mret == pre_shadow_mret,
                     "shadow transport holds mret class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_ebreak == pre_shadow_ebreak,
                     "shadow transport holds ebreak class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_fireable == pre_shadow_fireable,
                     "shadow transport holds fireable state stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_predict_taken == pre_shadow_predict_taken,
                     "shadow transport holds predict_taken stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_predict_target == pre_shadow_predict_target,
                     "shadow transport holds predict_target stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_shadow_predict_btb_hit == pre_shadow_predict_btb_hit,
                     "shadow transport holds btb_hit stable");
    }

    if (pre_frontend_flush) {
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_valid == 0,
                     "frontend flush clears the slot1 endpoint surface");
      if (pre_endpoint_valid || pre_slot1_valid || pre_shadow_valid) {
        coverage.endpoint_flush_clear_events++;
      }
    } else if (pre_slot1_endpoint_accept) {
      coverage.endpoint_capture_events++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_valid == 1,
                     "visible slot1 is accepted by the shadow endpoint");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_pc == pre_slot1_pc,
                     "endpoint captures slot1 pc");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_ins == pre_slot1_ins,
                     "endpoint captures slot1 instruction");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_imm == pre_slot1_imm,
                     "endpoint captures slot1 immediate");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_rd == pre_slot1_rd,
                     "endpoint captures slot1 rd");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_rs1 == pre_slot1_rs1,
                     "endpoint captures slot1 rs1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_rs2 == pre_slot1_rs2,
                     "endpoint captures slot1 rs2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_csr_addr == pre_slot1_csr_addr,
                     "endpoint captures slot1 csr_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_exu_opt == pre_slot1_exu_opt,
                     "endpoint captures slot1 exu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_alu_opt == pre_slot1_alu_opt,
                     "endpoint captures slot1 alu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_src_sel1 == pre_slot1_src_sel1,
                     "endpoint captures slot1 src_sel1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_src_sel2 == pre_slot1_src_sel2,
                     "endpoint captures slot1 src_sel2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_wen == pre_slot1_wen,
                     "endpoint captures slot1 wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_brch == pre_slot1_brch,
                     "endpoint captures slot1 branch class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_csr_wen == pre_slot1_csr_wen,
                     "endpoint captures slot1 csr_wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_load == pre_slot1_load,
                     "endpoint captures slot1 load class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_store == pre_slot1_store,
                     "endpoint captures slot1 store class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_jal == pre_slot1_jal,
                     "endpoint captures slot1 jal class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_jalr == pre_slot1_jalr,
                     "endpoint captures slot1 jalr class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_fence_i == pre_slot1_fence_i,
                     "endpoint captures slot1 fence_i class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_muldiv == pre_slot1_muldiv,
                     "endpoint captures slot1 muldiv class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_is_cop_insn == pre_slot1_is_cop_insn,
                     "endpoint captures slot1 cop class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_ecall == pre_slot1_ecall,
                     "endpoint captures slot1 ecall class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_mret == pre_slot1_mret,
                     "endpoint captures slot1 mret class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_ebreak == pre_slot1_ebreak,
                     "endpoint captures slot1 ebreak class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_fireable == pre_allow_second,
                     "endpoint captures slot1 fireable state");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_predict_taken == pre_pair_younger_predict_taken,
                     "endpoint captures younger predict_taken");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_predict_target == pre_pair_younger_predict_target,
                     "endpoint captures younger predict_target");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_predict_btb_hit == pre_pair_younger_predict_btb_hit,
                     "endpoint captures younger btb_hit");
      if (pre_allow_second) {
        coverage.endpoint_capture_fireable_events++;
      } else {
        coverage.endpoint_capture_blocked_events++;
      }
    } else if (pre_endpoint_valid) {
      coverage.endpoint_hold_cycles++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_valid == 1,
                     "endpoint holds valid without flush");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_pc == pre_endpoint_pc,
                     "endpoint holds pc stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_ins == pre_endpoint_ins,
                     "endpoint holds instruction stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_imm == pre_endpoint_imm,
                     "endpoint holds immediate stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_rd == pre_endpoint_rd,
                     "endpoint holds rd stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_rs1 == pre_endpoint_rs1,
                     "endpoint holds rs1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_rs2 == pre_endpoint_rs2,
                     "endpoint holds rs2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_csr_addr == pre_endpoint_csr_addr,
                     "endpoint holds csr_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_exu_opt == pre_endpoint_exu_opt,
                     "endpoint holds exu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_alu_opt == pre_endpoint_alu_opt,
                     "endpoint holds alu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_src_sel1 == pre_endpoint_src_sel1,
                     "endpoint holds src_sel1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_src_sel2 == pre_endpoint_src_sel2,
                     "endpoint holds src_sel2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_wen == pre_endpoint_wen,
                     "endpoint holds wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_brch == pre_endpoint_brch,
                     "endpoint holds branch class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_csr_wen == pre_endpoint_csr_wen,
                     "endpoint holds csr_wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_load == pre_endpoint_load,
                     "endpoint holds load class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_store == pre_endpoint_store,
                     "endpoint holds store class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_jal == pre_endpoint_jal,
                     "endpoint holds jal class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_jalr == pre_endpoint_jalr,
                     "endpoint holds jalr class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_fence_i == pre_endpoint_fence_i,
                     "endpoint holds fence_i class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_muldiv == pre_endpoint_muldiv,
                     "endpoint holds muldiv class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_is_cop_insn == pre_endpoint_is_cop_insn,
                     "endpoint holds cop class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_ecall == pre_endpoint_ecall,
                     "endpoint holds ecall class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_mret == pre_endpoint_mret,
                     "endpoint holds mret class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_ebreak == pre_endpoint_ebreak,
                     "endpoint holds ebreak class stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_fireable == pre_endpoint_fireable,
                     "endpoint holds fireable state stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_predict_taken == pre_endpoint_predict_taken,
                     "endpoint holds predict_taken stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_predict_target == pre_endpoint_predict_target,
                     "endpoint holds predict_target stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__slot1_endpoint_predict_btb_hit == pre_endpoint_predict_btb_hit,
                     "endpoint holds btb_hit stable");
    }

    if (pre_frontend_flush) {
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_valid == 0,
                     "frontend flush clears the pair bundle surface");
      if (pre_pair_bundle_valid || pre_frontend_pair_capture) {
        coverage.pair_bundle_flush_clear_events++;
      }
    } else if (pre_frontend_pair_capture) {
      coverage.pair_bundle_capture_events++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_valid == 1,
                     "visible frontend pair captures into the pair bundle");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_valid == 1,
                     "pair bundle keeps slot0 valid");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_pc == pre_slot0_pc,
                     "pair bundle captures slot0 pc");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_ins == pre_slot0_ins,
                     "pair bundle captures slot0 instruction");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_predict_taken == pre_slot0_predict_taken,
                     "pair bundle captures slot0 predict_taken");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_predict_target == pre_slot0_predict_target,
                     "pair bundle captures slot0 predict_target");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_predict_btb_hit == pre_slot0_predict_btb_hit,
                     "pair bundle captures slot0 btb_hit");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rd == pre_slot0_rd,
                     "pair bundle captures slot0 rd");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rs1 == pre_slot0_rs1,
                     "pair bundle captures slot0 rs1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rs2 == pre_slot0_rs2,
                     "pair bundle captures slot0 rs2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_wen == pre_slot0_wen,
                     "pair bundle captures slot0 wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_brch == pre_slot0_brch,
                     "pair bundle captures slot0 branch class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_imm == pre_slot0_imm,
                     "pair bundle captures slot0 immediate");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_csr_addr == pre_slot0_csr_addr,
                     "pair bundle captures slot0 csr_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_exu_opt == pre_slot0_exu_opt,
                     "pair bundle captures slot0 exu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_alu_opt == pre_slot0_alu_opt,
                     "pair bundle captures slot0 alu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_src_sel1 == pre_slot0_src_sel1,
                     "pair bundle captures slot0 src_sel1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_src_sel2 == pre_slot0_src_sel2,
                     "pair bundle captures slot0 src_sel2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_csr_wen == pre_slot0_csr_wen,
                     "pair bundle captures slot0 csr_wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_load == pre_slot0_load,
                     "pair bundle captures slot0 load class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_store == pre_slot0_store,
                     "pair bundle captures slot0 store class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_jal == pre_slot0_jal,
                     "pair bundle captures slot0 jal class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_jalr == pre_slot0_jalr,
                     "pair bundle captures slot0 jalr class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_fence_i == pre_slot0_fence_i,
                     "pair bundle captures slot0 fence_i class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_muldiv == pre_slot0_muldiv,
                     "pair bundle captures slot0 muldiv class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_is_cop_insn == pre_slot0_is_cop_insn,
                     "pair bundle captures slot0 cop class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_ecall == pre_slot0_ecall,
                     "pair bundle captures slot0 ecall class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_mret == pre_slot0_mret,
                     "pair bundle captures slot0 mret class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_ebreak == pre_slot0_ebreak,
                     "pair bundle captures slot0 ebreak class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_valid == 1,
                     "pair bundle keeps slot1 valid");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_pc == pre_pair_younger_pc,
                     "pair bundle captures slot1 pc");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_ins == pre_pair_younger_ins,
                     "pair bundle captures slot1 instruction");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_predict_taken == pre_pair_younger_predict_taken,
                     "pair bundle captures slot1 predict_taken");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_predict_target == pre_pair_younger_predict_target,
                     "pair bundle captures slot1 predict_target");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_predict_btb_hit == pre_pair_younger_predict_btb_hit,
                     "pair bundle captures slot1 btb_hit");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rd == pre_pair_slot1_rd,
                     "pair bundle captures slot1 rd");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rs1 == pre_pair_slot1_rs1,
                     "pair bundle captures slot1 rs1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rs2 == pre_pair_slot1_rs2,
                     "pair bundle captures slot1 rs2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_wen == pre_pair_slot1_wen,
                     "pair bundle captures slot1 wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_brch == pre_pair_slot1_brch,
                     "pair bundle captures slot1 branch class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_imm == pre_pair_slot1_imm,
                     "pair bundle captures slot1 immediate");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_csr_addr == pre_pair_slot1_csr_addr,
                     "pair bundle captures slot1 csr_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_exu_opt == pre_pair_slot1_exu_opt,
                     "pair bundle captures slot1 exu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_alu_opt == pre_pair_slot1_alu_opt,
                     "pair bundle captures slot1 alu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_src_sel1 == pre_pair_slot1_src_sel1,
                     "pair bundle captures slot1 src_sel1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_src_sel2 == pre_pair_slot1_src_sel2,
                     "pair bundle captures slot1 src_sel2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_csr_wen == pre_pair_slot1_csr_wen,
                     "pair bundle captures slot1 csr_wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_load == pre_pair_slot1_load,
                     "pair bundle captures slot1 load class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_store == pre_pair_slot1_store,
                     "pair bundle captures slot1 store class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_jal == pre_pair_slot1_jal,
                     "pair bundle captures slot1 jal class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_jalr == pre_pair_slot1_jalr,
                     "pair bundle captures slot1 jalr class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_fence_i == pre_pair_slot1_fence_i,
                     "pair bundle captures slot1 fence_i class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_muldiv == pre_pair_slot1_muldiv,
                     "pair bundle captures slot1 muldiv class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_is_cop_insn == pre_pair_slot1_is_cop_insn,
                     "pair bundle captures slot1 cop class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_ecall == pre_pair_slot1_ecall,
                     "pair bundle captures slot1 ecall class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_mret == pre_pair_slot1_mret,
                     "pair bundle captures slot1 mret class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_ebreak == pre_pair_slot1_ebreak,
                     "pair bundle captures slot1 ebreak class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_candidate_alu_branch == pre_pair_candidate_alu_branch,
                     "pair bundle captures pair candidate classification");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_allow_second == pre_allow_second,
                     "pair bundle captures pair fireability");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_order_alu_then_branch == pre_pair_order_alu_then_branch,
                     "pair bundle captures alu-then-branch order");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_order_branch_then_alu == pre_pair_order_branch_then_alu,
                     "pair bundle captures branch-then-alu order");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_raw == pre_pair_block_raw,
                     "pair bundle captures raw block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_waw == pre_pair_block_waw,
                     "pair bundle captures waw block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_dual_writeback == pre_pair_block_dual_writeback,
                     "pair bundle captures dual-writeback block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_exclusive_backend == pre_pair_block_exclusive_backend,
                     "pair bundle captures exclusive-backend block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_redirect_control == pre_pair_block_redirect_control,
                     "pair bundle captures redirect-control block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_older_branch_first == pre_pair_block_older_branch_first,
                     "pair bundle captures older-branch-first block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_downstream_busy == pre_pair_block_downstream_busy,
                     "pair bundle captures downstream-busy block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_cop_pipeline == pre_pair_block_cop_pipeline,
                     "pair bundle captures cop-pipeline block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_frontend_flush == pre_pair_block_frontend_flush,
                     "pair bundle captures frontend-flush block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_pc !=
                         root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_pc,
                     "pair bundle keeps distinct pcs across both lanes");
      if (pre_allow_second) {
        coverage.pair_bundle_capture_fireable_events++;
        fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_candidate_alu_branch == 1,
                       "fireable pair bundle remains a candidate alu-branch pair");
      } else {
        coverage.pair_bundle_capture_blocked_events++;
      }
    } else if (pre_pair_bundle_valid) {
      coverage.pair_bundle_hold_cycles++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_valid == 1,
                     "pair bundle holds valid without flush");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_valid == pre_pair_bundle_slot0_valid,
                     "pair bundle holds slot0 valid stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_pc == pre_pair_bundle_slot0_pc,
                     "pair bundle holds slot0 pc stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_ins == pre_pair_bundle_slot0_ins,
                     "pair bundle holds slot0 instruction stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_predict_taken == pre_pair_bundle_slot0_predict_taken,
                     "pair bundle holds slot0 predict_taken stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_predict_target == pre_pair_bundle_slot0_predict_target,
                     "pair bundle holds slot0 predict_target stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_predict_btb_hit == pre_pair_bundle_slot0_predict_btb_hit,
                     "pair bundle holds slot0 btb_hit stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rd == pre_pair_bundle_slot0_rd,
                     "pair bundle holds slot0 rd stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rs1 == pre_pair_bundle_slot0_rs1,
                     "pair bundle holds slot0 rs1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_rs2 == pre_pair_bundle_slot0_rs2,
                     "pair bundle holds slot0 rs2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_wen == pre_pair_bundle_slot0_wen,
                     "pair bundle holds slot0 wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_brch == pre_pair_bundle_slot0_brch,
                     "pair bundle holds slot0 brch stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_imm == pre_pair_bundle_slot0_imm,
                     "pair bundle holds slot0 immediate stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_csr_addr == pre_pair_bundle_slot0_csr_addr,
                     "pair bundle holds slot0 csr_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_exu_opt == pre_pair_bundle_slot0_exu_opt,
                     "pair bundle holds slot0 exu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_alu_opt == pre_pair_bundle_slot0_alu_opt,
                     "pair bundle holds slot0 alu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_src_sel1 == pre_pair_bundle_slot0_src_sel1,
                     "pair bundle holds slot0 src_sel1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_src_sel2 == pre_pair_bundle_slot0_src_sel2,
                     "pair bundle holds slot0 src_sel2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_csr_wen == pre_pair_bundle_slot0_csr_wen,
                     "pair bundle holds slot0 csr_wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_load == pre_pair_bundle_slot0_load,
                     "pair bundle holds slot0 load stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_store == pre_pair_bundle_slot0_store,
                     "pair bundle holds slot0 store stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_jal == pre_pair_bundle_slot0_jal,
                     "pair bundle holds slot0 jal stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_jalr == pre_pair_bundle_slot0_jalr,
                     "pair bundle holds slot0 jalr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_fence_i == pre_pair_bundle_slot0_fence_i,
                     "pair bundle holds slot0 fence_i stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_muldiv == pre_pair_bundle_slot0_muldiv,
                     "pair bundle holds slot0 muldiv stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_is_cop_insn == pre_pair_bundle_slot0_is_cop_insn,
                     "pair bundle holds slot0 cop stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_ecall == pre_pair_bundle_slot0_ecall,
                     "pair bundle holds slot0 ecall stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_mret == pre_pair_bundle_slot0_mret,
                     "pair bundle holds slot0 mret stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot0_ebreak == pre_pair_bundle_slot0_ebreak,
                     "pair bundle holds slot0 ebreak stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_valid == pre_pair_bundle_slot1_valid,
                     "pair bundle holds slot1 valid stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_pc == pre_pair_bundle_slot1_pc,
                     "pair bundle holds slot1 pc stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_ins == pre_pair_bundle_slot1_ins,
                     "pair bundle holds slot1 instruction stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_predict_taken == pre_pair_bundle_slot1_predict_taken,
                     "pair bundle holds slot1 predict_taken stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_predict_target == pre_pair_bundle_slot1_predict_target,
                     "pair bundle holds slot1 predict_target stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_predict_btb_hit == pre_pair_bundle_slot1_predict_btb_hit,
                     "pair bundle holds slot1 btb_hit stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rd == pre_pair_bundle_slot1_rd,
                     "pair bundle holds slot1 rd stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rs1 == pre_pair_bundle_slot1_rs1,
                     "pair bundle holds slot1 rs1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_rs2 == pre_pair_bundle_slot1_rs2,
                     "pair bundle holds slot1 rs2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_wen == pre_pair_bundle_slot1_wen,
                     "pair bundle holds slot1 wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_brch == pre_pair_bundle_slot1_brch,
                     "pair bundle holds slot1 brch stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_imm == pre_pair_bundle_slot1_imm,
                     "pair bundle holds slot1 immediate stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_csr_addr == pre_pair_bundle_slot1_csr_addr,
                     "pair bundle holds slot1 csr_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_exu_opt == pre_pair_bundle_slot1_exu_opt,
                     "pair bundle holds slot1 exu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_alu_opt == pre_pair_bundle_slot1_alu_opt,
                     "pair bundle holds slot1 alu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_src_sel1 == pre_pair_bundle_slot1_src_sel1,
                     "pair bundle holds slot1 src_sel1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_src_sel2 == pre_pair_bundle_slot1_src_sel2,
                     "pair bundle holds slot1 src_sel2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_csr_wen == pre_pair_bundle_slot1_csr_wen,
                     "pair bundle holds slot1 csr_wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_load == pre_pair_bundle_slot1_load,
                     "pair bundle holds slot1 load stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_store == pre_pair_bundle_slot1_store,
                     "pair bundle holds slot1 store stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_jal == pre_pair_bundle_slot1_jal,
                     "pair bundle holds slot1 jal stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_jalr == pre_pair_bundle_slot1_jalr,
                     "pair bundle holds slot1 jalr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_fence_i == pre_pair_bundle_slot1_fence_i,
                     "pair bundle holds slot1 fence_i stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_muldiv == pre_pair_bundle_slot1_muldiv,
                     "pair bundle holds slot1 muldiv stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_is_cop_insn == pre_pair_bundle_slot1_is_cop_insn,
                     "pair bundle holds slot1 cop stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_ecall == pre_pair_bundle_slot1_ecall,
                     "pair bundle holds slot1 ecall stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_mret == pre_pair_bundle_slot1_mret,
                     "pair bundle holds slot1 mret stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_slot1_ebreak == pre_pair_bundle_slot1_ebreak,
                     "pair bundle holds slot1 ebreak stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_candidate_alu_branch == pre_pair_bundle_candidate_alu_branch,
                     "pair bundle holds candidate classification stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_allow_second == pre_pair_bundle_allow_second,
                     "pair bundle holds fireability stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_order_alu_then_branch == pre_pair_bundle_order_alu_then_branch,
                     "pair bundle holds alu-then-branch order stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_order_branch_then_alu == pre_pair_bundle_order_branch_then_alu,
                     "pair bundle holds branch-then-alu order stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_raw == pre_pair_bundle_block_raw,
                     "pair bundle holds raw block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_waw == pre_pair_bundle_block_waw,
                     "pair bundle holds waw block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_dual_writeback == pre_pair_bundle_block_dual_writeback,
                     "pair bundle holds dual-writeback block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_exclusive_backend == pre_pair_bundle_block_exclusive_backend,
                     "pair bundle holds exclusive-backend block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_redirect_control == pre_pair_bundle_block_redirect_control,
                     "pair bundle holds redirect-control block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_older_branch_first == pre_pair_bundle_block_older_branch_first,
                     "pair bundle holds older-branch-first block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_downstream_busy == pre_pair_bundle_block_downstream_busy,
                     "pair bundle holds downstream-busy block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_cop_pipeline == pre_pair_bundle_block_cop_pipeline,
                     "pair bundle holds cop-pipeline block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__frontend_pair_bundle_block_frontend_flush == pre_pair_bundle_block_frontend_flush,
                     "pair bundle holds frontend-flush block reason stable");
    }

    if (pre_frontend_flush) {
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_valid == 0,
                     "frontend flush clears the pair handoff surface");
      if (pre_pair_handoff_valid || pre_pair_bundle_valid) {
        coverage.pair_handoff_flush_clear_events++;
      }
    } else if (pre_pair_bundle_valid) {
      coverage.pair_handoff_capture_events++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_valid == 1,
                     "frontend pair bundle captures into the pair handoff");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_valid == pre_pair_bundle_slot0_valid,
                     "pair handoff keeps slot0 valid");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_pc == pre_pair_bundle_slot0_pc,
                     "pair handoff captures slot0 pc");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_ins == pre_pair_bundle_slot0_ins,
                     "pair handoff captures slot0 instruction");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src1 == pre_pair_bundle_slot0_src1,
                     "pair handoff captures slot0 src1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src2 == pre_pair_bundle_slot0_src2,
                     "pair handoff captures slot0 src2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_imm == pre_pair_bundle_slot0_imm,
                     "pair handoff captures slot0 immediate");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src_sel1 == pre_pair_bundle_slot0_src_sel1,
                     "pair handoff captures slot0 src_sel1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src_sel2 == pre_pair_bundle_slot0_src_sel2,
                     "pair handoff captures slot0 src_sel2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_rd == pre_pair_bundle_slot0_rd,
                     "pair handoff captures slot0 rd");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_csr_addr == pre_pair_bundle_slot0_csr_addr,
                     "pair handoff captures slot0 csr_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_exu_opt == pre_pair_bundle_slot0_exu_opt,
                     "pair handoff captures slot0 exu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_alu_opt == pre_pair_bundle_slot0_alu_opt,
                     "pair handoff captures slot0 alu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_wen == pre_pair_bundle_slot0_wen,
                     "pair handoff captures slot0 wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_csr_wen == pre_pair_bundle_slot0_csr_wen,
                     "pair handoff captures slot0 csr_wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_mret == pre_pair_bundle_slot0_mret,
                     "pair handoff captures slot0 mret");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_ecall == pre_pair_bundle_slot0_ecall,
                     "pair handoff captures slot0 ecall");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_load == pre_pair_bundle_slot0_load,
                     "pair handoff captures slot0 load");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_store == pre_pair_bundle_slot0_store,
                     "pair handoff captures slot0 store");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_brch == pre_pair_bundle_slot0_brch,
                     "pair handoff captures slot0 brch");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_jal == pre_pair_bundle_slot0_jal,
                     "pair handoff captures slot0 jal");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_jalr == pre_pair_bundle_slot0_jalr,
                     "pair handoff captures slot0 jalr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_ebreak == pre_pair_bundle_slot0_ebreak,
                     "pair handoff captures slot0 ebreak");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_fence_i == pre_pair_bundle_slot0_fence_i,
                     "pair handoff captures slot0 fence_i");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_muldiv == pre_pair_bundle_slot0_muldiv,
                     "pair handoff captures slot0 muldiv");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_is_cop_insn == pre_pair_bundle_slot0_is_cop_insn,
                     "pair handoff captures slot0 cop class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_predict_taken == pre_pair_bundle_slot0_predict_taken,
                     "pair handoff captures slot0 predict_taken");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_predict_target == pre_pair_bundle_slot0_predict_target,
                     "pair handoff captures slot0 predict_target");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_predict_btb_hit == pre_pair_bundle_slot0_predict_btb_hit,
                     "pair handoff captures slot0 btb_hit");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_rs1_addr == pre_pair_bundle_slot0_rs1_addr,
                     "pair handoff captures slot0 rs1_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_valid == pre_pair_bundle_slot1_valid,
                     "pair handoff keeps slot1 valid");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_pc == pre_pair_bundle_slot1_pc,
                     "pair handoff captures slot1 pc");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_ins == pre_pair_bundle_slot1_ins,
                     "pair handoff captures slot1 instruction");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src1 == pre_pair_bundle_slot1_src1,
                     "pair handoff captures slot1 src1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src2 == pre_pair_bundle_slot1_src2,
                     "pair handoff captures slot1 src2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_imm == pre_pair_bundle_slot1_imm,
                     "pair handoff captures slot1 immediate");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src_sel1 == pre_pair_bundle_slot1_src_sel1,
                     "pair handoff captures slot1 src_sel1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src_sel2 == pre_pair_bundle_slot1_src_sel2,
                     "pair handoff captures slot1 src_sel2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_rd == pre_pair_bundle_slot1_rd,
                     "pair handoff captures slot1 rd");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_csr_addr == pre_pair_bundle_slot1_csr_addr,
                     "pair handoff captures slot1 csr_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_exu_opt == pre_pair_bundle_slot1_exu_opt,
                     "pair handoff captures slot1 exu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_alu_opt == pre_pair_bundle_slot1_alu_opt,
                     "pair handoff captures slot1 alu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_wen == pre_pair_bundle_slot1_wen,
                     "pair handoff captures slot1 wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_csr_wen == pre_pair_bundle_slot1_csr_wen,
                     "pair handoff captures slot1 csr_wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_mret == pre_pair_bundle_slot1_mret,
                     "pair handoff captures slot1 mret");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_ecall == pre_pair_bundle_slot1_ecall,
                     "pair handoff captures slot1 ecall");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_load == pre_pair_bundle_slot1_load,
                     "pair handoff captures slot1 load");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_store == pre_pair_bundle_slot1_store,
                     "pair handoff captures slot1 store");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_brch == pre_pair_bundle_slot1_brch,
                     "pair handoff captures slot1 brch");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_jal == pre_pair_bundle_slot1_jal,
                     "pair handoff captures slot1 jal");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_jalr == pre_pair_bundle_slot1_jalr,
                     "pair handoff captures slot1 jalr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_ebreak == pre_pair_bundle_slot1_ebreak,
                     "pair handoff captures slot1 ebreak");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_fence_i == pre_pair_bundle_slot1_fence_i,
                     "pair handoff captures slot1 fence_i");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_muldiv == pre_pair_bundle_slot1_muldiv,
                     "pair handoff captures slot1 muldiv");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_is_cop_insn == pre_pair_bundle_slot1_is_cop_insn,
                     "pair handoff captures slot1 cop class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_predict_taken == pre_pair_bundle_slot1_predict_taken,
                     "pair handoff captures slot1 predict_taken");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_predict_target == pre_pair_bundle_slot1_predict_target,
                     "pair handoff captures slot1 predict_target");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_predict_btb_hit == pre_pair_bundle_slot1_predict_btb_hit,
                     "pair handoff captures slot1 btb_hit");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_rs1_addr == pre_pair_bundle_slot1_rs1_addr,
                     "pair handoff captures slot1 rs1_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_candidate_alu_branch == pre_pair_bundle_candidate_alu_branch,
                     "pair handoff captures candidate classification");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_allow_second == pre_pair_bundle_allow_second,
                     "pair handoff captures fireability");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_order_alu_then_branch == pre_pair_bundle_order_alu_then_branch,
                     "pair handoff captures alu-then-branch order");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_order_branch_then_alu == pre_pair_bundle_order_branch_then_alu,
                     "pair handoff captures branch-then-alu order");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_raw == pre_pair_bundle_block_raw,
                     "pair handoff captures raw block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_waw == pre_pair_bundle_block_waw,
                     "pair handoff captures waw block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_dual_writeback == pre_pair_bundle_block_dual_writeback,
                     "pair handoff captures dual-writeback block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_exclusive_backend == pre_pair_bundle_block_exclusive_backend,
                     "pair handoff captures exclusive-backend block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_redirect_control == pre_pair_bundle_block_redirect_control,
                     "pair handoff captures redirect-control block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_older_branch_first == pre_pair_bundle_block_older_branch_first,
                     "pair handoff captures older-branch-first block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_downstream_busy == pre_pair_bundle_block_downstream_busy,
                     "pair handoff captures downstream-busy block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_cop_pipeline == pre_pair_bundle_block_cop_pipeline,
                     "pair handoff captures cop-pipeline block reason");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_frontend_flush == pre_pair_bundle_block_frontend_flush,
                     "pair handoff captures frontend-flush block reason");
      if (pre_pair_handoff_valid &&
          root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_pc == pre_pair_handoff_slot0_pc &&
          root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_pc == pre_pair_handoff_slot1_pc &&
          root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src1 == pre_pair_handoff_slot0_src1 &&
          root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src1 == pre_pair_handoff_slot1_src1 &&
          root->sim_top__DOT__cpu__DOT__pair_handoff_allow_second == pre_pair_handoff_allow_second) {
        coverage.pair_handoff_hold_cycles++;
      }
      if (pre_pair_bundle_allow_second) {
        coverage.pair_handoff_capture_fireable_events++;
      } else {
        coverage.pair_handoff_capture_blocked_events++;
      }
    } else if (pre_pair_handoff_valid) {
      coverage.pair_handoff_hold_cycles++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_valid == 1,
                     "pair handoff holds valid without flush");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_valid == pre_pair_handoff_slot0_valid,
                     "pair handoff holds slot0 valid stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_pc == pre_pair_handoff_slot0_pc,
                     "pair handoff holds slot0 pc stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_ins == pre_pair_handoff_slot0_ins,
                     "pair handoff holds slot0 instruction stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src1 == pre_pair_handoff_slot0_src1,
                     "pair handoff holds slot0 src1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src2 == pre_pair_handoff_slot0_src2,
                     "pair handoff holds slot0 src2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_imm == pre_pair_handoff_slot0_imm,
                     "pair handoff holds slot0 immediate stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src_sel1 == pre_pair_handoff_slot0_src_sel1,
                     "pair handoff holds slot0 src_sel1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_src_sel2 == pre_pair_handoff_slot0_src_sel2,
                     "pair handoff holds slot0 src_sel2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_rd == pre_pair_handoff_slot0_rd,
                     "pair handoff holds slot0 rd stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_csr_addr == pre_pair_handoff_slot0_csr_addr,
                     "pair handoff holds slot0 csr_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_exu_opt == pre_pair_handoff_slot0_exu_opt,
                     "pair handoff holds slot0 exu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_alu_opt == pre_pair_handoff_slot0_alu_opt,
                     "pair handoff holds slot0 alu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_wen == pre_pair_handoff_slot0_wen,
                     "pair handoff holds slot0 wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_csr_wen == pre_pair_handoff_slot0_csr_wen,
                     "pair handoff holds slot0 csr_wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_mret == pre_pair_handoff_slot0_mret,
                     "pair handoff holds slot0 mret stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_ecall == pre_pair_handoff_slot0_ecall,
                     "pair handoff holds slot0 ecall stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_load == pre_pair_handoff_slot0_load,
                     "pair handoff holds slot0 load stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_store == pre_pair_handoff_slot0_store,
                     "pair handoff holds slot0 store stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_brch == pre_pair_handoff_slot0_brch,
                     "pair handoff holds slot0 brch stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_jal == pre_pair_handoff_slot0_jal,
                     "pair handoff holds slot0 jal stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_jalr == pre_pair_handoff_slot0_jalr,
                     "pair handoff holds slot0 jalr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_ebreak == pre_pair_handoff_slot0_ebreak,
                     "pair handoff holds slot0 ebreak stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_fence_i == pre_pair_handoff_slot0_fence_i,
                     "pair handoff holds slot0 fence_i stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_muldiv == pre_pair_handoff_slot0_muldiv,
                     "pair handoff holds slot0 muldiv stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_is_cop_insn == pre_pair_handoff_slot0_is_cop_insn,
                     "pair handoff holds slot0 cop stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_predict_taken == pre_pair_handoff_slot0_predict_taken,
                     "pair handoff holds slot0 predict_taken stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_predict_target == pre_pair_handoff_slot0_predict_target,
                     "pair handoff holds slot0 predict_target stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_predict_btb_hit == pre_pair_handoff_slot0_predict_btb_hit,
                     "pair handoff holds slot0 btb_hit stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot0_rs1_addr == pre_pair_handoff_slot0_rs1_addr,
                     "pair handoff holds slot0 rs1_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_valid == pre_pair_handoff_slot1_valid,
                     "pair handoff holds slot1 valid stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_pc == pre_pair_handoff_slot1_pc,
                     "pair handoff holds slot1 pc stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_ins == pre_pair_handoff_slot1_ins,
                     "pair handoff holds slot1 instruction stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src1 == pre_pair_handoff_slot1_src1,
                     "pair handoff holds slot1 src1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src2 == pre_pair_handoff_slot1_src2,
                     "pair handoff holds slot1 src2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_imm == pre_pair_handoff_slot1_imm,
                     "pair handoff holds slot1 immediate stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src_sel1 == pre_pair_handoff_slot1_src_sel1,
                     "pair handoff holds slot1 src_sel1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_src_sel2 == pre_pair_handoff_slot1_src_sel2,
                     "pair handoff holds slot1 src_sel2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_rd == pre_pair_handoff_slot1_rd,
                     "pair handoff holds slot1 rd stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_csr_addr == pre_pair_handoff_slot1_csr_addr,
                     "pair handoff holds slot1 csr_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_exu_opt == pre_pair_handoff_slot1_exu_opt,
                     "pair handoff holds slot1 exu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_alu_opt == pre_pair_handoff_slot1_alu_opt,
                     "pair handoff holds slot1 alu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_wen == pre_pair_handoff_slot1_wen,
                     "pair handoff holds slot1 wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_csr_wen == pre_pair_handoff_slot1_csr_wen,
                     "pair handoff holds slot1 csr_wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_mret == pre_pair_handoff_slot1_mret,
                     "pair handoff holds slot1 mret stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_ecall == pre_pair_handoff_slot1_ecall,
                     "pair handoff holds slot1 ecall stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_load == pre_pair_handoff_slot1_load,
                     "pair handoff holds slot1 load stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_store == pre_pair_handoff_slot1_store,
                     "pair handoff holds slot1 store stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_brch == pre_pair_handoff_slot1_brch,
                     "pair handoff holds slot1 brch stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_jal == pre_pair_handoff_slot1_jal,
                     "pair handoff holds slot1 jal stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_jalr == pre_pair_handoff_slot1_jalr,
                     "pair handoff holds slot1 jalr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_ebreak == pre_pair_handoff_slot1_ebreak,
                     "pair handoff holds slot1 ebreak stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_fence_i == pre_pair_handoff_slot1_fence_i,
                     "pair handoff holds slot1 fence_i stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_muldiv == pre_pair_handoff_slot1_muldiv,
                     "pair handoff holds slot1 muldiv stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_is_cop_insn == pre_pair_handoff_slot1_is_cop_insn,
                     "pair handoff holds slot1 cop stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_predict_taken == pre_pair_handoff_slot1_predict_taken,
                     "pair handoff holds slot1 predict_taken stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_predict_target == pre_pair_handoff_slot1_predict_target,
                     "pair handoff holds slot1 predict_target stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_predict_btb_hit == pre_pair_handoff_slot1_predict_btb_hit,
                     "pair handoff holds slot1 btb_hit stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_slot1_rs1_addr == pre_pair_handoff_slot1_rs1_addr,
                     "pair handoff holds slot1 rs1_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_candidate_alu_branch == pre_pair_handoff_candidate_alu_branch,
                     "pair handoff holds candidate classification stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_allow_second == pre_pair_handoff_allow_second,
                     "pair handoff holds fireability stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_order_alu_then_branch == pre_pair_handoff_order_alu_then_branch,
                     "pair handoff holds alu-then-branch order stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_order_branch_then_alu == pre_pair_handoff_order_branch_then_alu,
                     "pair handoff holds branch-then-alu order stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_raw == pre_pair_handoff_block_raw,
                     "pair handoff holds raw block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_waw == pre_pair_handoff_block_waw,
                     "pair handoff holds waw block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_dual_writeback == pre_pair_handoff_block_dual_writeback,
                     "pair handoff holds dual-writeback block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_exclusive_backend == pre_pair_handoff_block_exclusive_backend,
                     "pair handoff holds exclusive-backend block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_redirect_control == pre_pair_handoff_block_redirect_control,
                     "pair handoff holds redirect-control block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_older_branch_first == pre_pair_handoff_block_older_branch_first,
                     "pair handoff holds older-branch-first block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_downstream_busy == pre_pair_handoff_block_downstream_busy,
                     "pair handoff holds downstream-busy block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_cop_pipeline == pre_pair_handoff_block_cop_pipeline,
                     "pair handoff holds cop-pipeline block reason stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_handoff_block_frontend_flush == pre_pair_handoff_block_frontend_flush,
                     "pair handoff holds frontend-flush block reason stable");
    }

    if (pre_frontend_flush) {
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_valid == 0,
                     "frontend flush clears the pair dispatch surface");
      if (pre_pair_dispatch_valid || (pre_pair_handoff_valid && pre_handoff_scoreboard_allow_second)) {
        coverage.pair_dispatch_flush_clear_events++;
      }
    } else if (pre_pair_handoff_valid && pre_handoff_scoreboard_allow_second) {
      coverage.pair_dispatch_capture_events++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_valid == 1,
                     "fireable pair handoff captures into the pair dispatch surface");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_valid == pre_pair_handoff_slot0_valid,
                     "pair dispatch keeps slot0 valid");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_pc == pre_pair_handoff_slot0_pc,
                     "pair dispatch captures slot0 pc");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_ins == pre_pair_handoff_slot0_ins,
                     "pair dispatch captures slot0 instruction");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src1 == pre_pair_handoff_slot0_src1,
                     "pair dispatch captures slot0 src1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src2 == pre_pair_handoff_slot0_src2,
                     "pair dispatch captures slot0 src2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_imm == pre_pair_handoff_slot0_imm,
                     "pair dispatch captures slot0 immediate");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src_sel1 == pre_pair_handoff_slot0_src_sel1,
                     "pair dispatch captures slot0 src_sel1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src_sel2 == pre_pair_handoff_slot0_src_sel2,
                     "pair dispatch captures slot0 src_sel2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_rd == pre_pair_handoff_slot0_rd,
                     "pair dispatch captures slot0 rd");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_csr_addr == pre_pair_handoff_slot0_csr_addr,
                     "pair dispatch captures slot0 csr_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_exu_opt == pre_pair_handoff_slot0_exu_opt,
                     "pair dispatch captures slot0 exu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_alu_opt == pre_pair_handoff_slot0_alu_opt,
                     "pair dispatch captures slot0 alu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_wen == pre_pair_handoff_slot0_wen,
                     "pair dispatch captures slot0 wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_csr_wen == pre_pair_handoff_slot0_csr_wen,
                     "pair dispatch captures slot0 csr_wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_mret == pre_pair_handoff_slot0_mret,
                     "pair dispatch captures slot0 mret");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_ecall == pre_pair_handoff_slot0_ecall,
                     "pair dispatch captures slot0 ecall");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_load == pre_pair_handoff_slot0_load,
                     "pair dispatch captures slot0 load");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_store == pre_pair_handoff_slot0_store,
                     "pair dispatch captures slot0 store");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_brch == pre_pair_handoff_slot0_brch,
                     "pair dispatch captures slot0 brch");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_jal == pre_pair_handoff_slot0_jal,
                     "pair dispatch captures slot0 jal");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_jalr == pre_pair_handoff_slot0_jalr,
                     "pair dispatch captures slot0 jalr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_ebreak == pre_pair_handoff_slot0_ebreak,
                     "pair dispatch captures slot0 ebreak");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_fence_i == pre_pair_handoff_slot0_fence_i,
                     "pair dispatch captures slot0 fence_i");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_muldiv == pre_pair_handoff_slot0_muldiv,
                     "pair dispatch captures slot0 muldiv");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_is_cop_insn == pre_pair_handoff_slot0_is_cop_insn,
                     "pair dispatch captures slot0 cop class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_predict_taken == pre_pair_handoff_slot0_predict_taken,
                     "pair dispatch captures slot0 predict_taken");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_predict_target == pre_pair_handoff_slot0_predict_target,
                     "pair dispatch captures slot0 predict_target");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_predict_btb_hit == pre_pair_handoff_slot0_predict_btb_hit,
                     "pair dispatch captures slot0 btb_hit");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_rs1_addr == pre_pair_handoff_slot0_rs1_addr,
                     "pair dispatch captures slot0 rs1_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_valid == pre_pair_handoff_slot1_valid,
                     "pair dispatch keeps slot1 valid");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_pc == pre_pair_handoff_slot1_pc,
                     "pair dispatch captures slot1 pc");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_ins == pre_pair_handoff_slot1_ins,
                     "pair dispatch captures slot1 instruction");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src1 == pre_pair_handoff_slot1_src1,
                     "pair dispatch captures slot1 src1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src2 == pre_pair_handoff_slot1_src2,
                     "pair dispatch captures slot1 src2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_imm == pre_pair_handoff_slot1_imm,
                     "pair dispatch captures slot1 immediate");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src_sel1 == pre_pair_handoff_slot1_src_sel1,
                     "pair dispatch captures slot1 src_sel1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src_sel2 == pre_pair_handoff_slot1_src_sel2,
                     "pair dispatch captures slot1 src_sel2");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_rd == pre_pair_handoff_slot1_rd,
                     "pair dispatch captures slot1 rd");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_csr_addr == pre_pair_handoff_slot1_csr_addr,
                     "pair dispatch captures slot1 csr_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_exu_opt == pre_pair_handoff_slot1_exu_opt,
                     "pair dispatch captures slot1 exu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_alu_opt == pre_pair_handoff_slot1_alu_opt,
                     "pair dispatch captures slot1 alu_opt");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_wen == pre_pair_handoff_slot1_wen,
                     "pair dispatch captures slot1 wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_csr_wen == pre_pair_handoff_slot1_csr_wen,
                     "pair dispatch captures slot1 csr_wen");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_mret == pre_pair_handoff_slot1_mret,
                     "pair dispatch captures slot1 mret");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_ecall == pre_pair_handoff_slot1_ecall,
                     "pair dispatch captures slot1 ecall");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_load == pre_pair_handoff_slot1_load,
                     "pair dispatch captures slot1 load");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_store == pre_pair_handoff_slot1_store,
                     "pair dispatch captures slot1 store");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_brch == pre_pair_handoff_slot1_brch,
                     "pair dispatch captures slot1 brch");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_jal == pre_pair_handoff_slot1_jal,
                     "pair dispatch captures slot1 jal");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_jalr == pre_pair_handoff_slot1_jalr,
                     "pair dispatch captures slot1 jalr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_ebreak == pre_pair_handoff_slot1_ebreak,
                     "pair dispatch captures slot1 ebreak");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_fence_i == pre_pair_handoff_slot1_fence_i,
                     "pair dispatch captures slot1 fence_i");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_muldiv == pre_pair_handoff_slot1_muldiv,
                     "pair dispatch captures slot1 muldiv");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_is_cop_insn == pre_pair_handoff_slot1_is_cop_insn,
                     "pair dispatch captures slot1 cop class");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_predict_taken == pre_pair_handoff_slot1_predict_taken,
                     "pair dispatch captures slot1 predict_taken");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_predict_target == pre_pair_handoff_slot1_predict_target,
                     "pair dispatch captures slot1 predict_target");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_predict_btb_hit == pre_pair_handoff_slot1_predict_btb_hit,
                     "pair dispatch captures slot1 btb_hit");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_rs1_addr == pre_pair_handoff_slot1_rs1_addr,
                     "pair dispatch captures slot1 rs1_addr");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_candidate_alu_branch == pre_pair_handoff_candidate_alu_branch,
                     "pair dispatch captures candidate classification");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_allow_second == pre_handoff_scoreboard_allow_second,
                     "pair dispatch captures runtime executable fireability");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_order_alu_then_branch == pre_pair_handoff_order_alu_then_branch,
                     "pair dispatch captures alu-then-branch order");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_order_branch_then_alu == pre_pair_handoff_order_branch_then_alu,
                     "pair dispatch captures branch-then-alu order");
      if (pre_pair_dispatch_valid &&
          root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_pc == pre_pair_dispatch_slot0_pc &&
          root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_pc == pre_pair_dispatch_slot1_pc &&
          root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src1 == pre_pair_dispatch_slot0_src1 &&
          root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src1 == pre_pair_dispatch_slot1_src1 &&
          root->sim_top__DOT__cpu__DOT__pair_dispatch_allow_second == pre_pair_dispatch_allow_second) {
        coverage.pair_dispatch_hold_cycles++;
      }
      coverage.pair_dispatch_capture_fireable_events++;
    } else if (pre_pair_dispatch_valid) {
      coverage.pair_dispatch_hold_cycles++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_valid == 1,
                     "pair dispatch holds valid without flush");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_valid == pre_pair_dispatch_slot0_valid,
                     "pair dispatch holds slot0 valid stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_pc == pre_pair_dispatch_slot0_pc,
                     "pair dispatch holds slot0 pc stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_ins == pre_pair_dispatch_slot0_ins,
                     "pair dispatch holds slot0 instruction stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src1 == pre_pair_dispatch_slot0_src1,
                     "pair dispatch holds slot0 src1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src2 == pre_pair_dispatch_slot0_src2,
                     "pair dispatch holds slot0 src2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_imm == pre_pair_dispatch_slot0_imm,
                     "pair dispatch holds slot0 immediate stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src_sel1 == pre_pair_dispatch_slot0_src_sel1,
                     "pair dispatch holds slot0 src_sel1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_src_sel2 == pre_pair_dispatch_slot0_src_sel2,
                     "pair dispatch holds slot0 src_sel2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_rd == pre_pair_dispatch_slot0_rd,
                     "pair dispatch holds slot0 rd stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_csr_addr == pre_pair_dispatch_slot0_csr_addr,
                     "pair dispatch holds slot0 csr_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_exu_opt == pre_pair_dispatch_slot0_exu_opt,
                     "pair dispatch holds slot0 exu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_alu_opt == pre_pair_dispatch_slot0_alu_opt,
                     "pair dispatch holds slot0 alu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_wen == pre_pair_dispatch_slot0_wen,
                     "pair dispatch holds slot0 wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_csr_wen == pre_pair_dispatch_slot0_csr_wen,
                     "pair dispatch holds slot0 csr_wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_mret == pre_pair_dispatch_slot0_mret,
                     "pair dispatch holds slot0 mret stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_ecall == pre_pair_dispatch_slot0_ecall,
                     "pair dispatch holds slot0 ecall stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_load == pre_pair_dispatch_slot0_load,
                     "pair dispatch holds slot0 load stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_store == pre_pair_dispatch_slot0_store,
                     "pair dispatch holds slot0 store stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_brch == pre_pair_dispatch_slot0_brch,
                     "pair dispatch holds slot0 brch stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_jal == pre_pair_dispatch_slot0_jal,
                     "pair dispatch holds slot0 jal stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_jalr == pre_pair_dispatch_slot0_jalr,
                     "pair dispatch holds slot0 jalr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_ebreak == pre_pair_dispatch_slot0_ebreak,
                     "pair dispatch holds slot0 ebreak stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_fence_i == pre_pair_dispatch_slot0_fence_i,
                     "pair dispatch holds slot0 fence_i stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_muldiv == pre_pair_dispatch_slot0_muldiv,
                     "pair dispatch holds slot0 muldiv stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_is_cop_insn == pre_pair_dispatch_slot0_is_cop_insn,
                     "pair dispatch holds slot0 cop stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_predict_taken == pre_pair_dispatch_slot0_predict_taken,
                     "pair dispatch holds slot0 predict_taken stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_predict_target == pre_pair_dispatch_slot0_predict_target,
                     "pair dispatch holds slot0 predict_target stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_predict_btb_hit == pre_pair_dispatch_slot0_predict_btb_hit,
                     "pair dispatch holds slot0 btb_hit stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot0_rs1_addr == pre_pair_dispatch_slot0_rs1_addr,
                     "pair dispatch holds slot0 rs1_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_valid == pre_pair_dispatch_slot1_valid,
                     "pair dispatch holds slot1 valid stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_pc == pre_pair_dispatch_slot1_pc,
                     "pair dispatch holds slot1 pc stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_ins == pre_pair_dispatch_slot1_ins,
                     "pair dispatch holds slot1 instruction stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src1 == pre_pair_dispatch_slot1_src1,
                     "pair dispatch holds slot1 src1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src2 == pre_pair_dispatch_slot1_src2,
                     "pair dispatch holds slot1 src2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_imm == pre_pair_dispatch_slot1_imm,
                     "pair dispatch holds slot1 immediate stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src_sel1 == pre_pair_dispatch_slot1_src_sel1,
                     "pair dispatch holds slot1 src_sel1 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_src_sel2 == pre_pair_dispatch_slot1_src_sel2,
                     "pair dispatch holds slot1 src_sel2 stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_rd == pre_pair_dispatch_slot1_rd,
                     "pair dispatch holds slot1 rd stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_csr_addr == pre_pair_dispatch_slot1_csr_addr,
                     "pair dispatch holds slot1 csr_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_exu_opt == pre_pair_dispatch_slot1_exu_opt,
                     "pair dispatch holds slot1 exu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_alu_opt == pre_pair_dispatch_slot1_alu_opt,
                     "pair dispatch holds slot1 alu_opt stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_wen == pre_pair_dispatch_slot1_wen,
                     "pair dispatch holds slot1 wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_csr_wen == pre_pair_dispatch_slot1_csr_wen,
                     "pair dispatch holds slot1 csr_wen stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_mret == pre_pair_dispatch_slot1_mret,
                     "pair dispatch holds slot1 mret stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_ecall == pre_pair_dispatch_slot1_ecall,
                     "pair dispatch holds slot1 ecall stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_load == pre_pair_dispatch_slot1_load,
                     "pair dispatch holds slot1 load stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_store == pre_pair_dispatch_slot1_store,
                     "pair dispatch holds slot1 store stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_brch == pre_pair_dispatch_slot1_brch,
                     "pair dispatch holds slot1 brch stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_jal == pre_pair_dispatch_slot1_jal,
                     "pair dispatch holds slot1 jal stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_jalr == pre_pair_dispatch_slot1_jalr,
                     "pair dispatch holds slot1 jalr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_ebreak == pre_pair_dispatch_slot1_ebreak,
                     "pair dispatch holds slot1 ebreak stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_fence_i == pre_pair_dispatch_slot1_fence_i,
                     "pair dispatch holds slot1 fence_i stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_muldiv == pre_pair_dispatch_slot1_muldiv,
                     "pair dispatch holds slot1 muldiv stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_is_cop_insn == pre_pair_dispatch_slot1_is_cop_insn,
                     "pair dispatch holds slot1 cop stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_predict_taken == pre_pair_dispatch_slot1_predict_taken,
                     "pair dispatch holds slot1 predict_taken stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_predict_target == pre_pair_dispatch_slot1_predict_target,
                     "pair dispatch holds slot1 predict_target stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_predict_btb_hit == pre_pair_dispatch_slot1_predict_btb_hit,
                     "pair dispatch holds slot1 btb_hit stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_slot1_rs1_addr == pre_pair_dispatch_slot1_rs1_addr,
                     "pair dispatch holds slot1 rs1_addr stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_candidate_alu_branch == pre_pair_dispatch_candidate_alu_branch,
                     "pair dispatch holds candidate classification stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_allow_second == pre_pair_dispatch_allow_second,
                     "pair dispatch holds fireability stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_order_alu_then_branch == pre_pair_dispatch_order_alu_then_branch,
                     "pair dispatch holds alu-then-branch order stable");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_order_branch_then_alu == pre_pair_dispatch_order_branch_then_alu,
                     "pair dispatch holds branch-then-alu order stable");
    }

    if (pre_frontend_flush) {
      fail |= expect(root->sim_top__DOT__cpu__DOT__lane1_issue_valid == 0,
                     "frontend flush clears the live lane1 issue bit");
      if (pre_lane1_issue_valid || pre_lane1_issue_accept) {
        coverage.lane1_issue_flush_clear_events++;
      }
    } else if (pre_lane1_issue_kill) {
      coverage.lane1_issue_kill_events++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__lane1_issue_valid == 0,
                     "runtime scoreboard kill clears the live lane1 issue bit");
    } else if (pre_lane1_issue_accept) {
      coverage.lane1_issue_accept_events++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__lane1_issue_valid == 1,
                     "dispatch-visible executable pair raises the live lane1 issue bit");
    } else if (pre_lane1_issue_valid) {
      coverage.lane1_issue_hold_cycles++;
      fail |= expect(root->sim_top__DOT__cpu__DOT__lane1_issue_valid == 1,
                     "live lane1 issue bit holds without flush or kill");
    }

    if (root->sim_top__DOT__cpu__DOT__lane1_issue_valid) {
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_valid == 1,
                     "live lane1 issue bit always has a dispatch payload behind it");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_candidate_alu_branch == 1,
                     "live lane1 issue bit keeps alu-plus-branch candidate classification");
      fail |= expect(root->sim_top__DOT__cpu__DOT__pair_dispatch_order_alu_then_branch == 1,
                     "live lane1 issue bit keeps alu-then-branch ordering");
    }

    top->clock = 0;
    top->eval();
    main_time++;
  }

  fail |= expect(finished, "test program reaches halt address");
  fail |= expect(exit_code == 0, "test program exits cleanly");
  fail |= expect(coverage.slot1_visible_events > 0,
                 "slot1 observability becomes visible at least once");
  fail |= expect(coverage.slot1_fireable_events > 0,
                 "slot1 observability becomes fireable at least once");
  fail |= expect(coverage.slot1_blocked_nonflush_events > 0,
                 "slot1 observability becomes blocked without flush at least once");
  fail |= expect(coverage.slot1_flushed_events > 0,
                 "slot1 observability remains visible across at least one flush-blocked cycle");
  fail |= expect(coverage.slot1_blocked_events ==
                     (coverage.slot1_blocked_nonflush_events + coverage.slot1_flushed_events),
                 "slot1 blocked coverage accounting stays self-consistent");
  fail |= expect(coverage.shadow_capture_events > 0,
                 "slot1 shadow transport captures at least one visible slot1");
  fail |= expect(coverage.shadow_capture_fireable_events > 0,
                 "slot1 shadow transport captures at least one fireable slot1");
  fail |= expect(coverage.shadow_capture_blocked_events > 0,
                 "slot1 shadow transport captures at least one blocked slot1");
  fail |= expect(coverage.shadow_hold_cycles > 0,
                 "slot1 shadow transport holds a captured payload across at least one cycle");
  fail |= expect(coverage.shadow_flush_clear_events > 0,
                 "slot1 shadow transport is cleared by at least one flush event");
  fail |= expect(coverage.endpoint_capture_events > 0,
                 "slot1 endpoint accepts at least one visible slot1 payload");
  fail |= expect(coverage.endpoint_capture_fireable_events > 0,
                 "slot1 endpoint accepts at least one fireable slot1 payload");
  fail |= expect(coverage.endpoint_capture_blocked_events > 0,
                 "slot1 endpoint accepts at least one blocked slot1 payload");
  fail |= expect(coverage.endpoint_hold_cycles > 0,
                 "slot1 endpoint holds an accepted payload across at least one cycle");
  fail |= expect(coverage.endpoint_flush_clear_events > 0,
                 "slot1 endpoint is cleared by at least one flush event");
  fail |= expect(coverage.pair_bundle_capture_events > 0,
                 "frontend pair bundle captures at least one visible pair");
  fail |= expect(coverage.pair_bundle_capture_fireable_events > 0,
                 "frontend pair bundle captures at least one fireable pair");
  fail |= expect(coverage.pair_bundle_capture_blocked_events > 0,
                 "frontend pair bundle captures at least one blocked pair");
  fail |= expect(coverage.pair_bundle_hold_cycles > 0,
                 "frontend pair bundle holds a captured pair across at least one cycle");
  fail |= expect(coverage.pair_bundle_flush_clear_events > 0,
                 "frontend pair bundle is cleared by at least one flush event");
  fail |= expect(coverage.pair_bundle_capture_events ==
                     (coverage.pair_bundle_capture_fireable_events + coverage.pair_bundle_capture_blocked_events),
                 "frontend pair bundle fireable and blocked accounting stays self-consistent");
  fail |= expect(coverage.pair_handoff_capture_events > 0,
                 "pair handoff captures at least one visible pair");
  fail |= expect(coverage.pair_handoff_capture_fireable_events > 0,
                 "pair handoff captures at least one fireable pair");
  fail |= expect(coverage.pair_handoff_capture_blocked_events > 0,
                 "pair handoff captures at least one blocked pair");
  fail |= expect(coverage.pair_handoff_hold_cycles > 0,
                 "pair handoff holds a captured pair across at least one cycle");
  fail |= expect(coverage.pair_handoff_flush_clear_events > 0,
                 "pair handoff is cleared by at least one flush event");
  fail |= expect(coverage.pair_handoff_capture_events ==
                     (coverage.pair_handoff_capture_fireable_events + coverage.pair_handoff_capture_blocked_events),
                 "pair handoff fireable and blocked accounting stays self-consistent");
  fail |= expect(coverage.pair_dispatch_capture_events > 0,
                 "pair dispatch captures at least one fireable pair");
  fail |= expect(coverage.pair_dispatch_capture_fireable_events > 0,
                  "pair dispatch captures at least one fireable pair");
  fail |= expect(coverage.pair_dispatch_hold_cycles > 0,
                   "pair dispatch holds a captured pair across at least one cycle");
  fail |= expect(coverage.pair_dispatch_flush_clear_events > 0,
                   "pair dispatch is cleared by at least one flush event");
  fail |= expect(coverage.pair_dispatch_capture_events ==
                     coverage.pair_dispatch_capture_fireable_events,
                 "pair dispatch accounting stays fireable-only");
  fail |= expect(coverage.lane1_issue_accept_events > 0,
                 "live lane1 issue bit accepts at least one dispatch-visible pair");
  fail |= expect(coverage.lane1_issue_hold_cycles > 0,
                 "live lane1 issue bit holds across at least one cycle");
  fail |= expect(coverage.lane1_issue_flush_clear_events > 0,
                 "live lane1 issue bit is cleared by at least one flush event");

  delete top;

  if (fail) {
    return 1;
  }

  std::printf("PASS: top-level slot1 transport and live lane1 boundary stay self-consistent "
              "(slot1-events=%llu, fireable=%llu, blocked=%llu, blocked-nonflush=%llu, flushed=%llu, shadow-captures=%llu, shadow-fireable=%llu, shadow-blocked=%llu, shadow-hold=%llu, shadow-flush-clear=%llu, endpoint-captures=%llu, endpoint-fireable=%llu, endpoint-blocked=%llu, endpoint-hold=%llu, endpoint-flush-clear=%llu, pair-captures=%llu, pair-fireable=%llu, pair-blocked=%llu, pair-hold=%llu, pair-flush-clear=%llu, handoff-captures=%llu, handoff-fireable=%llu, handoff-blocked=%llu, handoff-hold=%llu, handoff-flush-clear=%llu, dispatch-captures=%llu, dispatch-fireable=%llu, dispatch-hold=%llu, dispatch-flush-clear=%llu, lane1-accepts=%llu, lane1-hold=%llu, lane1-kills=%llu, lane1-flush-clear=%llu)\n",
              static_cast<unsigned long long>(coverage.slot1_visible_events),
              static_cast<unsigned long long>(coverage.slot1_fireable_events),
              static_cast<unsigned long long>(coverage.slot1_blocked_events),
              static_cast<unsigned long long>(coverage.slot1_blocked_nonflush_events),
              static_cast<unsigned long long>(coverage.slot1_flushed_events),
              static_cast<unsigned long long>(coverage.shadow_capture_events),
              static_cast<unsigned long long>(coverage.shadow_capture_fireable_events),
              static_cast<unsigned long long>(coverage.shadow_capture_blocked_events),
              static_cast<unsigned long long>(coverage.shadow_hold_cycles),
              static_cast<unsigned long long>(coverage.shadow_flush_clear_events),
              static_cast<unsigned long long>(coverage.endpoint_capture_events),
              static_cast<unsigned long long>(coverage.endpoint_capture_fireable_events),
              static_cast<unsigned long long>(coverage.endpoint_capture_blocked_events),
              static_cast<unsigned long long>(coverage.endpoint_hold_cycles),
              static_cast<unsigned long long>(coverage.endpoint_flush_clear_events),
              static_cast<unsigned long long>(coverage.pair_bundle_capture_events),
              static_cast<unsigned long long>(coverage.pair_bundle_capture_fireable_events),
              static_cast<unsigned long long>(coverage.pair_bundle_capture_blocked_events),
              static_cast<unsigned long long>(coverage.pair_bundle_hold_cycles),
              static_cast<unsigned long long>(coverage.pair_bundle_flush_clear_events),
              static_cast<unsigned long long>(coverage.pair_handoff_capture_events),
              static_cast<unsigned long long>(coverage.pair_handoff_capture_fireable_events),
              static_cast<unsigned long long>(coverage.pair_handoff_capture_blocked_events),
              static_cast<unsigned long long>(coverage.pair_handoff_hold_cycles),
              static_cast<unsigned long long>(coverage.pair_handoff_flush_clear_events),
              static_cast<unsigned long long>(coverage.pair_dispatch_capture_events),
              static_cast<unsigned long long>(coverage.pair_dispatch_capture_fireable_events),
              static_cast<unsigned long long>(coverage.pair_dispatch_hold_cycles),
              static_cast<unsigned long long>(coverage.pair_dispatch_flush_clear_events),
              static_cast<unsigned long long>(coverage.lane1_issue_accept_events),
              static_cast<unsigned long long>(coverage.lane1_issue_hold_cycles),
              static_cast<unsigned long long>(coverage.lane1_issue_kill_events),
              static_cast<unsigned long long>(coverage.lane1_issue_flush_clear_events));
  return 0;
}
