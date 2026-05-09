module hcpu_cop_backend(
    input               clock,
    input               reset,
    input               i_pre_valid,
    input               i_post_ready,
    input               i_flush,
    input      [31:0]   i_src1,
    input      [31:0]   i_src2,
    input      [31:0]   i_ins,
    output              o_pre_ready,
    output              o_post_valid,
    output              o_busy,
    output     [31:0]   o_res
);

wire        cop_done;
wire [31:0] cop_res;
reg         cop_busy;
reg         resp_valid;
reg [31:0]  resp_res;

hcpu_dummy_coprocessor u_dummy_coprocessor(
    .clock      (clock),
    .reset      (reset),
    .i_flush    (i_flush),
    .i_valid    (i_pre_valid),
    .i_src1     (i_src1),
    .i_src2     (i_src2),
    .i_ins      (i_ins),
    .o_res      (cop_res),
    .o_done     (cop_done)
);

assign o_pre_ready = !cop_busy && !resp_valid;
assign o_post_valid = resp_valid;
assign o_busy = cop_busy || resp_valid;
assign o_res = resp_res;

always @(posedge clock or posedge reset) begin
    if (reset || i_flush) begin
        cop_busy <= 1'b0;
        resp_valid <= 1'b0;
        resp_res <= 32'b0;
    end else begin
        if (i_pre_valid && !cop_busy && !resp_valid) begin
            cop_busy <= 1'b1;
        end

        if (cop_done) begin
            cop_busy <= 1'b0;
            resp_valid <= 1'b1;
            resp_res <= cop_res;
        end

        if (resp_valid && i_post_ready) begin
            resp_valid <= 1'b0;
        end
    end
end

endmodule
