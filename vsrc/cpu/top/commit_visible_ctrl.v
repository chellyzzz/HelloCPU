module hcpu_commit_visible_ctrl (
    input         clock,
    input         reset,
    input         i_scalar_exu_mispredict_flush,
    input         i_idu2exu_brch,
    input         i_idu2exu_jal,
    input         i_idu2exu_jalr,
    input         i_commit_visible,
    input         i_exu2wbu_ecall,
    input         i_exu2wbu_mret,
    input         i_pc_update_en,
    input         i_exu_mispredict_flush_r,
    output        o_wbu_pc_update_fire,
    output        o_redirect_fire,
    output        o_redirect_complete,
    output reg    o_redirect_recovery,
    output reg [31:0] o_redirect_gap_cnt,
    output reg    o_redirect_cause_brch,
    output reg    o_redirect_cause_jal,
    output reg    o_redirect_cause_jalr
);

assign o_wbu_pc_update_fire = i_commit_visible && (i_exu2wbu_ecall || i_exu2wbu_mret);
assign o_redirect_fire = i_exu_mispredict_flush_r || i_pc_update_en;
assign o_redirect_complete = o_redirect_recovery && i_commit_visible && !o_redirect_fire;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        o_redirect_recovery   <= 1'b0;
        o_redirect_gap_cnt    <= 32'd0;
        o_redirect_cause_brch <= 1'b0;
        o_redirect_cause_jal  <= 1'b0;
        o_redirect_cause_jalr <= 1'b0;
    end else begin
        if (i_scalar_exu_mispredict_flush) begin
            o_redirect_cause_brch <= i_idu2exu_brch;
            o_redirect_cause_jal  <= i_idu2exu_jal;
            o_redirect_cause_jalr <= i_idu2exu_jalr;
        end else if (o_wbu_pc_update_fire) begin
            o_redirect_cause_brch <= 1'b0;
            o_redirect_cause_jal  <= 1'b0;
            o_redirect_cause_jalr <= 1'b0;
        end

        if (o_redirect_fire) begin
            o_redirect_recovery <= 1'b1;
            o_redirect_gap_cnt  <= 32'd0;
        end else if (o_redirect_complete) begin
            o_redirect_recovery <= 1'b0;
        end else if (o_redirect_recovery) begin
            o_redirect_gap_cnt <= o_redirect_gap_cnt + 32'd1;
        end
    end
end

endmodule
