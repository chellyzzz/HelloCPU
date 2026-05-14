module hcpu_decode_pair_policy (
    input                               i_pair_valid,
    input                               i_pair_candidate_alu_branch,
    input                               i_pair_has_raw,
    input                               i_pair_has_waw,
    input                               i_pair_has_dual_writeback,
    input                               i_pair_has_exclusive_backend,
    input                               i_pair_has_redirect_control,
    input                               i_pair_order_alu_then_branch,
    input                               i_pair_order_branch_then_alu,
    input                               i_downstream_ready,
    input                               i_cop_pipeline_active,
    input                               i_frontend_flush,

    output                              o_pair_visible,
    output                              o_allow_second,
    output                              o_select_slot1_youngest,
    output                              o_select_slot1_branch,
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

wire pair_clean = i_pair_candidate_alu_branch && !i_pair_has_raw && !i_pair_has_waw &&
                  !i_pair_has_dual_writeback && !i_pair_has_exclusive_backend &&
                  !i_pair_has_redirect_control;
wire pair_direction_ok = i_pair_order_alu_then_branch && !i_pair_order_branch_then_alu;
wire slot1_visible = i_pair_valid && pair_clean && pair_direction_ok;

assign o_pair_visible = i_pair_valid;
assign o_allow_second = slot1_visible && i_downstream_ready &&
                        !i_cop_pipeline_active && !i_frontend_flush;
assign o_select_slot1_youngest = slot1_visible;
assign o_select_slot1_branch = slot1_visible;
assign o_block_raw = i_pair_valid && i_pair_has_raw;
assign o_block_waw = i_pair_valid && i_pair_has_waw;
assign o_block_dual_writeback = i_pair_valid && i_pair_has_dual_writeback;
assign o_block_exclusive_backend = i_pair_valid && i_pair_has_exclusive_backend;
assign o_block_redirect_control = i_pair_valid && i_pair_has_redirect_control;
assign o_block_older_branch_first = i_pair_valid && i_pair_order_branch_then_alu;
assign o_block_downstream_busy = i_pair_valid && !i_downstream_ready;
assign o_block_cop_pipeline = i_pair_valid && i_cop_pipeline_active;
assign o_block_frontend_flush = i_pair_valid && i_frontend_flush;

endmodule
