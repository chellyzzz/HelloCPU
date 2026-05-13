#include "Vsim_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <algorithm>

// 64MB memory starting at 0x30000000
#define MEM_BASE 0x30000000
#define MEM_SIZE (64 * 1024 * 1024)
#define UART_ADDR 0x10000000
#define HALT_ADDR 0x10000004

static uint8_t mem[MEM_SIZE];
static bool finished = false;
static int exit_code = -1;
static uint64_t cycles = 0;
static uint64_t max_cycles = 100000000; // 50M cycle timeout
static bool mem_trace_en = false;
static FILE *mem_trace_fp = nullptr;
static const char *mem_trace_path = "mem_trace.log";
static bool commit_trace_en = false;
static FILE *commit_trace_fp = nullptr;
static const char *commit_trace_path = "commit_trace.log";
static bool branch_trace_en = false;
static FILE *branch_trace_fp = nullptr;
static const char *branch_trace_path = "branch_trace.log";

// ---- performance counters ----
static uint64_t cnt_inst = 0;
static uint64_t cnt_brch = 0;
static uint64_t cnt_brch_tkn = 0;
static uint64_t cnt_jal = 0;
static uint64_t cnt_load = 0;
static uint64_t cnt_store = 0;
static uint64_t cnt_mul = 0;
static uint64_t cnt_mul_low = 0;
static uint64_t cnt_mul_high = 0;
static uint64_t cnt_div = 0;
static uint64_t cnt_cop = 0;
static uint64_t cnt_alu = 0;
static uint64_t cnt_csr = 0;
static uint64_t cnt_sys = 0;
static uint64_t cnt_fence = 0;
static uint64_t cnt_stall = 0;
static uint64_t cnt_stall_front = 0;
static uint64_t cnt_stall_ifu_held = 0;
static uint64_t cnt_stall_ifu_held_ctrl = 0;
static uint64_t cnt_stall_ifu_held_lsu = 0;
static uint64_t cnt_stall_ifu_held_mul = 0;
static uint64_t cnt_stall_ifu_held_mul_only = 0;
static uint64_t cnt_stall_ifu_held_div = 0;
static uint64_t cnt_stall_ifu_held_cop = 0;
static uint64_t cnt_stall_ifu_held_other = 0;
static uint64_t cnt_stall_lsu = 0;
static uint64_t cnt_stall_lsu_start = 0;
static uint64_t cnt_stall_lsu_start_load = 0;
static uint64_t cnt_stall_lsu_start_store = 0;
static uint64_t cnt_stall_lsu_hit = 0;
static uint64_t cnt_stall_lsu_refill = 0;
static uint64_t cnt_stall_lsu_refill_ar = 0;
static uint64_t cnt_stall_lsu_refill_r = 0;
static uint64_t cnt_stall_lsu_uncached = 0;
static uint64_t cnt_stall_lsu_wb = 0;
static uint64_t cnt_stall_mul = 0;
static uint64_t cnt_stall_mul_only = 0;
static uint64_t cnt_stall_div = 0;
static uint64_t cnt_stall_cop = 0;
static uint64_t cnt_stall_ctrl = 0;
static uint64_t cnt_stall_other = 0;
static uint64_t cnt_stall_other_blocked = 0;
static uint64_t cnt_stall_other_pipe = 0;
static uint64_t cnt_stall_other_pipe_alu = 0;
static uint64_t cnt_stall_other_pipe_brch = 0;
static uint64_t cnt_stall_other_pipe_jal = 0;
static uint64_t cnt_stall_other_pipe_jalr = 0;
static uint64_t cnt_stall_other_pipe_sys = 0;
static uint64_t cnt_backend_pipe_occ = 0;
static uint64_t cnt_icache_hit = 0;
static uint64_t cnt_icache_miss = 0;
static uint64_t cnt_ifu_fetch = 0;
static uint64_t cnt_ifu_done = 0;
static uint64_t cnt_load_bus = 0;
static uint64_t cnt_load_done = 0;
static uint64_t cnt_store_bus = 0;
static uint64_t cnt_store_done = 0;
static uint64_t cnt_btb_hit = 0;
static uint64_t cnt_btb_miss = 0;
static uint64_t cnt_btb_mispredict = 0;
static uint64_t cnt_br_misp_pred_nt = 0;
static uint64_t cnt_br_misp_pred_taken_nt = 0;
static uint64_t cnt_br_misp_target_bad = 0;
static uint64_t cnt_br_misp_pred_nt_btb_hit = 0;
static uint64_t cnt_br_misp_pred_nt_btb_miss = 0;
static uint64_t cnt_br_misp_pred_taken_nt_btb_hit = 0;
static uint64_t cnt_br_misp_pred_taken_nt_btb_miss = 0;
static uint64_t cnt_ras_hit = 0;
static uint64_t cnt_ras_miss = 0;
static uint64_t cnt_jal_tgt_bad = 0;
static uint64_t cnt_ras_push = 0;
static uint64_t cnt_wbu_pcup = 0;
static uint64_t cnt_wbu_pcup_brch = 0;
static uint64_t cnt_wbu_pcup_jal = 0;
static uint64_t cnt_wbu_pcup_jalr = 0;
static uint64_t cnt_wbu_pcup_ecall = 0;
static uint64_t cnt_wbu_pcup_mret = 0;
static uint64_t cnt_redirect_gap = 0;
static uint64_t cnt_redirect_events = 0;
static uint64_t cnt_redirect_gap_brch = 0;
static uint64_t cnt_redirect_events_brch = 0;
static uint64_t cnt_redirect_gap_jal = 0;
static uint64_t cnt_redirect_events_jal = 0;
static uint64_t cnt_redirect_gap_jalr = 0;
static uint64_t cnt_redirect_events_jalr = 0;

struct PcHotspot {
  uint32_t pc;
  uint64_t count;
};

static uint64_t pc_counts[65536];
static uint64_t mergesort_loop_samples = 0;

static uint32_t pmem_peek32(uint32_t addr) {
  uint32_t offset = addr - MEM_BASE;
  if (offset + sizeof(uint32_t) > MEM_SIZE)
    return 0;
  return *(uint32_t *)(mem + offset);
}

static void record_commit_pc(uint32_t pc) {
  if (pc < MEM_BASE)
    return;
  uint32_t index = (pc - MEM_BASE) >> 2;
  if (index < 65536)
    pc_counts[index]++;
}

static void print_pc_hotspots() {
  PcHotspot pc_hotspots[16] = {};
  for (uint32_t index = 0; index < 65536; index++) {
    uint64_t count = pc_counts[index];
    if (!count || count <= pc_hotspots[15].count)
      continue;
    pc_hotspots[15] = {MEM_BASE + (index << 2), count};
    std::sort(std::begin(pc_hotspots), std::end(pc_hotspots),
              [](const PcHotspot &a, const PcHotspot &b) {
                return a.count > b.count;
              });
  }
  printf("├─────────────────────────────────────────────────────┤\n");
  printf("│ Commit PC Hotspots (approx.)                       │\n");
  for (const auto &slot : pc_hotspots) {
    if (slot.count)
      printf("│   pc=0x%08x count=%12lu                 │\n", slot.pc,
             slot.count);
  }
}

// ---- performance summary printer ----
static void print_perf_summary() {
  uint64_t total_clk = cycles / 2;
  if (total_clk == 0)
    total_clk = 1;
  printf("\n");
  printf("┌─────────────────────────────────────────────────────┐\n");
  printf("│            Performance Counter Summary              │\n");
  printf("├─────────────────────────────────────────────────────┤\n");
  printf("│ Total cycles         : %12lu                 │\n", total_clk);
  printf("│ Total instructions   : %12lu (IPC = %.3f)       │\n", cnt_inst,
         (double)cnt_inst / total_clk);
  printf("│ True stall cycles    : %12lu (%.1f%%)            │\n", cnt_stall,
         100.0 * cnt_stall / total_clk);
  printf("│ Backend pipe occ     : %12lu (%.1f%%)            │\n",
         cnt_backend_pipe_occ, 100.0 * cnt_backend_pipe_occ / total_clk);
  if (cnt_stall > 0) {
    printf("│   Frontend/empty     : %10lu (%5.1f%%)            │\n",
           cnt_stall_front, 100.0 * cnt_stall_front / cnt_stall);
    printf("│   IFU held valid     : %10lu (%5.1f%%)            │\n",
           cnt_stall_ifu_held, 100.0 * cnt_stall_ifu_held / cnt_stall);
    if (cnt_stall_ifu_held > 0) {
      printf("│     ├─ control       : %10lu (%5.1f%%)            │\n",
             cnt_stall_ifu_held_ctrl,
             100.0 * cnt_stall_ifu_held_ctrl / cnt_stall_ifu_held);
      printf("│     ├─ LSU           : %10lu (%5.1f%%)            │\n",
             cnt_stall_ifu_held_lsu,
             100.0 * cnt_stall_ifu_held_lsu / cnt_stall_ifu_held);
      printf("│     ├─ MUL/DIV       : %10lu (%5.1f%%)            │\n",
             cnt_stall_ifu_held_mul,
             100.0 * cnt_stall_ifu_held_mul / cnt_stall_ifu_held);
      if (cnt_stall_ifu_held_mul > 0) {
        printf("│     │  ├─ MUL-high   : %10lu (%5.1f%%)            │\n",
               cnt_stall_ifu_held_mul_only,
               100.0 * cnt_stall_ifu_held_mul_only / cnt_stall_ifu_held_mul);
        printf("│     │  ├─ DIV        : %10lu (%5.1f%%)            │\n",
               cnt_stall_ifu_held_div,
               100.0 * cnt_stall_ifu_held_div / cnt_stall_ifu_held_mul);
      }
      printf("│     ├─ COP           : %10lu (%5.1f%%)            │\n",
             cnt_stall_ifu_held_cop,
             100.0 * cnt_stall_ifu_held_cop / cnt_stall_ifu_held);
      printf("│     ├─ other         : %10lu (%5.1f%%)            │\n",
             cnt_stall_ifu_held_other,
             100.0 * cnt_stall_ifu_held_other / cnt_stall_ifu_held);
    }
    printf("│   LSU wait           : %10lu (%5.1f%%)            │\n",
           cnt_stall_lsu, 100.0 * cnt_stall_lsu / cnt_stall);
    if (cnt_stall_lsu > 0) {
      printf("│     ├─ start         : %10lu (%5.1f%%)            │\n",
             cnt_stall_lsu_start, 100.0 * cnt_stall_lsu_start / cnt_stall_lsu);
      if (cnt_stall_lsu_start > 0) {
        printf("│     │  ├─ load       : %10lu (%5.1f%%)            │\n",
               cnt_stall_lsu_start_load,
               100.0 * cnt_stall_lsu_start_load / cnt_stall_lsu_start);
        printf("│     │  ├─ store      : %10lu (%5.1f%%)            │\n",
               cnt_stall_lsu_start_store,
               100.0 * cnt_stall_lsu_start_store / cnt_stall_lsu_start);
      }
      printf("│     ├─ hit path      : %10lu (%5.1f%%)            │\n",
             cnt_stall_lsu_hit, 100.0 * cnt_stall_lsu_hit / cnt_stall_lsu);
      printf("│     ├─ refill        : %10lu (%5.1f%%)            │\n",
             cnt_stall_lsu_refill,
             100.0 * cnt_stall_lsu_refill / cnt_stall_lsu);
      if (cnt_stall_lsu_refill > 0) {
        printf("│     │  ├─ AR wait    : %10lu (%5.1f%%)            │\n",
               cnt_stall_lsu_refill_ar,
               100.0 * cnt_stall_lsu_refill_ar / cnt_stall_lsu_refill);
        printf("│     │  ├─ R data     : %10lu (%5.1f%%)            │\n",
               cnt_stall_lsu_refill_r,
               100.0 * cnt_stall_lsu_refill_r / cnt_stall_lsu_refill);
      }
      printf("│     ├─ uncached      : %10lu (%5.1f%%)            │\n",
             cnt_stall_lsu_uncached,
             100.0 * cnt_stall_lsu_uncached / cnt_stall_lsu);
      printf("│     ├─ writeback     : %10lu (%5.1f%%)            │\n",
             cnt_stall_lsu_wb, 100.0 * cnt_stall_lsu_wb / cnt_stall_lsu);
    }
    printf("│   MUL/DIV wait       : %10lu (%5.1f%%)            │\n",
           cnt_stall_mul, 100.0 * cnt_stall_mul / cnt_stall);
    if (cnt_stall_mul > 0) {
      printf("│     ├─ MUL-high      : %10lu (%5.1f%%)            │\n",
             cnt_stall_mul_only, 100.0 * cnt_stall_mul_only / cnt_stall_mul);
      printf("│     ├─ DIV           : %10lu (%5.1f%%)            │\n",
             cnt_stall_div, 100.0 * cnt_stall_div / cnt_stall_mul);
    }
    printf("│   COP wait           : %10lu (%5.1f%%)            │\n",
           cnt_stall_cop, 100.0 * cnt_stall_cop / cnt_stall);
    printf("│   Control recovery   : %10lu (%5.1f%%)            │\n",
           cnt_stall_ctrl, 100.0 * cnt_stall_ctrl / cnt_stall);
    printf("│   Other blocked bknd : %10lu (%5.1f%%)            │\n",
           cnt_stall_other_blocked, 100.0 * cnt_stall_other_blocked / cnt_stall);
    if (cnt_stall_other > 0) {
      printf("│     ├─ residual total: %10lu (%5.1f%%)            │\n",
             cnt_stall_other,
             100.0 * cnt_stall_other / cnt_stall);
    }
  }
  if (cnt_backend_pipe_occ > 0) {
    printf("│   Pipe occ breakdown : %10lu (%5.1f%%)            │\n",
           cnt_stall_other_pipe, 100.0 * cnt_stall_other_pipe / cnt_backend_pipe_occ);
    printf("│     ├─ ALU/other     : %10lu (%5.1f%%)            │\n",
           cnt_stall_other_pipe_alu,
           100.0 * cnt_stall_other_pipe_alu / cnt_backend_pipe_occ);
    printf("│     ├─ branch        : %10lu (%5.1f%%)            │\n",
           cnt_stall_other_pipe_brch,
           100.0 * cnt_stall_other_pipe_brch / cnt_backend_pipe_occ);
    printf("│     ├─ JAL           : %10lu (%5.1f%%)            │\n",
           cnt_stall_other_pipe_jal,
           100.0 * cnt_stall_other_pipe_jal / cnt_backend_pipe_occ);
    printf("│     ├─ JALR          : %10lu (%5.1f%%)            │\n",
           cnt_stall_other_pipe_jalr,
           100.0 * cnt_stall_other_pipe_jalr / cnt_backend_pipe_occ);
    printf("│     ├─ sys/csr       : %10lu (%5.1f%%)            │\n",
           cnt_stall_other_pipe_sys,
           100.0 * cnt_stall_other_pipe_sys / cnt_backend_pipe_occ);
  }
  printf("├─────────────────────────────────────────────────────┤\n");
  printf("│ Instruction Mix                                    │\n");
  if (cnt_inst > 0) {
    printf("│   ALU ops           : %10lu (%5.1f%%)            │\n", cnt_alu,
           100.0 * cnt_alu / cnt_inst);
    printf("│   Branches          : %10lu (%5.1f%%)            │\n", cnt_brch,
           100.0 * cnt_brch / cnt_inst);
    printf("│     ├─ taken        : %10lu (%5.1f%%)            │\n",
           cnt_brch_tkn, 100.0 * cnt_brch_tkn / (cnt_brch ? cnt_brch : 1));
    printf("│   Jumps (JAL+JALR)  : %10lu (%5.1f%%)            │\n", cnt_jal,
           100.0 * cnt_jal / cnt_inst);
    printf("│   Loads             : %10lu (%5.1f%%)            │\n", cnt_load,
           100.0 * cnt_load / cnt_inst);
    printf("│   Stores            : %10lu (%5.1f%%)            │\n", cnt_store,
           100.0 * cnt_store / cnt_inst);
    printf("│   Multiplies        : %10lu (%5.1f%%)            │\n", cnt_mul,
           100.0 * cnt_mul / cnt_inst);
    if (cnt_mul > 0) {
      printf("│     ├─ MUL-low      : %10lu (%5.1f%%)            │\n",
             cnt_mul_low, 100.0 * cnt_mul_low / cnt_mul);
      printf("│     ├─ MUL-high     : %10lu (%5.1f%%)            │\n",
             cnt_mul_high, 100.0 * cnt_mul_high / cnt_mul);
    }
    printf("│   Divides           : %10lu (%5.1f%%)            │\n", cnt_div,
           100.0 * cnt_div / cnt_inst);
    printf("│   COP custom ops    : %10lu (%5.1f%%)            │\n", cnt_cop,
           100.0 * cnt_cop / cnt_inst);
    printf("│   CSR accesses      : %10lu (%5.1f%%)            │\n", cnt_csr,
           100.0 * cnt_csr / cnt_inst);
    printf("│   System (ECALL/MRET/EBREAK): %4lu (%5.1f%%)     │\n", cnt_sys,
           100.0 * cnt_sys / cnt_inst);
    printf("│   fence.i           : %10lu (%5.1f%%)            │\n", cnt_fence,
           100.0 * cnt_fence / cnt_inst);
  }
  printf("├─────────────────────────────────────────────────────┤\n");
  printf("│ Branch Predictor                                   │\n");
  uint64_t btb_total = cnt_btb_hit + cnt_btb_miss;
  if (btb_total > 0) {
    printf("│   BTB hits          : %10lu (%5.1f%%)            │\n",
           cnt_btb_hit, 100.0 * cnt_btb_hit / btb_total);
    printf("│   BTB misses        : %10lu (%5.1f%%)            │\n",
           cnt_btb_miss, 100.0 * cnt_btb_miss / btb_total);
    printf("│   BTB mispredicts   : %10lu (%5.1f%%)            │\n",
           cnt_btb_mispredict, 100.0 * cnt_btb_mispredict / btb_total);
    if (cnt_btb_mispredict > 0) {
      printf("│     ├─ pred NT,taken: %10lu (%5.1f%%)            │\n",
             cnt_br_misp_pred_nt,
             100.0 * cnt_br_misp_pred_nt / cnt_btb_mispredict);
      printf("│     │  ├─ btb hit   : %10lu (%5.1f%%)            │\n",
             cnt_br_misp_pred_nt_btb_hit,
             100.0 * cnt_br_misp_pred_nt_btb_hit / (cnt_br_misp_pred_nt ? cnt_br_misp_pred_nt : 1));
      printf("│     │  ├─ btb miss  : %10lu (%5.1f%%)            │\n",
             cnt_br_misp_pred_nt_btb_miss,
             100.0 * cnt_br_misp_pred_nt_btb_miss / (cnt_br_misp_pred_nt ? cnt_br_misp_pred_nt : 1));
      printf("│     ├─ pred T,NT    : %10lu (%5.1f%%)            │\n",
             cnt_br_misp_pred_taken_nt,
             100.0 * cnt_br_misp_pred_taken_nt / cnt_btb_mispredict);
      printf("│     │  ├─ btb hit   : %10lu (%5.1f%%)            │\n",
             cnt_br_misp_pred_taken_nt_btb_hit,
             100.0 * cnt_br_misp_pred_taken_nt_btb_hit / (cnt_br_misp_pred_taken_nt ? cnt_br_misp_pred_taken_nt : 1));
      printf("│     │  ├─ btb miss  : %10lu (%5.1f%%)            │\n",
             cnt_br_misp_pred_taken_nt_btb_miss,
             100.0 * cnt_br_misp_pred_taken_nt_btb_miss / (cnt_br_misp_pred_taken_nt ? cnt_br_misp_pred_taken_nt : 1));
      printf("│     ├─ target bad   : %10lu (%5.1f%%)            │\n",
             cnt_br_misp_target_bad,
             100.0 * cnt_br_misp_target_bad / cnt_btb_mispredict);
    }
  }
  uint64_t ras_total = cnt_ras_hit + cnt_ras_miss;
  if (ras_total > 0) {
    printf("│   RAS hits          : %10lu (%5.1f%%)            │\n",
           cnt_ras_hit, 100.0 * cnt_ras_hit / ras_total);
    printf("│   RAS misses        : %10lu (%5.1f%%)            │\n",
           cnt_ras_miss, 100.0 * cnt_ras_miss / ras_total);
  }
  printf("│ Debug: JAL tgt bad  : %10lu                     │\n",
         cnt_jal_tgt_bad);
  printf("│ Debug: RAS pushes   : %10lu                     │\n", cnt_ras_push);
  printf("│ Debug: WBU pcupdate : %10lu                     │\n", cnt_wbu_pcup);
  if (cnt_wbu_pcup > 0) {
    printf("│   ├─ branch         : %10lu (%5.1f%%)            │\n",
           cnt_wbu_pcup_brch, 100.0 * cnt_wbu_pcup_brch / cnt_wbu_pcup);
    printf("│   ├─ JAL            : %10lu (%5.1f%%)            │\n",
           cnt_wbu_pcup_jal, 100.0 * cnt_wbu_pcup_jal / cnt_wbu_pcup);
    printf("│   ├─ JALR           : %10lu (%5.1f%%)            │\n",
           cnt_wbu_pcup_jalr, 100.0 * cnt_wbu_pcup_jalr / cnt_wbu_pcup);
    printf("│   ├─ ECALL          : %10lu (%5.1f%%)            │\n",
           cnt_wbu_pcup_ecall, 100.0 * cnt_wbu_pcup_ecall / cnt_wbu_pcup);
    printf("│   ├─ MRET           : %10lu (%5.1f%%)            │\n",
           cnt_wbu_pcup_mret, 100.0 * cnt_wbu_pcup_mret / cnt_wbu_pcup);
  }
  if (cnt_redirect_events > 0) {
    printf("│ Redirect cost       : %10lu avg cycles (%lu events) │\n",
           cnt_redirect_gap / cnt_redirect_events, cnt_redirect_events);
    if (cnt_redirect_events_brch > 0)
      printf("│   ├─ branch         : %6lu avg (%lu events)            │\n",
             cnt_redirect_gap_brch / cnt_redirect_events_brch, cnt_redirect_events_brch);
    if (cnt_redirect_events_jal > 0)
      printf("│   ├─ JAL            : %6lu avg (%lu events)            │\n",
             cnt_redirect_gap_jal / cnt_redirect_events_jal, cnt_redirect_events_jal);
    if (cnt_redirect_events_jalr > 0)
      printf("│   ├─ JALR           : %6lu avg (%lu events)            │\n",
             cnt_redirect_gap_jalr / cnt_redirect_events_jalr, cnt_redirect_events_jalr);
  }
  printf("├─────────────────────────────────────────────────────┤\n");
  printf("│ Cache Statistics                                   │\n");
  uint64_t ic_total = cnt_icache_hit + cnt_icache_miss;
  if (ic_total > 0) {
    printf("│   ICache hits       : %10lu (%5.1f%%)            │\n",
           cnt_icache_hit, 100.0 * cnt_icache_hit / ic_total);
    printf("│   ICache misses     : %10lu (%5.1f%%)            │\n",
           cnt_icache_miss, 100.0 * cnt_icache_miss / ic_total);
    printf("│   ICache hit rate   : %10.1f%%                     │\n",
           100.0 * cnt_icache_hit / ic_total);
  }
  printf("├─────────────────────────────────────────────────────┤\n");
  printf("│ Bus Transactions                                   │\n");
  printf("│   IFU fetches       : %10lu / done: %lu                 │\n",
         cnt_ifu_fetch, cnt_ifu_done);
  printf("│   Load  xacts       : %10lu / done: %lu                 │\n",
         cnt_load_bus, cnt_load_done);
  printf("│   Store xacts       : %10lu / done: %lu                 │\n",
         cnt_store_bus, cnt_store_done);
  print_pc_hotspots();
  printf("└─────────────────────────────────────────────────────┘\n");
}

// DPI-C: memory read
extern "C" void pmem_read(int addr, int *data) {
  uint32_t offset = (uint32_t)addr - MEM_BASE;
  if (offset < MEM_SIZE) {
    *data = *(int *)(mem + offset);
  } else {
    *data = 0;
  }
}

// DPI-C: memory write (with UART simulation)
extern "C" void pmem_write(int addr, int data, int strb) {
  if ((uint32_t)addr == UART_ADDR) {
    putchar(data & 0xff);
    fflush(stdout);
    return;
  }
  if ((uint32_t)addr == HALT_ADDR) {
    finished = true;
    exit_code = data;
    return;
  }
  uint32_t offset = (uint32_t)addr - MEM_BASE;
  if (offset < MEM_SIZE) {
    if (mem_trace_en && mem_trace_fp && (uint32_t)addr >= MEM_BASE)
      fprintf(mem_trace_fp, "%08x %08x %x\n", (uint32_t)addr, (uint32_t)data,
              strb & 0xf);
    uint8_t *p = mem + offset;
    for (int i = 0; i < 4; i++) {
      if (strb & (1 << i)) {
        p[i] = (data >> (i * 8)) & 0xff;
      }
    }
  }
}

// DPI-C performance counters
extern "C" void inst_cnt_dpic() { cnt_inst++; }
extern "C" void brch_cnt_dpic() { cnt_brch++; }
extern "C" void brch_tkn_dpic() { cnt_brch_tkn++; }
extern "C" void jal_cnt_dpic() { cnt_jal++; }
extern "C" void load_dpic() { cnt_load++; }
extern "C" void store_dpic() { cnt_store++; }
extern "C" void mul_cnt_dpic() { cnt_mul++; }
extern "C" void mul_low_cnt_dpic() { cnt_mul_low++; }
extern "C" void mul_high_cnt_dpic() { cnt_mul_high++; }
extern "C" void div_cnt_dpic() { cnt_div++; }
extern "C" void cop_cnt_dpic() { cnt_cop++; }
extern "C" void alu_cnt_dpic() { cnt_alu++; }
extern "C" void csr_cnt_dpic() { cnt_csr++; }
extern "C" void sys_cnt_dpic() { cnt_sys++; }
extern "C" void fence_cnt_dpic() { cnt_fence++; }
extern "C" void stall_cnt_dpic() { cnt_stall++; }
extern "C" void stall_front_dpic() { cnt_stall_front++; }
extern "C" void stall_ifu_held_dpic() { cnt_stall_ifu_held++; }
extern "C" void stall_ifu_held_ctrl_dpic() { cnt_stall_ifu_held_ctrl++; }
extern "C" void stall_ifu_held_lsu_dpic() { cnt_stall_ifu_held_lsu++; }
extern "C" void stall_ifu_held_mul_dpic() { cnt_stall_ifu_held_mul++; }
extern "C" void stall_ifu_held_mul_only_dpic() { cnt_stall_ifu_held_mul_only++; }
extern "C" void stall_ifu_held_div_dpic() { cnt_stall_ifu_held_div++; }
extern "C" void stall_ifu_held_cop_dpic() { cnt_stall_ifu_held_cop++; }
extern "C" void stall_ifu_held_other_dpic() { cnt_stall_ifu_held_other++; }
extern "C" void stall_lsu_dpic() { cnt_stall_lsu++; }
extern "C" void stall_lsu_start_dpic() { cnt_stall_lsu_start++; }
extern "C" void stall_lsu_start_load_dpic() { cnt_stall_lsu_start_load++; }
extern "C" void stall_lsu_start_store_dpic() { cnt_stall_lsu_start_store++; }
extern "C" void stall_lsu_hit_dpic() { cnt_stall_lsu_hit++; }
extern "C" void stall_lsu_refill_dpic() { cnt_stall_lsu_refill++; }
extern "C" void stall_lsu_refill_ar_dpic() { cnt_stall_lsu_refill_ar++; }
extern "C" void stall_lsu_refill_r_dpic() { cnt_stall_lsu_refill_r++; }
extern "C" void stall_lsu_uncached_dpic() { cnt_stall_lsu_uncached++; }
extern "C" void stall_lsu_wb_dpic() { cnt_stall_lsu_wb++; }
extern "C" void stall_mul_dpic() { cnt_stall_mul++; }
extern "C" void stall_mul_only_dpic() { cnt_stall_mul_only++; }
extern "C" void stall_div_dpic() { cnt_stall_div++; }
extern "C" void stall_cop_dpic() { cnt_stall_cop++; }
extern "C" void stall_ctrl_dpic() { cnt_stall_ctrl++; }
extern "C" void stall_other_dpic() { cnt_stall_other++; }
extern "C" void stall_other_blocked_dpic() { cnt_stall_other_blocked++; }
extern "C" void stall_other_pipe_dpic() { cnt_stall_other_pipe++; }
extern "C" void stall_other_pipe_alu_dpic() { cnt_stall_other_pipe_alu++; }
extern "C" void stall_other_pipe_brch_dpic() { cnt_stall_other_pipe_brch++; }
extern "C" void stall_other_pipe_jal_dpic() { cnt_stall_other_pipe_jal++; }
extern "C" void stall_other_pipe_jalr_dpic() { cnt_stall_other_pipe_jalr++; }
extern "C" void stall_other_pipe_sys_dpic() { cnt_stall_other_pipe_sys++; }
extern "C" void backend_pipe_occ_dpic() { cnt_backend_pipe_occ++; }
extern "C" void cache_miss() { cnt_icache_miss++; }
extern "C" void ifu_start() { cnt_ifu_fetch++; }
extern "C" void ifu_end() { cnt_ifu_done++; }
extern "C" void load_start() { cnt_load_bus++; }
extern "C" void load_end() { cnt_load_done++; }
extern "C" void store_start() { cnt_store_bus++; }
extern "C" void store_end() { cnt_store_done++; }

// Legacy DPI-C names (aliases / no-ops — kept for backward compat)
extern "C" void load_cnt_dpic() { cnt_load_bus++; }
extern "C" void store_cnt_dpic() { cnt_store_bus++; }
extern "C" void icache_end() { cnt_icache_hit++; }
extern "C" void btb_hit_dpic() { cnt_btb_hit++; }
extern "C" void btb_miss_dpic() { cnt_btb_miss++; }
extern "C" void btb_misp_dpic() { cnt_btb_mispredict++; }
extern "C" void br_misp_pred_nt_dpic() { cnt_br_misp_pred_nt++; }
extern "C" void br_misp_pred_taken_nt_dpic() { cnt_br_misp_pred_taken_nt++; }
extern "C" void br_misp_target_bad_dpic() { cnt_br_misp_target_bad++; }
extern "C" void br_misp_pred_nt_btb_hit_dpic() { cnt_br_misp_pred_nt_btb_hit++; }
extern "C" void br_misp_pred_nt_btb_miss_dpic() { cnt_br_misp_pred_nt_btb_miss++; }
extern "C" void br_misp_pred_taken_nt_btb_hit_dpic() { cnt_br_misp_pred_taken_nt_btb_hit++; }
extern "C" void br_misp_pred_taken_nt_btb_miss_dpic() { cnt_br_misp_pred_taken_nt_btb_miss++; }
extern "C" void ras_hit_dpic() { cnt_ras_hit++; }
extern "C" void ras_miss_dpic() { cnt_ras_miss++; }
extern "C" void jal_tgt_mismatch() { cnt_jal_tgt_bad++; }
extern "C" void ras_push_dpic() { cnt_ras_push++; }
extern "C" void wbu_pcup_dpic() { cnt_wbu_pcup++; }
extern "C" void wbu_pcup_brch_dpic() { cnt_wbu_pcup_brch++; }
extern "C" void wbu_pcup_jal_dpic() { cnt_wbu_pcup_jal++; }
extern "C" void wbu_pcup_jalr_dpic() { cnt_wbu_pcup_jalr++; }
extern "C" void wbu_pcup_ecall_dpic() { cnt_wbu_pcup_ecall++; }
extern "C" void wbu_pcup_mret_dpic() { cnt_wbu_pcup_mret++; }
extern "C" void redirect_gap_dpic(int cycles) { cnt_redirect_gap += cycles; cnt_redirect_events++; }
extern "C" void redirect_gap_brch_dpic(int cycles) { cnt_redirect_gap_brch += cycles; cnt_redirect_events_brch++; }
extern "C" void redirect_gap_jal_dpic(int cycles) { cnt_redirect_gap_jal += cycles; cnt_redirect_events_jal++; }
extern "C" void redirect_gap_jalr_dpic(int cycles) { cnt_redirect_gap_jalr += cycles; cnt_redirect_events_jalr++; }
extern "C" void commit_pc_dpic(int pc) { record_commit_pc((uint32_t)pc); }
extern "C" void commit_trace_dpic(int pc, int rd, int wdata, int wen,
                                   int is_store, int store_addr,
                                   int store_data, int store_strb,
                                   int is_brch, int brch_taken,
                                   int predict_taken, int predict_correct,
                                   int pc_update, int flush) {
  if (!commit_trace_en || !commit_trace_fp)
    return;
  fprintf(commit_trace_fp,
          "pc=%08x rd=%02d wen=%d wdata=%08x st=%d saddr=%08x sdata=%08x "
          "strb=%x br=%d bt=%d pred=%d pcorr=%d pcup=%d flush=%d\n",
          (uint32_t)pc, rd & 0x1f, wen & 1, (uint32_t)wdata, is_store & 1,
          (uint32_t)store_addr, (uint32_t)store_data, store_strb & 0xf,
           is_brch & 1, brch_taken & 1, predict_taken & 1,
           predict_correct & 1, pc_update & 1, flush & 1);
}
extern "C" void branch_trace_dpic(int pc, int btb_hit, int pred_taken,
                                   int pred_target, int actual_taken,
                                   int branch_target) {
  if (!branch_trace_en || !branch_trace_fp)
    return;
  fprintf(branch_trace_fp,
          "pc=%08x btb_hit=%d pred=%d pred_target=%08x actual=%d target=%08x\n",
          (uint32_t)pc, btb_hit & 1, pred_taken & 1, (uint32_t)pred_target,
          actual_taken & 1, (uint32_t)branch_target);
}
extern "C" void mergesort_loop_dpic(int s4, int s1, int s0, int s3, int s2) {
  mergesort_loop_samples++;
  if (mergesort_loop_samples == 1000 || mergesort_loop_samples == 10000 ||
      mergesort_loop_samples == 100000 || mergesort_loop_samples == 1000000) {
    uint32_t s4_addr = (uint32_t)s4;
    uint32_t s1_addr = (uint32_t)s1;
    printf("[DEBUG] mergesort loop %lu: s4=0x%08x s4.next=0x%08x s1=0x%08x s1.next=0x%08x s0=%d s3=%d s2=0x%08x\n",
           mergesort_loop_samples, s4_addr, pmem_peek32(s4_addr), s1_addr,
           pmem_peek32(s1_addr), s0, s3, (uint32_t)s2);
  }
}

static void load_image(const char *file) {
  FILE *fp = fopen(file, "rb");
  if (!fp) {
    fprintf(stderr, "Error: cannot open image '%s'\n", file);
    exit(1);
  }
  fseek(fp, 0, SEEK_END);
  long size = ftell(fp);
  fseek(fp, 0, SEEK_SET);
  if (size > MEM_SIZE) {
    fprintf(stderr, "Error: image too large (%ld > %d)\n", size, MEM_SIZE);
    exit(1);
  }
  fread(mem, size, 1, fp);
  fclose(fp);
  printf("[HelloCPU] Loaded image: %s (%ld bytes)\n", file, size);
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  if (argc < 2) {
    fprintf(stderr, "Usage: %s <image.bin> [--wave] [--max-cycles=N]\n",
            argv[0]);
    return 1;
  }

  const char *img = argv[1];
  bool wave_en = false;
  for (int i = 2; i < argc; i++) {
    if (strcmp(argv[i], "--wave") == 0)
      wave_en = true;
    if (strncmp(argv[i], "--max-cycles=", 13) == 0)
      max_cycles = atoll(argv[i] + 13);
    if (strcmp(argv[i], "--mem-trace") == 0)
      mem_trace_en = true;
    if (strncmp(argv[i], "--mem-trace=", 12) == 0) {
      mem_trace_en = true;
      mem_trace_path = argv[i] + 12;
    }
    if (strcmp(argv[i], "--commit-trace") == 0)
      commit_trace_en = true;
    if (strncmp(argv[i], "--commit-trace=", 15) == 0) {
      commit_trace_en = true;
      commit_trace_path = argv[i] + 15;
    }
    if (strcmp(argv[i], "--branch-trace") == 0)
      branch_trace_en = true;
    if (strncmp(argv[i], "--branch-trace=", 15) == 0) {
      branch_trace_en = true;
      branch_trace_path = argv[i] + 15;
    }
  }
  if (mem_trace_en) {
    mem_trace_fp = fopen(mem_trace_path, "w");
    if (!mem_trace_fp) {
      fprintf(stderr, "Error: cannot open %s\n", mem_trace_path);
      return 1;
    }
  }
  if (commit_trace_en) {
    commit_trace_fp = fopen(commit_trace_path, "w");
    if (!commit_trace_fp) {
      fprintf(stderr, "Error: cannot open %s\n", commit_trace_path);
      return 1;
    }
  }
  if (branch_trace_en) {
    branch_trace_fp = fopen(branch_trace_path, "w");
    if (!branch_trace_fp) {
      fprintf(stderr, "Error: cannot open %s\n", branch_trace_path);
      return 1;
    }
  }

  memset(mem, 0, sizeof(mem));
  load_image(img);

  Vsim_top *top = new Vsim_top;
  VerilatedVcdC *tfp = nullptr;
  if (wave_en) {
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("wave.vcd");
  }

  // Reset
  top->reset = 1;
  top->clock = 0;
  for (int i = 0; i < 10; i++) {
    top->clock = !top->clock;
    top->eval();
    if (tfp)
      tfp->dump(cycles++);
  }
  top->reset = 0;

  // Run
  while (!finished && cycles < max_cycles && !Verilated::gotFinish()) {
    top->clock = !top->clock;
    top->eval();
    if (tfp)
      tfp->dump(cycles);
    cycles++;
  }

  if (tfp) {
    tfp->close();
    delete tfp;
  }
  if (mem_trace_fp) {
    fclose(mem_trace_fp);
    mem_trace_fp = nullptr;
  }
  if (commit_trace_fp) {
    fclose(commit_trace_fp);
    commit_trace_fp = nullptr;
  }
  if (branch_trace_fp) {
    fclose(branch_trace_fp);
    branch_trace_fp = nullptr;
  }
  delete top;

  if (finished) {
    if (exit_code == 0) {
      printf("\n\033[1;32m[HelloCPU] PASS\033[0m (cycles: %lu)\n", cycles / 2);
    } else {
      printf(
          "\n\033[1;31m[HelloCPU] FAIL\033[0m (exit code: %d, cycles: %lu)\n",
          exit_code, cycles / 2);
    }
  } else {
    printf("\n\033[1;33m[HelloCPU] TIMEOUT\033[0m (max cycles: %lu)\n",
           max_cycles / 2);
    exit_code = -1;
  }
  print_perf_summary();
  return exit_code;
}
