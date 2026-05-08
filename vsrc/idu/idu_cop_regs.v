module hcpu_idu_cop_regs (
    input               clock,
    input               reset,
    input               i_pre_valid,
    input               i_post_ready,
    input               i_consume,
    output              o_pre_ready,
    output              o_post_valid,
    input      [31:0]   i_pc,
    input      [31:0]   i_src1,
    input      [31:0]   i_src2,
    input      [4:0]    i_rd,
    input               i_wen,
    output reg [31:0]   o_pc,
    output reg [31:0]   o_src1,
    output reg [31:0]   o_src2,
    output reg [4:0]    o_rd,
    output reg          o_wen
);

reg post_valid;

assign o_post_valid = post_valid;
assign o_pre_ready = ~post_valid || i_post_ready;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        post_valid <= 1'b0;
    end else if (i_consume) begin
        post_valid <= 1'b0;
    end else if (o_pre_ready) begin
        post_valid <= i_pre_valid;
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        o_pc   <= 32'b0;
        o_src1 <= 32'b0;
        o_src2 <= 32'b0;
        o_rd   <= 5'b0;
        o_wen  <= 1'b0;
    end else if (i_consume) begin
        o_pc   <= 32'b0;
        o_src1 <= 32'b0;
        o_src2 <= 32'b0;
        o_rd   <= 5'b0;
        o_wen  <= 1'b0;
    end else if (o_pre_ready && i_pre_valid) begin
        o_pc   <= i_pc;
        o_src1 <= i_src1;
        o_src2 <= i_src2;
        o_rd   <= i_rd;
        o_wen  <= i_wen;
    end else if (o_pre_ready && ~i_pre_valid) begin
        o_pc   <= 32'b0;
        o_src1 <= 32'b0;
        o_src2 <= 32'b0;
        o_rd   <= 5'b0;
        o_wen  <= 1'b0;
    end
end

endmodule
