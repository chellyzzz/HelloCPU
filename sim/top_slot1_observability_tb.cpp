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
    const bool pre_pair_younger_predict_taken = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predict_taken;
    const uint32_t pre_pair_younger_predict_target = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predict_target;
    const bool pre_pair_younger_predict_btb_hit = root->sim_top__DOT__cpu__DOT__ifu_pair_younger_predict_btb_hit;
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

  delete top;

  if (fail) {
    return 1;
  }

  std::printf("PASS: top-level slot1 observability remains non-binding and branch-only "
              "(slot1-events=%llu, fireable=%llu, blocked=%llu, blocked-nonflush=%llu, flushed=%llu, shadow-captures=%llu, shadow-fireable=%llu, shadow-blocked=%llu, shadow-hold=%llu, shadow-flush-clear=%llu)\n",
              static_cast<unsigned long long>(coverage.slot1_visible_events),
              static_cast<unsigned long long>(coverage.slot1_fireable_events),
              static_cast<unsigned long long>(coverage.slot1_blocked_events),
              static_cast<unsigned long long>(coverage.slot1_blocked_nonflush_events),
              static_cast<unsigned long long>(coverage.slot1_flushed_events),
              static_cast<unsigned long long>(coverage.shadow_capture_events),
              static_cast<unsigned long long>(coverage.shadow_capture_fireable_events),
              static_cast<unsigned long long>(coverage.shadow_capture_blocked_events),
              static_cast<unsigned long long>(coverage.shadow_hold_cycles),
              static_cast<unsigned long long>(coverage.shadow_flush_clear_events));
  return 0;
}
