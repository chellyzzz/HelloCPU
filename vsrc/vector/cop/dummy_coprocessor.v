module hcpu_dummy_coprocessor(
    input               clock,
    input               reset,
    input               i_valid,
    input      [31:0]   i_src1,
    input      [31:0]   i_src2,
    input      [31:0]   i_ins,
    output     [31:0]   o_res,
    output reg          o_done
);

reg         busy;
reg [1:0]   countdown;
reg [31:0]  latched_res;

assign o_res = latched_res;

wire [2:0]  cop_funct3 = i_ins[14:12];
wire [31:0] lane_add8 = {
    i_src1[31:24] + i_src2[31:24],
    i_src1[23:16] + i_src2[23:16],
    i_src1[15:8]  + i_src2[15:8],
    i_src1[7:0]   + i_src2[7:0]
};
wire [31:0] lane_xor8 = i_src1 ^ i_src2;
wire [31:0] lane_and8 = i_src1 & i_src2;
wire [31:0] cop_result = (cop_funct3 == 3'b001) ? lane_add8 :
                          (cop_funct3 == 3'b010) ? lane_xor8 :
                          (cop_funct3 == 3'b011) ? lane_and8 :
                          (i_src1 + i_src2);

always @(posedge clock or posedge reset) begin
    if (reset) begin
        busy        <= 1'b0;
        countdown   <= 2'b0;
        latched_res <= 32'b0;
        o_done      <= 1'b0;
    end else begin
        o_done <= 1'b0;

        if (i_valid && !busy) begin
            busy        <= 1'b1;
            countdown   <= 2'd2;
            latched_res <= cop_result;
        end else if (busy) begin
            if (countdown == 2'd1) begin
                busy      <= 1'b0;
                countdown <= 2'b0;
                o_done    <= 1'b1;
            end else begin
                countdown <= countdown - 2'd1;
            end
        end
    end
end

endmodule
