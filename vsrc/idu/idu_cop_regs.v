module hcpu_idu_cop_regs (
    input               clock,
    input               reset,
    input               i_capture,
    input               i_clear,
    input               i_backend_busy,
    input      [31:0]   i_pc,
    input      [31:0]   i_src1,
    input      [31:0]   i_src2,
    input      [4:0]    i_rd,
    input               i_wen,
    output reg          o_inflight,
    output              o_issue_ready,
    output reg [31:0]   o_pc,
    output     [31:0]   o_active_src1,
    output     [31:0]   o_active_src2,
    output reg [4:0]    o_rd,
    output reg          o_wen
);

reg [31:0] src1;
reg [31:0] src2;

assign o_active_src1 = o_inflight ? src1 : i_src1;
assign o_active_src2 = o_inflight ? src2 : i_src2;
assign o_issue_ready = !o_inflight && !i_backend_busy;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        o_inflight <= 1'b0;
        o_pc <= 32'b0;
        src1 <= 32'b0;
        src2 <= 32'b0;
        o_rd <= 5'b0;
        o_wen <= 1'b0;
    end else if (i_clear) begin
        o_inflight <= 1'b0;
        o_pc <= 32'b0;
        src1 <= 32'b0;
        src2 <= 32'b0;
        o_rd <= 5'b0;
        o_wen <= 1'b0;
    end else if (i_capture) begin
        o_inflight <= 1'b1;
        o_pc <= i_pc;
        src1 <= i_src1;
        src2 <= i_src2;
        o_rd <= i_rd;
        o_wen <= i_wen;
    end
end

endmodule
