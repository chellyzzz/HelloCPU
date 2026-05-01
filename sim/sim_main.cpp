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
static uint64_t max_cycles = 10000000; // 10M cycles timeout

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
        // Apply byte strobe
        uint8_t *p = mem + offset;
        for (int i = 0; i < 4; i++) {
            if (strb & (1 << i)) {
                p[i] = (data >> (i * 8)) & 0xff;
            }
        }
    }
}

// DPI-C stubs for performance counters in CPU
extern "C" void csr_cnt_dpic() {}
extern "C" void brch_cnt_dpic() {}
extern "C" void jal_cnt_dpic() {}
extern "C" void load_cnt_dpic() {}
extern "C" void store_cnt_dpic() {}
extern "C" void inst_cnt_dpic() {}
extern "C" void ifu_start() {}
extern "C" void ifu_end() {}
extern "C" void icache_end() {}
extern "C" void cache_miss() {}
extern "C" void load_start() {}
extern "C" void load_end() {}
extern "C" void store_start() {}
extern "C" void store_end() {}

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
    return exit_code;
}
