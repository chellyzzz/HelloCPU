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

struct FlushCoverage {
  uint64_t redirect_flush_events = 0;
  uint64_t redirect_flush_with_nonempty_queue = 0;
  uint64_t redirect_flush_with_fetch_ready = 0;
};

enum class FlushMode {
  ExuRedirect,
  PcUpdate,
};

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  if (argc < 2) {
    std::fprintf(stderr,
                 "Usage: %s <image.bin> [--max-cycles=N]\n",
                 argv[0]);
    return 1;
  }

  FlushMode mode = FlushMode::ExuRedirect;

  for (int i = 2; i < argc; ++i) {
    if (std::strncmp(argv[i], "--max-cycles=", 13) == 0) {
      max_cycles = std::strtoull(argv[i] + 13, nullptr, 10);
    } else if (std::strcmp(argv[i], "--pc-update") == 0) {
      mode = FlushMode::PcUpdate;
    }
  }

  load_image(argv[1]);

  Vsim_top *top = new Vsim_top;
  Vsim_top___024root *root = top->rootp;
  int fail = 0;
  FlushCoverage coverage;

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
    const bool pre_redirect_flush =
        root->sim_top__DOT__cpu__DOT__frontend_flush &&
        ((mode == FlushMode::ExuRedirect)
             ? static_cast<bool>(root->sim_top__DOT__cpu__DOT__exu_mispredict_flush)
             : static_cast<bool>(root->sim_top__DOT__cpu__DOT__pc_update_en));
    const bool pre_fetch_would_enqueue =
        root->sim_top__DOT__cpu__DOT__icache_hit &&
        root->sim_top__DOT__cpu__DOT__ifu_fetch_ready;
    const uint8_t pre_count = root->sim_top__DOT__cpu__DOT__ifu_fetch_queue__DOT__count;

    top->clock = 1;
    top->eval();
    main_time++;

    if (!top->reset && pre_redirect_flush) {
      coverage.redirect_flush_events++;
      if (pre_count != 0) {
        coverage.redirect_flush_with_nonempty_queue++;
      }
      if (pre_fetch_would_enqueue) {
        coverage.redirect_flush_with_fetch_ready++;
      }

      fail |= expect(root->sim_top__DOT__cpu__DOT__ifu_fetch_queue__DOT__count == 0,
                     "redirect flush clears fetch queue count");
      fail |= expect(root->sim_top__DOT__cpu__DOT__ifu_fetch_queue__DOT__valid_q[0] == 0,
                     "redirect flush clears fetch queue entry 0");
      fail |= expect(root->sim_top__DOT__cpu__DOT__ifu_fetch_queue__DOT__valid_q[1] == 0,
                     "redirect flush clears fetch queue entry 1");
      fail |= expect(root->sim_top__DOT__cpu__DOT__ifu_fetch_queue__DOT__head == 0,
                     "redirect flush resets fetch queue head");
      fail |= expect(root->sim_top__DOT__cpu__DOT__ifu_fetch_queue__DOT__tail == 0,
                     "redirect flush resets fetch queue tail");
    }

    top->clock = 0;
    top->eval();
    main_time++;

    if (!top->reset && pre_redirect_flush) {
      fail |= expect(root->sim_top__DOT__cpu__DOT__ifu_fetch_queue__DOT__count == 0,
                     "redirect flush does not leave a stale queued entry one cycle later");
    }

    if (fail) {
      break;
    }
  }

  delete top;

  fail |= expect(finished, "program completed before timeout");
  fail |= expect(exit_code == 0, "program exited successfully");
  fail |= expect(coverage.redirect_flush_events > 0,
                 "observed at least one top-level redirect flush event");
  fail |= expect(coverage.redirect_flush_with_nonempty_queue > 0,
                 "observed redirect flush while fetch queue was non-empty");

  if (fail) {
    return 1;
  }

  std::printf(
      "PASS: top-level %s flush clears fetch queue (redirects=%llu, nonempty=%llu, fetch-ready=%llu)\n",
      mode == FlushMode::ExuRedirect ? "redirect" : "pc_update",
      static_cast<unsigned long long>(coverage.redirect_flush_events),
      static_cast<unsigned long long>(coverage.redirect_flush_with_nonempty_queue),
      static_cast<unsigned long long>(coverage.redirect_flush_with_fetch_ready));
  return 0;
}
