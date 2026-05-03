#include "Vsim_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>

// 64MB memory starting at 0x30000000
#define MEM_BASE 0x30000000
#define MEM_SIZE (64 * 1024 * 1024)
#define UART_ADDR 0x10000000
#define HALT_ADDR 0x10000004

static uint8_t mem[MEM_SIZE];
static bool finished = false;
static int exit_code = -1;
static uint64_t cycles = 0;
static uint64_t max_cycles = 200000000; // 100M cycle timeout

// ---- performance counters ----
static uint64_t cnt_inst      = 0;
static uint64_t cnt_brch      = 0;
static uint64_t cnt_brch_tkn  = 0;
static uint64_t cnt_jal       = 0;
static uint64_t cnt_load      = 0;
static uint64_t cnt_store     = 0;
static uint64_t cnt_mul       = 0;
static uint64_t cnt_div       = 0;
static uint64_t cnt_alu       = 0;
static uint64_t cnt_csr       = 0;
static uint64_t cnt_sys       = 0;
static uint64_t cnt_fence     = 0;
static uint64_t cnt_stall     = 0;
static uint64_t cnt_icache_hit   = 0;
static uint64_t cnt_icache_miss  = 0;
static uint64_t cnt_ifu_fetch    = 0;
static uint64_t cnt_ifu_done     = 0;
static uint64_t cnt_load_bus     = 0;
static uint64_t cnt_load_done    = 0;
static uint64_t cnt_store_bus    = 0;
static uint64_t cnt_store_done   = 0;
static uint64_t cnt_btb_hit      = 0;
static uint64_t cnt_btb_miss     = 0;
static uint64_t cnt_btb_mispredict = 0;
static uint64_t cnt_ras_hit      = 0;
static uint64_t cnt_ras_miss     = 0;

// ---- performance summary printer ----
static void print_perf_summary() {
    uint64_t total_clk = cycles / 2;
    if (total_clk == 0) total_clk = 1;
    printf("\n");
    printf("┌─────────────────────────────────────────────────────┐\n");
    printf("│            Performance Counter Summary              │\n");
    printf("├─────────────────────────────────────────────────────┤\n");
    printf("│ Total cycles         : %12lu                 │\n", total_clk);
    printf("│ Total instructions   : %12lu (IPC = %.3f)       │\n",
           cnt_inst, (double)cnt_inst / total_clk);
    printf("│ Stall cycles         : %12lu (%.1f%%)            │\n",
           cnt_stall, 100.0 * cnt_stall / total_clk);
    printf("├─────────────────────────────────────────────────────┤\n");
    printf("│ Instruction Mix                                    │\n");
    if (cnt_inst > 0) {
        printf("│   ALU ops           : %10lu (%5.1f%%)            │\n",
               cnt_alu, 100.0 * cnt_alu / cnt_inst);
        printf("│   Branches          : %10lu (%5.1f%%)            │\n",
               cnt_brch, 100.0 * cnt_brch / cnt_inst);
        printf("│     ├─ taken        : %10lu (%5.1f%%)            │\n",
               cnt_brch_tkn, 100.0 * cnt_brch_tkn / (cnt_brch ? cnt_brch : 1));
        printf("│   Jumps (JAL+JALR)  : %10lu (%5.1f%%)            │\n",
               cnt_jal, 100.0 * cnt_jal / cnt_inst);
        printf("│   Loads             : %10lu (%5.1f%%)            │\n",
               cnt_load, 100.0 * cnt_load / cnt_inst);
        printf("│   Stores            : %10lu (%5.1f%%)            │\n",
               cnt_store, 100.0 * cnt_store / cnt_inst);
        printf("│   Multiplies        : %10lu (%5.1f%%)            │\n",
               cnt_mul, 100.0 * cnt_mul / cnt_inst);
        printf("│   Divides           : %10lu (%5.1f%%)            │\n",
               cnt_div, 100.0 * cnt_div / cnt_inst);
        printf("│   CSR accesses      : %10lu (%5.1f%%)            │\n",
               cnt_csr, 100.0 * cnt_csr / cnt_inst);
        printf("│   System (ECALL/MRET/EBREAK): %4lu (%5.1f%%)     │\n",
               cnt_sys, 100.0 * cnt_sys / cnt_inst);
        printf("│   fence.i           : %10lu (%5.1f%%)            │\n",
               cnt_fence, 100.0 * cnt_fence / cnt_inst);
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
    }
    uint64_t ras_total = cnt_ras_hit + cnt_ras_miss;
    if (ras_total > 0) {
        printf("│   RAS hits          : %10lu (%5.1f%%)            │\n",
               cnt_ras_hit, 100.0 * cnt_ras_hit / ras_total);
        printf("│   RAS misses        : %10lu (%5.1f%%)            │\n",
               cnt_ras_miss, 100.0 * cnt_ras_miss / ras_total);
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
        uint8_t *p = mem + offset;
        for (int i = 0; i < 4; i++) {
            if (strb & (1 << i)) {
                p[i] = (data >> (i * 8)) & 0xff;
            }
        }
    }
}

// DPI-C performance counters
extern "C" void inst_cnt_dpic()   { cnt_inst++; }
extern "C" void brch_cnt_dpic()   { cnt_brch++; }
extern "C" void brch_tkn_dpic()   { cnt_brch_tkn++; }
extern "C" void jal_cnt_dpic()    { cnt_jal++; }
extern "C" void load_dpic()       { cnt_load++; }
extern "C" void store_dpic()      { cnt_store++; }
extern "C" void mul_cnt_dpic()    { cnt_mul++; }
extern "C" void div_cnt_dpic()    { cnt_div++; }
extern "C" void alu_cnt_dpic()    { cnt_alu++; }
extern "C" void csr_cnt_dpic()    { cnt_csr++; }
extern "C" void sys_cnt_dpic()    { cnt_sys++; }
extern "C" void fence_cnt_dpic()  { cnt_fence++; }
extern "C" void stall_cnt_dpic()  { cnt_stall++; }
extern "C" void cache_miss()      { cnt_icache_miss++; }
extern "C" void ifu_start()       { cnt_ifu_fetch++; }
extern "C" void ifu_end()         { cnt_ifu_done++; }
extern "C" void load_start()      { cnt_load_bus++; }
extern "C" void load_end()        { cnt_load_done++; }
extern "C" void store_start()     { cnt_store_bus++; }
extern "C" void store_end()       { cnt_store_done++; }

// Legacy DPI-C names (aliases / no-ops — kept for backward compat)
extern "C" void load_cnt_dpic()   { cnt_load_bus++; }
extern "C" void store_cnt_dpic()  { cnt_store_bus++; }
extern "C" void icache_end()      { cnt_icache_hit++; }
extern "C" void btb_hit_dpic()   { cnt_btb_hit++; }
extern "C" void btb_miss_dpic()  { cnt_btb_miss++; }
extern "C" void btb_misp_dpic()  { cnt_btb_mispredict++; }
extern "C" void ras_hit_dpic()   { cnt_ras_hit++; }
extern "C" void ras_miss_dpic()  { cnt_ras_miss++; }

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
        fprintf(stderr, "Usage: %s <image.bin> [--wave] [--max-cycles=N]\n", argv[0]);
        return 1;
    }

    const char *img = argv[1];
    bool wave_en = false;
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "--wave") == 0) wave_en = true;
        if (strncmp(argv[i], "--max-cycles=", 13) == 0)
            max_cycles = atoll(argv[i] + 13);
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
        if (tfp) tfp->dump(cycles++);
    }
    top->reset = 0;

    // Run
    while (!finished && cycles < max_cycles && !Verilated::gotFinish()) {
        top->clock = !top->clock;
        top->eval();
        if (tfp) tfp->dump(cycles);
        cycles++;
    }

    if (tfp) { tfp->close(); delete tfp; }
    delete top;

    if (finished) {
        if (exit_code == 0) {
            printf("\n\033[1;32m[HelloCPU] PASS\033[0m (cycles: %lu)\n", cycles / 2);
        } else {
            printf("\n\033[1;31m[HelloCPU] FAIL\033[0m (exit code: %d, cycles: %lu)\n", exit_code, cycles / 2);
        }
    } else {
        printf("\n\033[1;33m[HelloCPU] TIMEOUT\033[0m (max cycles: %lu)\n", max_cycles / 2);
        exit_code = -1;
    }
    print_perf_summary();
    return exit_code;
}
