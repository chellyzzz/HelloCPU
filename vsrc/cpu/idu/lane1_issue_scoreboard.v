module hcpu_lane1_issue_scoreboard (
    input                               i_pair_valid,
    input                               i_slot0_valid,
    input                               i_slot1_valid,
    input       [4:0]                   i_slot0_rd,
    input       [4:0]                   i_slot1_rd,
    input       [4:0]                   i_slot1_rs1_addr,
    input       [4:0]                   i_slot1_rs2_addr,
    input                               i_slot0_wen,
    input                               i_slot1_wen,
    input                               i_slot0_csr_wen,
    input                               i_slot1_csr_wen,
    input                               i_slot0_brch,
    input                               i_slot0_jal,
    input                               i_slot0_jalr,
    input                               i_slot0_load,
    input                               i_slot0_store,
    input                               i_slot0_muldiv,
    input                               i_slot0_is_cop_insn,
    input                               i_slot0_ecall,
    input                               i_slot0_mret,
    input                               i_slot0_ebreak,
    input                               i_slot0_fence_i,
    input                               i_slot1_brch,
    input                               i_slot1_jal,
    input                               i_slot1_jalr,
    input                               i_slot1_load,
    input                               i_slot1_store,
    input                               i_slot1_muldiv,
    input                               i_slot1_is_cop_insn,
    input                               i_slot1_ecall,
    input                               i_slot1_mret,
    input                               i_slot1_ebreak,
    input                               i_slot1_fence_i,
    input                               i_downstream_ready,
    input                               i_cop_pipeline_active,
    input                               i_frontend_flush,

    output                              o_pair_candidate_alu_branch,
    output                              o_pair_order_alu_then_branch,
    output                              o_pair_order_branch_then_alu,
    output                              o_allow_second,
    output                              o_block_raw,
    output                              o_block_waw,
    output                              o_block_dual_writeback,
    output                              o_block_exclusive_backend,
    output                              o_block_redirect_control,
    output                              o_block_older_branch_first,
    output                              o_block_downstream_busy,
    output                              o_block_cop_pipeline,
    output                              o_block_frontend_flush
);

wire slot0_simple_alu = i_slot0_valid && !i_slot0_brch && !i_slot0_jal && !i_slot0_jalr &&
                        !i_slot0_load && !i_slot0_store && !i_slot0_muldiv && !i_slot0_is_cop_insn &&
                        !i_slot0_ecall && !i_slot0_mret && !i_slot0_ebreak && !i_slot0_fence_i && !i_slot0_csr_wen;
wire slot1_simple_alu = i_slot1_valid && !i_slot1_brch && !i_slot1_jal && !i_slot1_jalr &&
                        !i_slot1_load && !i_slot1_store && !i_slot1_muldiv && !i_slot1_is_cop_insn &&
                        !i_slot1_ecall && !i_slot1_mret && !i_slot1_ebreak && !i_slot1_fence_i && !i_slot1_csr_wen;
wire slot0_simple_branch = i_slot0_valid && i_slot0_brch && !i_slot0_wen && !i_slot0_jal && !i_slot0_jalr &&
                           !i_slot0_load && !i_slot0_store && !i_slot0_muldiv && !i_slot0_is_cop_insn &&
                           !i_slot0_ecall && !i_slot0_mret && !i_slot0_ebreak && !i_slot0_fence_i;
wire slot1_simple_branch = i_slot1_valid && i_slot1_brch && !i_slot1_wen && !i_slot1_jal && !i_slot1_jalr &&
                           !i_slot1_load && !i_slot1_store && !i_slot1_muldiv && !i_slot1_is_cop_insn &&
                           !i_slot1_ecall && !i_slot1_mret && !i_slot1_ebreak && !i_slot1_fence_i;

wire pair_shape_candidate = (slot0_simple_alu && slot1_simple_branch) ||
                            (slot0_simple_branch && slot1_simple_alu);

assign o_pair_order_alu_then_branch = i_pair_valid && slot0_simple_alu && slot1_simple_branch;
assign o_pair_order_branch_then_alu = i_pair_valid && slot0_simple_branch && slot1_simple_alu;
assign o_block_raw = i_pair_valid && i_slot0_wen && (i_slot0_rd != 5'b0) &&
                     ((i_slot1_rs1_addr == i_slot0_rd) || (i_slot1_rs2_addr == i_slot0_rd));
assign o_block_waw = i_pair_valid && i_slot0_wen && i_slot1_wen && (i_slot0_rd != 5'b0) &&
                     (i_slot1_rd == i_slot0_rd);
assign o_block_dual_writeback = i_pair_valid && i_slot0_wen && i_slot1_wen;
assign o_block_exclusive_backend = i_pair_valid && (i_slot0_load || i_slot0_store || i_slot0_muldiv ||
                                                    i_slot0_is_cop_insn || i_slot1_load || i_slot1_store ||
                                                    i_slot1_muldiv || i_slot1_is_cop_insn);
assign o_block_redirect_control = i_pair_valid && (i_slot0_jal || i_slot0_jalr || i_slot0_ecall || i_slot0_mret ||
                                                   i_slot0_ebreak || i_slot0_fence_i || i_slot1_jal || i_slot1_jalr ||
                                                   i_slot1_ecall || i_slot1_mret || i_slot1_ebreak || i_slot1_fence_i);
assign o_block_older_branch_first = o_pair_order_branch_then_alu;
assign o_pair_candidate_alu_branch = i_pair_valid && pair_shape_candidate && !o_block_raw && !o_block_waw &&
                                     !o_block_dual_writeback && !o_block_exclusive_backend &&
                                     !o_block_redirect_control;
assign o_block_downstream_busy = i_pair_valid && !i_downstream_ready;
assign o_block_cop_pipeline = i_pair_valid && i_cop_pipeline_active;
assign o_block_frontend_flush = i_pair_valid && i_frontend_flush;

assign o_allow_second = o_pair_candidate_alu_branch && !o_block_older_branch_first &&
                        !o_block_downstream_busy && !o_block_cop_pipeline && !o_block_frontend_flush;

endmodule
