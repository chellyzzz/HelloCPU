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

wire [2:0]  cop_funct3;
wire [3:0]  scalar_lane_op;
wire [31:0] scalar_lane_result;

hcpu_vector_cop_decode u_cop_decode(
    .i_ins(i_ins),
    .o_funct3(cop_funct3),
    .o_scalar_lane_op(scalar_lane_op)
);

hcpu_vector_lane_alu u_scalar_lane_alu(
    .i_lhs(i_src1),
    .i_rhs(i_src2),
    .i_op(scalar_lane_op),
    .o_res(scalar_lane_result)
);

wire [31:0] cop_result = (cop_funct3 == 3'b001) ? scalar_lane_result :
                          (cop_funct3 == 3'b010) ? scalar_lane_result :
                          (cop_funct3 == 3'b011) ? scalar_lane_result :
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
