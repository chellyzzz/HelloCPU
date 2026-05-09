module hcpu_idu_cop_regs (
    input               clock,
    input               reset,
    input               i_issue_valid,
    input               i_kill,
    input               i_dequeue,
    input               i_backend_busy,
    input      [31:0]   i_pc,
    input      [31:0]   i_ins,
    input      [31:0]   i_src1,
    input      [31:0]   i_src2,
    input      [4:0]    i_rd,
    input               i_wen,
    output              o_inflight,
    output              o_issue_ready,
    output              o_issue_fire,
    output     [31:0]   o_pc,
    output     [31:0]   o_ins,
    output     [31:0]   o_active_src1,
    output     [31:0]   o_active_src2,
    output     [4:0]    o_rd,
    output              o_wen
);

reg         entry_valid;
reg [31:0]  entry_pc;
reg [31:0]  entry_ins;
reg [31:0]  entry_src1;
reg [31:0]  entry_src2;
reg [4:0]   entry_rd;
reg         entry_wen;

assign o_inflight = entry_valid;
assign o_pc = entry_pc;
assign o_ins = o_issue_fire ? i_ins :
               entry_valid  ? entry_ins : i_ins;
assign o_active_src1 = o_issue_fire ? i_src1 :
                       entry_valid  ? entry_src1 : i_src1;
assign o_active_src2 = o_issue_fire ? i_src2 :
                       entry_valid  ? entry_src2 : i_src2;
assign o_rd = entry_rd;
assign o_wen = entry_wen;
assign o_issue_ready = !o_inflight && !i_backend_busy;
assign o_issue_fire = i_issue_valid && o_issue_ready;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        entry_valid <= 1'b0;
        entry_pc <= 32'b0;
        entry_ins <= 32'b0;
        entry_src1 <= 32'b0;
        entry_src2 <= 32'b0;
        entry_rd <= 5'b0;
        entry_wen <= 1'b0;
    end else if (i_kill) begin
        entry_valid <= 1'b0;
        entry_pc <= 32'b0;
        entry_ins <= 32'b0;
        entry_src1 <= 32'b0;
        entry_src2 <= 32'b0;
        entry_rd <= 5'b0;
        entry_wen <= 1'b0;
    end else if (i_dequeue) begin
        entry_valid <= o_issue_fire;
        entry_pc <= o_issue_fire ? i_pc : 32'b0;
        entry_ins <= o_issue_fire ? i_ins : 32'b0;
        entry_src1 <= o_issue_fire ? i_src1 : 32'b0;
        entry_src2 <= o_issue_fire ? i_src2 : 32'b0;
        entry_rd <= o_issue_fire ? i_rd : 5'b0;
        entry_wen <= o_issue_fire ? i_wen : 1'b0;
    end else if (o_issue_fire) begin
        entry_valid <= 1'b1;
        entry_pc <= i_pc;
        entry_ins <= i_ins;
        entry_src1 <= i_src1;
        entry_src2 <= i_src2;
        entry_rd <= i_rd;
        entry_wen <= i_wen;
    end
end

endmodule
