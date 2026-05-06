module hcpu_dummy_coprocessor(
    input               clock,
    input               reset,
    input               i_valid,
    input      [31:0]   i_src1,
    input      [31:0]   i_src2,
    output reg [31:0]   o_res,
    output reg          o_done
);

reg         busy;
reg [1:0]   countdown;
reg [31:0]  latched_res;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        busy        <= 1'b0;
        countdown   <= 2'b0;
        latched_res <= 32'b0;
        o_res       <= 32'b0;
        o_done      <= 1'b0;
    end else begin
        o_done <= 1'b0;

        if (i_valid && !busy) begin
            busy        <= 1'b1;
            countdown   <= 2'd2;
            latched_res <= i_src1 + i_src2;
        end else if (busy) begin
            if (countdown == 2'd1) begin
                busy      <= 1'b0;
                countdown <= 2'b0;
                o_res     <= latched_res;
                o_done    <= 1'b1;
            end else begin
                countdown <= countdown - 2'd1;
            end
        end
    end
end

endmodule
