#include "Vhcpu_ifu_fetch_queue.h"
#include "verilated.h"

#include <cstdio>

static vluint64_t main_time = 0;

static void tick(Vhcpu_ifu_fetch_queue *top) {
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

static int expect_predecode(Vhcpu_ifu_fetch_queue *top,
                            uint32_t rd,
                            uint32_t rs1,
                            uint32_t rs2,
                            bool wen,
                            bool csr_wen,
                            bool load,
                            bool store,
                            bool brch,
                            bool jal,
                            bool jalr,
                            bool fence_i,
                            bool muldiv,
                            bool is_cop,
                            bool ecall,
                            bool mret,
                            bool ebreak,
                            const char *context) {
  int fail = 0;
  fail |= expect(top->o_predecode_rd == rd, context);
  fail |= expect(top->o_predecode_rs1_addr == rs1, context);
  fail |= expect(top->o_predecode_rs2_addr == rs2, context);
  fail |= expect(top->o_predecode_wen == wen, context);
  fail |= expect(top->o_predecode_csr_wen == csr_wen, context);
  fail |= expect(top->o_predecode_load == load, context);
  fail |= expect(top->o_predecode_store == store, context);
  fail |= expect(top->o_predecode_brch == brch, context);
  fail |= expect(top->o_predecode_jal == jal, context);
  fail |= expect(top->o_predecode_jalr == jalr, context);
  fail |= expect(top->o_predecode_fence_i == fence_i, context);
  fail |= expect(top->o_predecode_muldiv == muldiv, context);
  fail |= expect(top->o_predecode_is_cop_insn == is_cop, context);
  fail |= expect(top->o_predecode_ecall == ecall, context);
  fail |= expect(top->o_predecode_mret == mret, context);
  fail |= expect(top->o_predecode_ebreak == ebreak, context);
  return fail;
}

static int expect_pair_screen(Vhcpu_ifu_fetch_queue *top,
                              bool valid,
                              bool candidate_alu_branch,
                              bool has_raw,
                              bool has_waw,
                              bool has_dual_writeback,
                              bool has_exclusive_backend,
                              bool has_redirect_control,
                              bool order_alu_then_branch,
                              bool order_branch_then_alu,
                              const char *context) {
  int fail = 0;
  fail |= expect(top->o_pair_valid == valid, context);
  fail |= expect(top->o_pair_candidate_alu_branch == candidate_alu_branch, context);
  fail |= expect(top->o_pair_has_raw == has_raw, context);
  fail |= expect(top->o_pair_has_waw == has_waw, context);
  fail |= expect(top->o_pair_has_dual_writeback == has_dual_writeback, context);
  fail |= expect(top->o_pair_has_exclusive_backend == has_exclusive_backend, context);
  fail |= expect(top->o_pair_has_redirect_control == has_redirect_control, context);
  fail |= expect(top->o_pair_order_alu_then_branch == order_alu_then_branch, context);
  fail |= expect(top->o_pair_order_branch_then_alu == order_branch_then_alu, context);
  return fail;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vhcpu_ifu_fetch_queue *top = new Vhcpu_ifu_fetch_queue;
  int fail = 0;

  constexpr uint32_t pc_a = 0x30000010u;
  constexpr uint32_t ins_a = 0x00130293u;  // addi x5, x6, 1
  constexpr uint32_t target_a = 0x30000040u >> 2;

  constexpr uint32_t pc_b = 0x30000014u;
  constexpr uint32_t ins_b = 0x00208463u;  // beq x1, x2, 8
  constexpr uint32_t target_b = 0x30000080u >> 2;

  constexpr uint32_t pc_c = 0x30000018u;
  constexpr uint32_t ins_c = 0x00c22383u;  // lw x7, 12(x4)
  constexpr uint32_t target_c = 0x300000c0u >> 2;

  constexpr uint32_t pc_d = 0x3000001cu;
  constexpr uint32_t ins_d = 0x0000100fu;  // fence.i
  constexpr uint32_t target_d = 0x30000100u >> 2;

  constexpr uint32_t pc_e = 0x30000020u;
  constexpr uint32_t ins_e = 0x00100093u;  // addi x1, x0, 1
  constexpr uint32_t target_e = 0x30000140u >> 2;

  constexpr uint32_t pc_f = 0x30000024u;
  constexpr uint32_t ins_f = 0x00108113u;  // addi x2, x1, 1
  constexpr uint32_t target_f = 0x30000180u >> 2;

  constexpr uint32_t pc_g = 0x30000028u;
  constexpr uint32_t ins_g = 0x00200113u;  // addi x2, x0, 2
  constexpr uint32_t target_g = 0x300001c0u >> 2;

  top->reset = 1;
  top->flush = 0;
  top->i_enq_valid = 0;
  top->i_deq_ready = 0;
  top->i_pc = 0;
  top->i_ins = 0;
  top->i_predict_taken = 0;
  top->i_predict_target = 0;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->reset = 0;
  top->eval();

  fail |= expect(top->o_deq_valid == 0, "reset clears queue valid");
  fail |= expect(top->o_enq_ready == 1, "reset leaves queue ready for enqueue");

  top->i_enq_valid = 1;
  top->i_deq_ready = 0;
  top->i_pc = pc_a;
  top->i_ins = ins_a;
  top->i_predict_taken = 1;
  top->i_predict_target = target_a;
  top->i_predict_btb_hit = 1;
  tick(top);

  fail |= expect(top->o_deq_valid == 1, "first enqueue creates a visible entry");
  fail |= expect(top->o_pc == pc_a, "first enqueue captures pc");
  fail |= expect(top->o_ins == ins_a, "first enqueue captures instruction");
  fail |= expect(top->o_predict_taken == 1, "first enqueue captures predict_taken");
  fail |= expect(top->o_predict_target == target_a, "first enqueue captures predict_target");
  fail |= expect(top->o_predict_btb_hit == 1, "first enqueue captures predict_btb_hit");
  fail |= expect_predecode(top, 5, 6, 0, true, false, false, false, false, false,
                           false, false, false, false, false, false, false,
                           "addi predecode captured");

  top->i_pc = pc_b;
  top->i_ins = ins_b;
  top->i_predict_taken = 0;
  top->i_predict_target = target_b;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 1, "second enqueue keeps queue non-empty");
  fail |= expect(top->o_pc == pc_a, "oldest entry remains visible while second entry queues");
  fail |= expect(top->o_ins == ins_a, "oldest instruction remains visible while second entry queues");
  fail |= expect(top->o_enq_ready == 0, "queue reports full under backpressure after two entries");
  fail |= expect_predecode(top, 5, 6, 0, true, false, false, false, false, false,
                           false, false, false, false, false, false, false,
                           "stall preserves first predecode entry");
  fail |= expect_pair_screen(top, true, true, false, false, false, false, false, true, false,
                             "addi plus branch is visible as the first pairing candidate");

  top->i_pc = pc_c;
  top->i_ins = ins_c;
  top->i_predict_taken = 1;
  top->i_predict_target = target_c;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->eval();

  fail |= expect(top->o_pc == pc_a, "full queue rejects overwrite without dequeue");
  fail |= expect(top->o_ins == ins_a, "full queue keeps oldest instruction without dequeue");

  top->i_pc = pc_c;
  top->i_ins = ins_c;
  top->i_predict_taken = 1;
  top->i_predict_target = target_c;
  top->i_predict_btb_hit = 0;
  top->i_deq_ready = 1;
  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 1, "simultaneous dequeue and enqueue keeps queue non-empty");
  fail |= expect(top->o_pc == pc_b, "second entry becomes visible after replacing oldest entry");
  fail |= expect(top->o_ins == ins_b, "second entry instruction becomes visible after replace");
  fail |= expect(top->o_predict_taken == 0, "second entry predict_taken preserved after replace");
  fail |= expect(top->o_predict_target == target_b, "second entry predict_target preserved after replace");
  fail |= expect(top->o_predict_btb_hit == 0, "second entry predict_btb_hit preserved after replace");
  fail |= expect_predecode(top, 8, 1, 2, false, false, false, false, true, false,
                           false, false, false, false, false, false, false,
                           "branch predecode preserved after replace");
  fail |= expect_pair_screen(top, true, false, false, false, false, true, false, false, false,
                             "branch plus load is blocked by exclusive backend use");

  top->i_enq_valid = 0;
  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 1, "third entry remains queued after draining second entry");
  fail |= expect(top->o_pc == pc_c, "third entry drains last");
  fail |= expect(top->o_ins == ins_c, "third instruction drains last");
  fail |= expect(top->o_predict_taken == 1, "third predict_taken drains last");
  fail |= expect(top->o_predict_target == target_c, "third predict_target drains last");
  fail |= expect(top->o_predict_btb_hit == 0, "third predict_btb_hit drains last");
  fail |= expect_predecode(top, 7, 4, 0, true, false, true, false, false, false,
                           false, false, false, false, false, false, false,
                           "load predecode drains last");

  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 0, "queue empties after final dequeue");
  fail |= expect(top->o_enq_ready == 1, "queue is ready again after draining");
  fail |= expect_pair_screen(top, false, false, false, false, false, false, false, false, false,
                             "empty queue has no pair screen result");

  top->i_deq_ready = 0;
  top->i_enq_valid = 1;
  top->i_pc = pc_a;
  top->i_ins = ins_a;
  top->i_predict_taken = 1;
  top->i_predict_target = target_a;
  top->i_predict_btb_hit = 1;
  tick(top);

  top->i_pc = pc_b;
  top->i_ins = ins_b;
  top->i_predict_taken = 0;
  top->i_predict_target = target_b;
  top->i_predict_btb_hit = 0;
  tick(top);

  top->flush = 1;
  top->i_enq_valid = 0;
  tick(top);
  top->flush = 0;
  top->eval();

  fail |= expect(top->o_deq_valid == 0, "flush drops all queued entries");
  fail |= expect(top->o_enq_ready == 1, "flush reopens enqueue path");

  top->i_enq_valid = 1;
  top->i_deq_ready = 1;
  top->i_pc = pc_a;
  top->i_ins = ins_a;
  top->i_predict_taken = 1;
  top->i_predict_target = target_a;
  top->i_predict_btb_hit = 1;
  tick(top);

  top->i_pc = pc_b;
  top->i_ins = ins_b;
  top->i_predict_taken = 0;
  top->i_predict_target = target_b;
  top->i_predict_btb_hit = 0;
  tick(top);

  top->flush = 1;
  top->i_pc = pc_c;
  top->i_ins = ins_c;
  top->i_predict_taken = 1;
  top->i_predict_target = target_c;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->flush = 0;
  top->eval();

  fail |= expect(top->o_deq_valid == 0, "flush dominates concurrent dequeue and enqueue");
  fail |= expect(top->o_enq_ready == 1, "flush leaves queue ready after concurrent activity");

  top->i_enq_valid = 1;
  top->i_deq_ready = 0;
  top->i_pc = pc_d;
  top->i_ins = ins_d;
  top->i_predict_taken = 0;
  top->i_predict_target = target_d;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->eval();

  fail |= expect(top->o_deq_valid == 1, "queue accepts new entry after flush-dominant cycle");
  fail |= expect(top->o_ins == ins_d, "fence.i instruction becomes visible after fresh enqueue");
  fail |= expect_predecode(top, 0, 0, 0, false, false, false, false, false, false,
                           false, true, false, false, false, false, false,
                           "fence.i predecode captured");

  top->i_pc = pc_e;
  top->i_ins = ins_e;
  top->i_predict_taken = 0;
  top->i_predict_target = target_e;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->eval();

  fail |= expect_pair_screen(top, true, false, false, false, false, false, true, false, false,
                             "fence.i plus addi is pairing-hostile because of redirect control");

  top->i_deq_ready = 1;
  top->i_pc = pc_f;
  top->i_ins = ins_f;
  top->i_predict_taken = 0;
  top->i_predict_target = target_f;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->eval();

  fail |= expect_pair_screen(top, true, false, true, false, true, false, false, false, false,
                             "back-to-back addi pair reports raw and dual-writeback pressure");

  top->i_pc = pc_g;
  top->i_ins = ins_g;
  top->i_predict_taken = 0;
  top->i_predict_target = target_g;
  top->i_predict_btb_hit = 0;
  tick(top);
  top->eval();

  fail |= expect_pair_screen(top, true, false, false, true, true, false, false, false, false,
                             "same-rd addi pair reports WAW and dual-writeback pressure");

  delete top;
  if (fail) {
    return 1;
  }

  std::printf("PASS: IFU fetch queue preserves FIFO order, backpressure, replace-on-drain, and flush dominance\n");
  return 0;
}
